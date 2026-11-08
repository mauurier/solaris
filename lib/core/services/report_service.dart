import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import 'export_service.dart';
import 'formatting.dart';

/// Reporte PDF de una visita: portada, resumen con los hallazgos por
/// severidad, cada hallazgo con sus fotos y cada sección de la plantilla con
/// sus respuestas y evidencias, numeradas como en el levantamiento (2.1.3).
class ReportService {
  ReportService(this.store);
  final SurveyStore store;

  /// Las fotos se reducen a este ancho para que el PDF no pese cientos de MB.
  static const photoWidth = 900;

  /// Nombre del archivo: REPORTE_REY01202_VIS-001.pdf
  String fileName(FieldVisit v) {
    final project = store.project(v.projectId);
    return 'REPORTE_${slug(project?.code ?? 'PROYECTO', max: 20)}_${v.label}.pdf';
  }

  /// Arma el PDF. [onProgress] recibe cuántas fotos van preparadas de cuántas.
  Future<Uint8List> build(FieldVisit v, {DateTime? now, void Function(int done, int total)? onProgress}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    // Fotos y firmas, ya reducidas, por id de evidencia.
    final images = <String, Uint8List>{};
    final pending = store
        .evidenceOf(v.id)
        .where((e) => e.kind == EvidenceKind.photo || e.kind == EvidenceKind.signature)
        .where((e) => store.files.exists(e.path))
        .toList();
    for (var i = 0; i < pending.length; i++) {
      final e = pending[i];
      final bytes = await store.files.file(e.path).readAsBytes();
      final small = await Isolate.run(() => _shrink(bytes));
      if (small != null) images[e.id] = small;
      onProgress?.call(i + 1, pending.length);
    }

    final doc = pw.Document(
      title: fileName(v),
      author: 'Solaris',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    _ReportBuilder(store, v, images, now ?? DateTime.now()).addTo(doc);
    return doc.save();
  }
}

/// Reduce y vuelve a comprimir una foto; nula si no se pudo leer.
Uint8List? _shrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final resized = upright.width > ReportService.photoWidth
      ? img.copyResize(upright, width: ReportService.photoWidth)
      : upright;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
}

// ------------------------------------------------------------------ estilos

final _ink = PdfColor.fromHex('#1F2933');
final _muted = PdfColor.fromHex('#6B7280');
final _line = PdfColor.fromHex('#E5E7EB');
final _soft = PdfColor.fromHex('#F7F8FA');
final _accent = PdfColor.fromHex('#F59E0B');

PdfColor _severityColor(Severity s) => switch (s) {
      Severity.critica => PdfColor.fromHex('#DC2626'),
      Severity.alta => PdfColor.fromHex('#EA580C'),
      Severity.media => PdfColor.fromHex('#F59E0B'),
      Severity.baja => PdfColor.fromHex('#EAB308'),
    };

class _ReportBuilder {
  _ReportBuilder(this.store, this.v, this.images, this.now);
  final SurveyStore store;
  final FieldVisit v;
  final Map<String, Uint8List> images;
  final DateTime now;

  late final project = store.project(v.projectId);
  late final template = store.templateFor(v);
  late final engine = store.engineFor(v);
  late final findings = store.findingsOf(v.id).reversed.toList();

  void addTo(pw.Document doc) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 32),
      header: _header,
      footer: _footer,
      build: (_) => [
        ..._cover(),
        pw.NewPage(),
        ..._summary(),
        if (findings.isNotEmpty) ...[pw.NewPage(), ..._findings()],
        for (var i = 0; i < template.sections.length; i++) ...[pw.NewPage(), ..._section(i)],
      ],
    ));
  }

  // ------------------------------------------------------------ marco

  pw.Widget _header(pw.Context ctx) => ctx.pageNumber == 1
      ? pw.SizedBox()
      : pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            children: [
              pw.Text('SOLARIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _accent, fontSize: 10)),
              pw.Spacer(),
              pw.Text('${project?.code ?? ''} · ${v.label}', style: pw.TextStyle(color: _muted, fontSize: 9)),
            ],
          ),
        );

  pw.Widget _footer(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          children: [
            pw.Text('Confidencial · Generado con Solaris', style: pw.TextStyle(color: _muted, fontSize: 8)),
            pw.Spacer(),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      );

  pw.Widget _title(String text, {double size = 16}) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
        child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: _ink)),
      );

  pw.Widget _keyValue(String key, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: _ink)),
            pw.SizedBox(height: 2),
            pw.Text(value.isEmpty ? '—' : value, style: pw.TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      );

  String _when(DateTime d) => fmtDateTime(d);

  // ------------------------------------------------------------ portada

  List<pw.Widget> _cover() {
    final p = project;
    final dates = v.startedAt == null
        ? 'Sin iniciar'
        : v.endedAt == null || fmtDate(v.endedAt!) == fmtDate(v.startedAt!)
            ? fmtDate(v.startedAt!)
            : '${fmtDate(v.startedAt!)} – ${fmtDate(v.endedAt!)}';
    return [
      pw.Text('SOLARIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _accent, fontSize: 14)),
      pw.SizedBox(height: 40),
      pw.Center(
        child: pw.Text('Informe de levantamiento',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink)),
      ),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text('Fecha(s) de visita: $dates', style: pw.TextStyle(fontSize: 11, color: _muted))),
      pw.SizedBox(height: 36),
      _keyValue('Proyecto', p == null ? '' : '${p.code} · ${p.name}'),
      _keyValue('Cliente', p?.client ?? ''),
      _keyValue('Sitio', p?.site ?? ''),
      _keyValue('Dirección', p?.address ?? ''),
      _keyValue('Coordenadas', p?.coords?.label ?? ''),
      _keyValue('Tipo de proyecto', p?.type ?? ''),
      _keyValue('Visita', '${v.label} · ${v.motive}'),
      _keyValue('Equipo', 'Técnico: ${v.technician}   ·   Supervisor: ${v.supervisor}'),
      _keyValue('Plantilla', '${template.name} ${template.version}'),
      _keyValue('Estado', v.status.label),
      _keyValue('Fecha del informe', _when(now)),
    ];
  }

  // ------------------------------------------------------------ resumen

  List<pw.Widget> _summary() {
    final overall = engine.overall;
    final pend = engine.pendings();
    final blocking = pend.where((x) => x.kind == PendingKind.blocking).length;
    final justified = pend.where((x) => x.kind == PendingKind.justified).length;
    final photos = store.evidenceOf(v.id).where((e) => e.kind == EvidenceKind.photo).length;
    final critical = findings.where((f) => f.severity == Severity.critica).length;
    final review = store.reviewsOf(v.id).firstOrNull;

    final text = StringBuffer('Levantamiento con la plantilla "${template.name}" en ${project?.site ?? 'el sitio'}');
    if (v.startedAt != null) text.write(' el ${fmtDate(v.startedAt!)}');
    text.write('. Se respondieron ${overall.answered} de ${overall.total} preguntas y se tomaron $photos '
        'fotografía${photos == 1 ? '' : 's'}');
    text.write(blocking == 0 ? '; no quedan pendientes obligatorios' : '; quedan $blocking pendientes obligatorios');
    if (justified > 0) text.write(' ($justified justificados por el supervisor)');
    text.write('. ');
    text.write(switch (findings.length) {
      0 => 'No se registraron hallazgos.',
      1 => 'Se registró un hallazgo${critical > 0 ? ' crítico' : ''}.',
      final n => 'Se registraron $n hallazgos${critical > 0 ? ' ($critical crítico${critical == 1 ? '' : 's'})' : ''}.',
    });

    return [
      _title('Recuento de hallazgos'),
      pw.Table(
        border: pw.TableBorder.all(color: _line),
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1)},
        children: [
          _row(['Severidad', 'Abiertos', 'Cerrados'], header: true),
          for (final s in Severity.values.reversed)
            _row([
              s.label,
              '${findings.where((f) => f.severity == s && f.open).length}',
              '${findings.where((f) => f.severity == s && !f.open).length}',
            ], dot: _severityColor(s)),
          _row(['Total', '${findings.where((f) => f.open).length}', '${findings.where((f) => !f.open).length}'],
              header: true),
        ],
      ),
      pw.SizedBox(height: 22),
      _title('Resumen'),
      pw.Paragraph(text: text.toString(), style: pw.TextStyle(fontSize: 11, color: _ink, lineSpacing: 3)),
      if (v.notes.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _keyValue('Notas de cierre', v.notes),
      ],
      if ((project?.description ?? '').isNotEmpty) _keyValue('Descripción del proyecto', project!.description),
      pw.SizedBox(height: 10),
      _title('Datos de la visita', size: 13),
      _keyValue('Inicio', v.startedAt == null ? '' : '${_when(v.startedAt!)} · ${v.startPoint?.label ?? 'sin GPS'}'),
      _keyValue('Cierre', v.endedAt == null ? '' : '${_when(v.endedAt!)} · ${v.endPoint?.label ?? 'sin GPS'}'),
      _keyValue('Avance', '${(overall.value * 100).round()} % · ${overall.answered}/${overall.total} preguntas'),
      if (review != null)
        _keyValue(
          'Última revisión',
          '${review.decision == ReviewDecision.approved ? 'Aprobada' : 'Con correcciones'} · ${review.supervisor} · '
              '${_when(review.createdAt)}${review.notes.isEmpty ? '' : '\n${review.notes}'}',
        ),
    ];
  }

  pw.TableRow _row(List<String> cells, {bool header = false, PdfColor? dot}) => pw.TableRow(
        decoration: header ? pw.BoxDecoration(color: _soft) : null,
        children: [
          for (var i = 0; i < cells.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Row(
                mainAxisAlignment: i == 0 ? pw.MainAxisAlignment.start : pw.MainAxisAlignment.center,
                children: [
                  if (i == 0 && dot != null) ...[
                    pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: dot, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                  ],
                  pw.Text(cells[i],
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: header ? pw.FontWeight.bold : null, color: _ink)),
                ],
              ),
            ),
        ],
      );

  // ------------------------------------------------------------ hallazgos

  List<pw.Widget> _findings() => [
        _title('Hallazgos'),
        for (final f in findings) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 6),
            decoration: pw.BoxDecoration(
              color: _soft,
              border: pw.Border(left: pw.BorderSide(color: _severityColor(f.severity), width: 3)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Text(f.code, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: _ink)),
                  pw.SizedBox(width: 8),
                  pw.Text('${f.severity.label} · ${f.status.label} · ${f.category.label}',
                      style: pw.TextStyle(fontSize: 10, color: _severityColor(f.severity))),
                ]),
                pw.SizedBox(height: 4),
                pw.Text(f.description, style: pw.TextStyle(fontSize: 10.5, color: _ink)),
                if (f.location.isNotEmpty) pw.Text('Ubicación: ${f.location}', style: pw.TextStyle(fontSize: 9.5, color: _muted)),
                if (f.recommendation.isNotEmpty)
                  pw.Text('Recomendación: ${f.recommendation}', style: pw.TextStyle(fontSize: 9.5, color: _muted)),
                pw.Text('${f.user} · ${_when(f.createdAt)}${f.point == null ? '' : ' · ${f.point!.label}'}',
                    style: pw.TextStyle(fontSize: 8.5, color: _muted)),
              ],
            ),
          ),
          ..._photoRows(store.evidenceOfFinding(f.id)),
          pw.SizedBox(height: 10),
        ],
      ];

  // ------------------------------------------------------------ secciones

  List<pw.Widget> _section(int si) {
    final s = template.sections[si];
    final out = <pw.Widget>[_title('${si + 1} - ${s.title}')];
    for (var gi = 0; gi < s.groups.length; gi++) {
      final g = s.groups[gi];
      final count = engine.instanceCount(g);
      for (var inst = 0; inst < count; inst++) {
        final groupNo = '${si + 1}.${gi + 1}';
        final name = g.repeatable ? g.instanceName(inst) : g.title;
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
          child: pw.Text('$groupNo. $name', style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _ink)),
        ));
        for (var qi = 0; qi < g.questions.length; qi++) {
          final q = g.questions[qi];
          if (!engine.isVisible(g, inst, q)) continue;
          out.addAll(_question('$groupNo.${qi + 1}', g, inst, q));
        }
      }
    }
    return out;
  }

  List<pw.Widget> _question(String number, GroupDef g, int inst, QuestionDef q) {
    final key = AnswerKey(g.id, inst, q.id);
    final value = engine.value(key) ?? '';
    final justification = v.justifications[key.toString()];
    final box = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(5), border: pw.Border.all(color: _line)),
      child: pw.Text('$number - ${q.label}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
    );
    final answer = switch (q.type) {
      QType.yesNo => [_options(['Sí', 'No'], {value})],
      QType.single => [_options(q.options, {value})],
      QType.multi => [_options(q.options, VisitEngine.splitMulti(value).toSet())],
      QType.scale => [_scale(q, value)],
      QType.photo || QType.signature => _photoRows(store.evidenceOf(v.id, key)),
      QType.video || QType.document => _fileList(key, q),
      _ => [_text(value.isEmpty ? '' : (q.unit.isEmpty ? value : '$value ${q.unit}'))],
    };
    return [
      // El título va junto con el primer renglón de la respuesta: no queda
      // solo al final de una página.
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [box, answer.first]),
      ...answer.skip(1),
      if (justification != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
          child: pw.Text('Justificado: $justification', style: pw.TextStyle(fontSize: 9.5, color: _accent)),
        ),
      pw.SizedBox(height: 8),
    ];
  }

  pw.Widget _text(String value) => value.isEmpty
      ? pw.Text('Sin respuesta', style: pw.TextStyle(fontSize: 10, color: _muted))
      : pw.Paragraph(text: value, style: pw.TextStyle(fontSize: 10.5, color: _ink), margin: pw.EdgeInsets.zero);

  pw.Widget _options(List<String> options, Set<String> selected) => pw.Wrap(
        spacing: 14,
        runSpacing: 5,
        children: [
          for (final o in options)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: selected.contains(o) ? _ink : null,
                    border: pw.Border.all(color: selected.contains(o) ? _ink : _muted, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
                pw.SizedBox(width: 5),
                pw.Text(o,
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: selected.contains(o) ? _ink : _muted,
                        fontWeight: selected.contains(o) ? pw.FontWeight.bold : null)),
              ],
            ),
        ],
      );

  pw.Widget _scale(QuestionDef q, String value) {
    final n = double.tryParse(value);
    if (n == null) return _text('');
    final span = (q.max - q.min) == 0 ? 1 : q.max - q.min;
    final ratio = ((n - q.min) / span).clamp(0.0, 1.0);
    return pw.Row(
      children: [
        pw.Text('${q.min}', style: pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(height: 5, decoration: pw.BoxDecoration(color: _line, borderRadius: pw.BorderRadius.circular(3))),
              pw.Row(children: [
                pw.Expanded(
                  flex: (ratio * 1000).round().clamp(1, 1000),
                  child: pw.Container(
                      height: 5, decoration: pw.BoxDecoration(color: _accent, borderRadius: pw.BorderRadius.circular(3))),
                ),
                pw.Expanded(flex: (1000 - (ratio * 1000).round()).clamp(0, 999), child: pw.SizedBox()),
              ]),
            ],
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text('${q.max}', style: pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(width: 10),
        pw.Text('$value${q.unit.isEmpty ? '' : ' ${q.unit}'}',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
      ],
    );
  }

  /// Tres fotos por renglón; cada renglón es un widget aparte para que las
  /// preguntas con muchas fotos se repartan entre páginas.
  List<pw.Widget> _photoRows(List<Evidence> evidences) {
    final list = evidences.where((e) => e.kind == EvidenceKind.photo || e.kind == EvidenceKind.signature).toList();
    if (list.isEmpty) return [_text('')];
    return [
      for (var i = 0; i < list.length; i += 3)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + 3; j++)
                pw.Expanded(
                  child: j < list.length
                      ? pw.Padding(padding: const pw.EdgeInsets.only(right: 8), child: _photo(list[j]))
                      : pw.SizedBox(),
                ),
            ],
          ),
        ),
    ];
  }

  pw.Widget _photo(Evidence e) {
    final bytes = images[e.id];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 120,
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(4)),
          child: bytes == null
              ? pw.Center(child: pw.Text('Foto no disponible', style: pw.TextStyle(fontSize: 8, color: _muted)))
              : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(height: 3),
        pw.Text(e.user, style: pw.TextStyle(fontSize: 7.5, color: _muted)),
        pw.Text(_when(e.capturedAt), style: pw.TextStyle(fontSize: 7.5, color: _muted)),
        if (e.comment.isNotEmpty) pw.Text(e.comment, style: pw.TextStyle(fontSize: 7.5, color: _ink)),
      ],
    );
  }

  /// Videos y documentos no se pueden ver en un PDF: se listan sus archivos
  /// (vienen completos en el ZIP).
  List<pw.Widget> _fileList(AnswerKey key, QuestionDef q) {
    final files = store.evidenceOf(v.id, key);
    final docs = q.docCategory.isEmpty
        ? const <ProjectDocument>[]
        : store.documentsOf(v.projectId).where((d) => d.category == q.docCategory).toList();
    if (files.isEmpty && docs.isEmpty) return [_text('')];
    return [
      for (final e in files)
        pw.Text('${e.kind == EvidenceKind.video ? 'Video' : 'Archivo'}: ${e.originalName.isEmpty ? p.basename(e.path) : e.originalName} · '
            '${e.user} · ${_when(e.capturedAt)}',
            style: pw.TextStyle(fontSize: 10, color: _ink)),
      for (final d in docs)
        pw.Text('Documento del proyecto: ${d.originalName} · ${d.addedBy}', style: pw.TextStyle(fontSize: 10, color: _ink)),
    ];
  }
}
