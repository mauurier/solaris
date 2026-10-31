import 'dart:convert';

import 'package:path/path.dart' as p;

import '../models.dart';
import '../storage/persistence.dart';
import '../survey/entities.dart';

/// Tablas de Supabase que baja la app y la tabla local de cada una.
///
/// Las columnas son las que lee la app; [timestamp] es la columna con la que
/// se pide "lo que cambió desde X".
class RemoteTable {
  const RemoteTable(this.name, this.local, this.columns,
      {this.timestamp = 'actualizado_en', this.key = 'id', this.bucket});
  final String name;
  final String local;
  final String columns;
  final String timestamp;

  /// Desempate al ordenar, para que las páginas no se mezclen.
  final String key;

  /// Bucket de Storage con el archivo de cada fila (`ruta_archivo`).
  final String? bucket;

  static const projectTypes = RemoteTable(
      'tipo_proyecto', Tables.projectTypes, 'id, nombre, orden, actualizado_en, eliminado_en');
  static const visitMotives = RemoteTable(
      'motivo_visita', Tables.visitMotives, 'id, nombre, orden, actualizado_en, eliminado_en');
  static const templates = RemoteTable('plantilla', Tables.templates,
      'id, nombre, tipo, version_mayor, version_menor, activa, definicion, actualizado_en, eliminado_en');
  static const clients =
      RemoteTable('cliente', Tables.clients, 'id, razon_social, rfc, contacto, actualizado_en, eliminado_en');
  static const sites = RemoteTable(
      'sitio', Tables.sites, 'id, id_cliente, nombre, direccion, latitud, longitud, actualizado_en, eliminado_en');
  static const projects = RemoteTable('proyecto', Tables.projects,
      'id, id_sitio, id_tipo_proyecto, id_supervisor, id_plantilla, codigo, nombre, descripcion, '
          'fecha_programada, estado, creado_en, actualizado_en, eliminado_en');

  /// Sin tabla local propia: se guarda en `technicianIds` del proyecto.
  static const projectTechnicians = RemoteTable(
      'proyecto_tecnico', Tables.projects, 'id_proyecto, id_tecnico, creado_en, actualizado_en, eliminado_en',
      key: 'id_proyecto');
  static const visits = RemoteTable('visita', Tables.visits,
      'id, id_proyecto, id_tecnico, id_supervisor, id_motivo, id_plantilla, numero, fecha_programada, '
          'fecha_inicio, fecha_fin, lat_inicio, lng_inicio, lat_fin, lng_fin, estado, notas, '
          'fecha_ultima_apertura, plantilla_usada, repeticiones, justificaciones, creado_en, actualizado_en, '
          'eliminado_en');
  static const answers = RemoteTable('respuesta', Tables.answers,
      'id, id_visita, clave_grupo, numero_repeticion, clave_pregunta, valor, actualizado_en, eliminado_en');
  static const documents = RemoteTable(
      'documento',
      Tables.documents,
      'id, id_proyecto, id_usuario, categoria, ruta_archivo, mime_type, tamano, nombre_original, subido_en, '
          'creado_en, actualizado_en, eliminado_en',
      bucket: 'documentos');
  static const evidences = RemoteTable(
      'evidencia',
      Tables.evidences,
      'id, id_visita, id_usuario, clave_grupo, numero_repeticion, clave_pregunta, tipo, ruta_archivo, mime_type, '
          'tamano, nombre_original, fecha_captura, latitud, longitud, comentario, importada, subido_en, '
          'actualizado_en, eliminado_en',
      bucket: 'evidencias');
}

/// Conversión entre las filas de Supabase y el formato que guarda la app (el
/// mismo `toJson` de cada modelo): [catalogItem], [project]… para bajar y
/// [toDb] para subir.
class RemoteRows {
  RemoteRows._();

  static bool deleted(Map<String, Object?> r) => r['eliminado_en'] != null;

  // ---------------------------------------------------------------- estados

  /// `enCaptura` ↔ `en_captura`.
  static String statusToDb(ProjectStatus s) =>
      s.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  static ProjectStatus statusFromDb(Object? v) =>
      ProjectStatus.values.where((s) => statusToDb(s) == v).firstOrNull ?? ProjectStatus.asignado;

  // ---------------------------------------------------------------- tablas

  static Map<String, Object?> catalogItem(Map<String, Object?> r) =>
      {'id': r['id'], 'name': r['nombre'], 'order': r['orden'] ?? 0};

  /// `definicion` guarda `{sections: [...]}`, como `TemplateDef.toJson()`.
  static Map<String, Object?> template(Map<String, Object?> r) {
    final def = _map(r['definicion']);
    return {
      'id': r['id'],
      'name': r['nombre'],
      'type': r['tipo'] ?? '',
      'major': r['version_mayor'] ?? 1,
      'minor': r['version_menor'] ?? 0,
      'active': r['activa'] ?? true,
      'updatedAt': r['actualizado_en'],
      'sections': def['sections'] ?? const [],
    };
  }

  static Map<String, Object?> client(Map<String, Object?> r) => {
        'id': r['id'],
        'name': r['razon_social'],
        'rfc': r['rfc'] ?? '',
        'contact': r['contacto'] ?? '',
      };

  static Map<String, Object?> site(Map<String, Object?> r) => {
        'id': r['id'],
        'clientId': r['id_cliente'],
        'name': r['nombre'],
        'address': r['direccion'] ?? '',
        'coords': _point(r['latitud'], r['longitud']),
      };

  /// [technicianIds] sale de `proyecto_tecnico`.
  static Map<String, Object?> project(Map<String, Object?> r, List<String> technicianIds) => {
        'id': r['id'],
        'code': r['codigo'],
        'name': r['nombre'],
        'siteId': r['id_sitio'],
        'supervisorId': r['id_supervisor'],
        'technicianIds': technicianIds,
        'templateId': r['id_plantilla'] ?? '',
        'typeId': r['id_tipo_proyecto'],
        'description': r['descripcion'] ?? '',
        'createdAt': r['creado_en'],
        'scheduledAt': r['fecha_programada'],
        'status': statusFromDb(r['estado']).name,
        'updatedAt': r['actualizado_en'],
      };

  /// `plantilla_usada` es la copia completa de la plantilla (`TemplateDef.toJson()`).
  static Map<String, Object?> visit(Map<String, Object?> r) => {
        'id': r['id'],
        'projectId': r['id_proyecto'],
        'number': r['numero'],
        'technicianId': r['id_tecnico'],
        'supervisorId': r['id_supervisor'],
        'motiveId': r['id_motivo'],
        'templateId': r['id_plantilla'] ?? '',
        'scheduledAt': r['fecha_programada'],
        'status': statusFromDb(r['estado']).name,
        'startedAt': r['fecha_inicio'],
        'endedAt': r['fecha_fin'],
        'startPoint': _point(r['lat_inicio'], r['lng_inicio']),
        'endPoint': _point(r['lat_fin'], r['lng_fin']),
        'openedAt': r['fecha_ultima_apertura'],
        'template': r['plantilla_usada'] == null ? null : jsonEncode(_map(r['plantilla_usada'])),
        'instances': _map(r['repeticiones']).map((k, v) => MapEntry(k, (v as num).toInt())),
        'justifications': _map(r['justificaciones']).map((k, v) => MapEntry(k, '$v')),
        'notes': r['notas'] ?? '',
      };

  /// Clave local de la respuesta: `bloque#repetición/pregunta`.
  static String answerKey(Map<String, Object?> r) =>
      '${r['clave_grupo']}#${r['numero_repeticion'] ?? 0}/${r['clave_pregunta']}';

  /// Id de la fila local de una respuesta (`SurveyStore` usa `visita|clave`).
  static String answerRowId(Map<String, Object?> r) => '${r['id_visita']}|${answerKey(r)}';

  static Map<String, Object?> answer(Map<String, Object?> r) => {
        'visitId': r['id_visita'],
        'key': answerKey(r),
        'value': r['valor'] ?? '',
        'at': r['actualizado_en'],
      };

  static const _kinds = {'photo': 'foto', 'video': 'video', 'document': 'documento', 'signature': 'firma'};

  /// `ruta_archivo` es `{proyecto}/{archivo}`; la copia local va en
  /// `media/{proyecto}/docs`.
  static Map<String, Object?> document(Map<String, Object?> r) {
    final ruta = r['ruta_archivo'] as String;
    final projectId = r['id_proyecto'] as String;
    return {
      'id': r['id'],
      'projectId': projectId,
      'category': r['categoria'],
      'path': p.join('media', projectId, 'docs', p.posix.basename(ruta)),
      'originalName': r['nombre_original'] ?? p.posix.basename(ruta),
      'size': (r['tamano'] as num?)?.toInt() ?? 0,
      'addedAt': r['creado_en'],
      'addedById': r['id_usuario'],
    };
  }

  /// `ruta_archivo` es `{proyecto}/{visita}/{archivo}`; la copia local va en
  /// `media/{proyecto}/{visita}`.
  static Map<String, Object?> evidence(Map<String, Object?> r) {
    final ruta = r['ruta_archivo'] as String;
    final projectId = ruta.split('/').first;
    final visitId = r['id_visita'] as String;
    return {
      'id': r['id'],
      'visitId': visitId,
      'projectId': projectId,
      'key': r['clave_grupo'] == null ? '' : answerKey(r),
      'kind': _kinds.entries.firstWhere((e) => e.value == r['tipo'], orElse: () => _kinds.entries.first).key,
      'path': p.join('media', projectId, visitId, p.posix.basename(ruta)),
      'capturedAt': r['fecha_captura'],
      'userId': r['id_usuario'],
      'originalName': r['nombre_original'] ?? '',
      'point': _point(r['latitud'], r['longitud']),
      'comment': r['comentario'] ?? '',
      'imported': r['importada'] ?? false,
    };
  }

  /// Dónde va en Storage el archivo de una evidencia o documento local.
  static String remotePath(String localTable, Map<String, Object?> j) {
    final name = p.basename(j['path'] as String);
    return localTable == Tables.evidences ? '${j['projectId']}/${j['visitId']}/$name' : '${j['projectId']}/$name';
  }

  static const _mimes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.heic': 'image/heic',
    '.webp': 'image/webp',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.pdf': 'application/pdf',
  };

  static String mimeOf(String path) => _mimes[p.extension(path).toLowerCase()] ?? 'application/octet-stream';

  // ------------------------------------------------- del teléfono al servidor

  /// Fila local en el formato de la base, sin `id` ni `eliminado_en`. La
  /// subida compara columna por columna estas tres versiones: la del
  /// teléfono, su base y la del servidor (ver [same]).
  static Map<String, Object?> toDb(String localTable, Map<String, Object?> j) => switch (localTable) {
        Tables.projectTypes || Tables.visitMotives => {'nombre': j['name'], 'orden': j['order'] ?? 0},
        Tables.templates => {
            'nombre': j['name'],
            'tipo': _text(j['type']),
            'version_mayor': j['major'] ?? 1,
            'version_menor': j['minor'] ?? 0,
            'activa': j['active'] ?? true,
            'definicion': {'sections': j['sections'] ?? const []},
          },
        Tables.clients => {'razon_social': j['name'], 'rfc': _text(j['rfc']), 'contacto': _text(j['contact'])},
        Tables.sites => {
            'id_cliente': j['clientId'],
            'nombre': j['name'],
            'direccion': _text(j['address']),
            ..._coords('latitud', 'longitud', j['coords']),
          },
        // Los técnicos van aparte, en `proyecto_tecnico`.
        Tables.projects => {
            'id_sitio': j['siteId'],
            'id_tipo_proyecto': j['typeId'],
            'id_supervisor': j['supervisorId'],
            'id_plantilla': _text(j['templateId']),
            'codigo': j['code'],
            'nombre': j['name'],
            'descripcion': _text(j['description']),
            'fecha_programada': _utc(j['scheduledAt']),
            'estado': _status(j['status']),
            'creado_en': _utc(j['createdAt']),
          },
        Tables.visits => {
            'id_proyecto': j['projectId'],
            'id_tecnico': j['technicianId'],
            'id_supervisor': j['supervisorId'],
            'id_motivo': j['motiveId'],
            'id_plantilla': _text(j['templateId']),
            'numero': j['number'],
            'fecha_programada': _utc(j['scheduledAt']),
            'fecha_inicio': _utc(j['startedAt']),
            'fecha_fin': _utc(j['endedAt']),
            ..._coords('lat_inicio', 'lng_inicio', j['startPoint']),
            ..._coords('lat_fin', 'lng_fin', j['endPoint']),
            'estado': _status(j['status']),
            'notas': _text(j['notes']),
            'fecha_ultima_apertura': _utc(j['openedAt']),
            'plantilla_usada': j['template'] == null ? null : _map(j['template']),
            'repeticiones': j['instances'] ?? const {},
            'justificaciones': j['justifications'] ?? const {},
          },
        Tables.answers => _answerToDb(j),
        // `tamano` y `subido_en` los pone la subida del archivo.
        Tables.documents => {
            'id_proyecto': j['projectId'],
            'id_usuario': j['addedById'],
            'categoria': j['category'],
            'ruta_archivo': remotePath(localTable, j),
            'mime_type': mimeOf(j['path'] as String),
            'nombre_original': _text(j['originalName']),
            'creado_en': _utc(j['addedAt']),
          },
        Tables.evidences => {
            'id_visita': j['visitId'],
            'id_usuario': j['userId'],
            ..._evidenceKey(j['key'] as String? ?? ''),
            'tipo': _kinds[j['kind']],
            'ruta_archivo': remotePath(localTable, j),
            'mime_type': mimeOf(j['path'] as String),
            'nombre_original': _text(j['originalName']),
            'fecha_captura': _utc(j['capturedAt']),
            ..._coords('latitud', 'longitud', j['point']),
            'comentario': _text(j['comment']),
            'importada': j['imported'] ?? false,
          },
        _ => throw ArgumentError('Tabla sin subida: $localTable'),
      };

  static Map<String, Object?> _answerToDb(Map<String, Object?> j) {
    final k = AnswerKey.parse(j['key'] as String);
    return {
      'id_visita': j['visitId'],
      'clave_grupo': k.groupId,
      'numero_repeticion': k.instance,
      'clave_pregunta': k.questionId,
      'valor': j['value'],
    };
  }

  /// Una evidencia suelta (sin pregunta) no lleva clave.
  static Map<String, Object?> _evidenceKey(String key) {
    if (!key.contains('#')) return {'clave_grupo': null, 'numero_repeticion': null, 'clave_pregunta': null};
    final k = AnswerKey.parse(key);
    return {'clave_grupo': k.groupId, 'numero_repeticion': k.instance, 'clave_pregunta': k.questionId};
  }

  /// Mismo valor aunque venga escrito distinto: `numeric` como texto, horas
  /// con otra zona o jsonb con las llaves en otro orden.
  static bool same(Object? a, Object? b) {
    if (a == null || b == null) return a == b;
    if (a is Map && b is Map) {
      return a.length == b.length && a.keys.every((k) => b.containsKey(k) && same(a[k], b[k]));
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!same(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is num || b is num) {
      final x = _num(a), y = _num(b);
      return x != null && y != null && (x - y).abs() < 1e-9;
    }
    if (a is String && b is String && a != b) {
      final x = _instant(a), y = _instant(b);
      return x != null && y != null && x.isAtSameMomentAs(y);
    }
    return a == b;
  }

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  /// Las horas locales del teléfono se suben en UTC.
  static String? _utc(Object? v) => v is String ? DateTime.parse(v).toUtc().toIso8601String() : null;

  static String _status(Object? name) => statusToDb(ProjectStatus.values.asNameMap()[name] ?? ProjectStatus.asignado);

  /// `numeric(9, 6)`: se redondea igual que en la base para poder comparar.
  static Map<String, Object?> _coords(String lat, String lng, Object? point) {
    double? round(Object? v) => v is num ? (v * 1e6).round() / 1e6 : null;
    final p = point is Map ? point : const {};
    return {lat: round(p['lat']), lng: round(p['lng'])};
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

  static final _iso = RegExp(r'^\d{4}-\d{2}-\d{2}T');
  static DateTime? _instant(String v) => _iso.hasMatch(v) ? DateTime.tryParse(v) : null;

  // ---------------------------------------------------------------- ayuda

  static Map<String, Object?> _map(Object? v) => switch (v) {
        Map() => v.cast<String, Object?>(),
        String() when v.isNotEmpty => (jsonDecode(v) as Map).cast<String, Object?>(),
        _ => const {},
      };

  /// PostgREST manda `numeric` como número, pero también puede llegar como texto.
  static Map<String, Object?>? _point(Object? lat, Object? lng) {
    double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    final a = n(lat), b = n(lng);
    return a == null || b == null ? null : {'lat': a, 'lng': b};
  }
}
