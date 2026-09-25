import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import 'formatting.dart';

/// Convierte un texto en un fragmento seguro para nombre de archivo:
/// sin acentos ni caracteres especiales, en mayúsculas y con guiones bajos.
String slug(String s, {int max = 40}) {
  const from = 'ÁÀÄÂáàäâÉÈËÊéèëêÍÌÏÎíìïîÓÒÖÔóòöôÚÙÜÛúùüûÑñÇçΔ';
  const to = 'AAAAaaaaEEEEeeeeIIIIiiiiOOOOooooUUUUuuuuNnCcD';
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  var out = buf.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  out = out.replaceAll(RegExp(r'^_+|_+$'), '');
  if (out.length > max) out = out.substring(0, max).replaceAll(RegExp(r'_+$'), '');
  return out.isEmpty ? 'SIN_NOMBRE' : out;
}

/// Un archivo dentro del ZIP: sale de disco ([source]) o se genera ([text]).
class ExportEntry {
  ExportEntry.file(this.path, this.source) : text = null;
  ExportEntry.text(this.path, this.text) : source = null;

  /// Ruta dentro de la carpeta raíz del proyecto.
  final String path;
  final File? source;
  final String? text;

  int get size => source != null ? (source!.existsSync() ? source!.lengthSync() : 0) : utf8.encode(text!).length;
}

class ExportPlan {
  ExportPlan(this.root, this.zipName, this.entries);
  final String root;
  final String zipName;
  final List<ExportEntry> entries;

  int get totalBytes => entries.fold(0, (a, e) => a + e.size);
  int get fileCount => entries.length;

  /// Carpetas que existirán en el ZIP (las fijas y las que crean los archivos).
  List<String> get folders {
    final set = <String>{...Folders.all};
    for (final e in entries) {
      var dir = p.posix.dirname(e.path);
      while (dir != '.' && dir.isNotEmpty) {
        set.add(dir);
        dir = p.posix.dirname(dir);
      }
    }
    return set.toList()..sort();
  }
}

/// Arma la estructura de "Instrucciones de llenado de carpetas" y la nomenclatura
/// automática (RECIBO_CFE_SITIO.pdf, TABLERO_PRINCIPAL_ITM_001.jpg…).
class ExportService {
  ExportService(this.store);
  final SurveyStore store;

  ExportPlan plan(SurveyProject project, {DateTime? now}) {
    final date = fmtIsoDate(now ?? DateTime.now());
    final site = slug(project.site.isEmpty ? project.name : project.site, max: 30);
    final root = '${slug(project.code, max: 20)}_$site';
    final zipName = '${slug(project.client, max: 20)}_${site}_LEVANTAMIENTO_$date.zip';

    final entries = <ExportEntry>[];
    final used = <String>{};
    final seq = <String, int>{};

    String unique(String folder, String base, String ext, {bool numbered = true}) {
      // Fotos y videos se numeran siempre (_001); los documentos sólo si se
      // repite el nombre, para respetar RECIBO_CFE_[Sitio].pdf.
      final key = '$folder/$base';
      String name;
      do {
        final n = (seq[key] ?? 0) + 1;
        seq[key] = n;
        final suffix = numbered || n > 1 ? '_${n.toString().padLeft(3, '0')}' : '';
        name = '$folder/$base$suffix${ext.toLowerCase()}';
      } while (used.contains(name));
      used.add(name);
      return name;
    }

    // Documentos del proyecto.
    for (final d in store.documentsOf(project.id)) {
      final cat = d.cat;
      final name = unique(cat.folder, '${cat.prefix}_$site', p.extension(d.originalName), numbered: false);
      entries.add(ExportEntry.file(name, store.files.file(d.path)));
    }

    // Evidencias de todas las visitas, ubicadas según su pregunta.
    final evidenceRows = <List<String>>[];
    final visits = store.visitsOf(project.id).reversed.toList();
    for (final v in visits) {
      final template = store.templateFor(v);
      for (final e in store.evidenceOf(v.id)) {
        final key = AnswerKey.parse(e.key);
        final located = _locate(template, key);
        String folder;
        String base;
        String question;
        String instance = '';
        if (located == null) {
          folder = Folders.adicionales;
          base = 'EVIDENCIA';
          question = e.key;
        } else {
          final (group, q) = located;
          instance = group.instanceName(key.instance);
          folder = (q.folder.isEmpty ? Folders.adicionales : q.folder).replaceAll('{INSTANCIA}', instance);
          final prefix = q.prefix.isEmpty ? slug(q.label, max: 30) : q.prefix;
          base = slug(prefix.replaceAll('{INSTANCIA}', instance), max: 60);
          question = q.label;
        }
        final isDoc = e.kind == EvidenceKind.document;
        final name = unique(folder, isDoc ? '${base}_$site' : base, p.extension(e.path), numbered: !isDoc);
        entries.add(ExportEntry.file(name, store.files.file(e.path)));
        evidenceRows.add([
          name,
          question,
          instance,
          e.kind.name,
          v.label,
          fmtStamp(e.capturedAt),
          e.point?.lat.toStringAsFixed(6) ?? '',
          e.point?.lng.toStringAsFixed(6) ?? '',
          e.user,
          e.comment,
          e.imported ? 'Sí' : 'No',
          e.originalName,
          e.id,
        ]);
      }
    }

    // Reportes en texto dentro de "05 Reporte de Levantamiento".
    final code = slug(project.code, max: 20);
    entries.add(ExportEntry.text('${Folders.reporte}/RESUMEN_$code.txt', _summary(project, visits)));
    for (final v in visits.where((v) => v.started)) {
      entries.add(ExportEntry.text('${Folders.reporte}/LEVANTAMIENTO_${code}_${v.label}.csv', _answersCsv(v)));
    }
    final measures = _measurementsCsv(visits.where((v) => v.started).toList());
    if (measures != null) {
      entries.add(ExportEntry.text('${Folders.reporte}/MEDICIONES_$code.csv', measures));
    }
    if (evidenceRows.isNotEmpty) {
      entries.add(ExportEntry.text(
        '${Folders.reporte}/EVIDENCIAS_$code.csv',
        _csv([
          [
            'Archivo',
            'Pregunta',
            'Instancia',
            'Tipo',
            'Visita',
            'Fecha y hora',
            'Latitud',
            'Longitud',
            'Usuario',
            'Comentario',
            'Importada',
            'Nombre original',
            'ID interno',
          ],
          ...evidenceRows,
        ]),
      ));
    }

    return ExportPlan(root, zipName, entries);
  }

  /// Escribe el ZIP en [outputDir] y devuelve el archivo.
  Future<File> writeZip(ExportPlan plan, Directory outputDir) async {
    await outputDir.create(recursive: true);
    final out = File(p.join(outputDir.path, plan.zipName));
    if (await out.exists()) await out.delete();
    final encoder = ZipFileEncoder()..create(out.path);
    for (final folder in plan.folders) {
      encoder.addArchiveFile(ArchiveFile.directory('${plan.root}/$folder/'));
    }
    for (final e in plan.entries) {
      final name = '${plan.root}/${e.path}';
      if (e.source != null) {
        if (!await e.source!.exists()) continue;
        // JPG y MP4 ya vienen comprimidos: guardarlos tal cual es mucho más rápido.
        await encoder.addFile(e.source!, name, ZipFileEncoder.store);
      } else {
        encoder.addArchiveFile(ArchiveFile.bytes(name, utf8.encode(e.text!)));
      }
    }
    await encoder.close();
    return out;
  }

  (GroupDef, QuestionDef)? _locate(TemplateDef t, AnswerKey key) {
    for (final s in t.sections) {
      for (final g in s.groups) {
        if (g.id != key.groupId) continue;
        for (final q in g.questions) {
          if (q.id == key.questionId) return (g, q);
        }
      }
    }
    return null;
  }

  String _summary(SurveyProject project, List<FieldVisit> visits) {
    final b = StringBuffer()
      ..writeln('LEVANTAMIENTO TÉCNICO · ${project.code}')
      ..writeln('=' * 48)
      ..writeln('Proyecto:     ${project.name}')
      ..writeln('Cliente:      ${project.client}')
      ..writeln('Sitio:        ${project.site}')
      ..writeln('Dirección:    ${project.address}')
      ..writeln('Coordenadas:  ${project.coords?.label ?? '—'}')
      ..writeln('Tipo:         ${project.type}')
      ..writeln('Supervisor:   ${project.supervisor}')
      ..writeln('Técnicos:     ${project.technicians.join(', ')}')
      ..writeln('Creado:       ${fmtDateTime(project.createdAt)}')
      ..writeln('Exportado:    ${fmtDateTime(DateTime.now())}')
      ..writeln();
    if (project.description.isNotEmpty) b..writeln(project.description)..writeln();
    for (final v in visits) {
      final t = store.templateFor(v);
      b
        ..writeln('${v.label} · ${v.motive}')
        ..writeln('-' * 48)
        ..writeln('Técnico:      ${v.technician}')
        ..writeln('Plantilla:    ${t.name} ${t.version}')
        ..writeln('Inicio:       ${v.startedAt == null ? '—' : fmtDateTime(v.startedAt!)}'
            '  GPS: ${v.startPoint?.label ?? 'sin señal'}')
        ..writeln('Fin:          ${v.endedAt == null ? '—' : fmtDateTime(v.endedAt!)}'
            '  GPS: ${v.endPoint?.label ?? 'sin señal'}');
      if (v.started) {
        final engine = store.engineFor(v);
        final pend = engine.pendings();
        b.writeln('Avance:       ${(engine.overall.value * 100).round()} %');
        final justified = pend.where((x) => x.kind == PendingKind.justified).toList();
        final blocking = pend.where((x) => x.kind == PendingKind.blocking).toList();
        if (blocking.isNotEmpty) {
          b.writeln('Pendientes obligatorios:');
          for (final x in blocking) {
            b.writeln('  • ${x.question.code} ${x.question.contextLabel}');
          }
        }
        if (justified.isNotEmpty) {
          b.writeln('Pendientes justificados:');
          for (final x in justified) {
            b.writeln('  • ${x.question.code} ${x.question.contextLabel}: ${x.justification}');
          }
        }
        final hot = store.answersOf(v.id)['g_cierre#0/punto_caliente'];
        if (hot == 'Sí') {
          b.writeln('⚠ ANOMALÍA TERMOGRÁFICA GRAVE: '
              '${store.answersOf(v.id)['g_cierre#0/punto_caliente_desc'] ?? ''}');
        }
      }
      if (v.notes.isNotEmpty) b.writeln('Notas: ${v.notes}');
      b.writeln();
    }
    return b.toString();
  }

  String _answersCsv(FieldVisit v) {
    final engine = store.engineFor(v);
    final rows = <List<String>>[
      ['Sección', 'Código', 'Bloque', 'Pregunta', 'Respuesta', 'Unidad', 'Obligatoria', 'Estado'],
    ];
    for (final rq in engine.questions()) {
      final q = rq.question;
      String answer;
      if (q.type.isEvidence) {
        final n = engine.evidenceCount(rq.key);
        answer = n == 0 ? '' : '$n archivo${n == 1 ? '' : 's'}';
      } else {
        answer = (engine.value(rq.key) ?? '').replaceAll('|', ', ');
      }
      rows.add([
        rq.section.title,
        rq.code,
        rq.instanceName,
        q.label,
        answer,
        q.unit,
        q.required ? 'Sí' : 'No',
        engine.isAnswered(rq)
            ? 'Completo'
            : v.justifications.containsKey(rq.key.toString())
                ? 'Justificado'
                : 'Pendiente',
      ]);
    }
    return _csv(rows);
  }

  /// Mediciones eléctricas = respuestas numéricas en V, A o kA.
  String? _measurementsCsv(List<FieldVisit> visits) {
    const units = {'V', 'A', 'kA', 'kVA', '%Z'};
    final rows = <List<String>>[
      ['Visita', 'Equipo', 'Parámetro', 'Valor', 'Unidad'],
    ];
    for (final v in visits) {
      final engine = store.engineFor(v);
      for (final rq in engine.questions()) {
        final q = rq.question;
        if (q.type != QType.number || !units.contains(q.unit)) continue;
        final value = engine.value(rq.key);
        if (value == null || value.isEmpty) continue;
        rows.add([v.label, rq.instanceName, q.label, value, q.unit]);
      }
    }
    return rows.length == 1 ? null : _csv(rows);
  }

  /// CSV con BOM para que Excel respete los acentos.
  String _csv(List<List<String>> rows) {
    String cell(String s) => s.contains(RegExp(r'[",\n;]')) ? '"${s.replaceAll('"', '""')}"' : s;
    return '﻿${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
  }
}
