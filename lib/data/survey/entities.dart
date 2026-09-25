import 'dart:convert';

import '../models.dart';
import 'template.dart';

/// Coordenada capturada por el GPS del teléfono.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  String get label => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng};
  static GeoPoint? fromJson(Object? j) {
    if (j is! Map) return null;
    return GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());
  }

  /// Acepta "25.78, -100.18" tal como lo escribe una persona.
  static GeoPoint? tryParse(String s) {
    final parts = s.split(',').map((p) => double.tryParse(p.trim())).toList();
    if (parts.length != 2 || parts.contains(null)) return null;
    final lat = parts[0]!, lng = parts[1]!;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return GeoPoint(lat, lng);
  }
}

/// Categorías de documentos que se suben al iniciar un proyecto, con su
/// carpeta y prefijo según "Instrucciones de llenado de carpetas".
class DocCategory {
  const DocCategory(this.id, this.label, this.folder, this.prefix, this.hint);
  final String id;
  final String label;
  final String folder;
  final String prefix;
  final String hint;

  static const all = [
    DocCategory('recibo_cfe', 'Recibo de luz CFE', Folders.sitio, 'RECIBO_CFE',
        'Ambos lados: servicio, medidor, tarifa y demandas'),
    DocCategory('unifilar', 'Diagrama unifilar', Folders.documentacion, 'DIAGRAMA_UNIFILAR',
        'Versión actual del arrendador o del cliente'),
    DocCategory('ingenieria', 'Ingeniería existente', Folders.documentacion, 'INGENIERIA_EXISTENTE',
        'Memorias de cálculo, expedientes técnicos'),
    DocCategory('planos', 'Planos previos', Folders.documentacion, 'PLANOS',
        'Arquitectónicos, estructurales o eléctricos'),
    DocCategory('cad', 'CAD y modelos 3D', Folders.cad, 'CAD', 'Archivos nativos DWG, DXF, SKP…'),
    DocCategory('otro', 'Otro documento', Folders.adicionales, 'DOCUMENTO', 'Información complementaria'),
  ];

  static DocCategory byId(String id) => all.firstWhere((c) => c.id == id, orElse: () => all.last);
}

class SurveyProject {
  SurveyProject({
    required this.id,
    required this.code,
    required this.name,
    required this.client,
    required this.site,
    required this.address,
    required this.supervisor,
    required this.technicians,
    required this.templateId,
    required this.type,
    required this.createdAt,
    this.coords,
    this.scheduledAt,
    this.description = '',
    this.status = ProjectStatus.asignado,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;

  /// Clave del cliente o del sitio (REY01202). Da nombre al ZIP y a los archivos.
  String code;
  String name;
  String client;
  String site;
  String address;
  GeoPoint? coords;
  String supervisor;
  List<String> technicians;
  String templateId;
  String type;
  String description;
  DateTime createdAt;
  DateTime? scheduledAt;
  ProjectStatus status;
  DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'client': client,
        'site': site,
        'address': address,
        'coords': coords?.toJson(),
        'supervisor': supervisor,
        'technicians': technicians,
        'templateId': templateId,
        'type': type,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'scheduledAt': scheduledAt?.toIso8601String(),
        'status': status.name,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static SurveyProject fromJson(Map<String, Object?> j) => SurveyProject(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        client: j['client'] as String,
        site: j['site'] as String,
        address: j['address'] as String? ?? '',
        coords: GeoPoint.fromJson(j['coords']),
        supervisor: j['supervisor'] as String? ?? '',
        technicians: (j['technicians'] as List).cast<String>().toList(),
        templateId: j['templateId'] as String,
        type: j['type'] as String? ?? '',
        description: j['description'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        scheduledAt: DateTime.tryParse(j['scheduledAt'] as String? ?? ''),
        status: ProjectStatus.values.byName(j['status'] as String),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      );
}

/// Documento subido al proyecto (no a una visita): recibo CFE, planos, CAD…
class ProjectDocument {
  ProjectDocument({
    required this.id,
    required this.projectId,
    required this.category,
    required this.path,
    required this.originalName,
    required this.size,
    required this.addedAt,
    required this.addedBy,
  });

  final String id;
  final String projectId;
  final String category;

  /// Ruta relativa a la carpeta de datos de la app (ver `FileStore`).
  final String path;
  final String originalName;
  final int size;
  final DateTime addedAt;
  final String addedBy;

  DocCategory get cat => DocCategory.byId(category);

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'category': category,
        'path': path,
        'originalName': originalName,
        'size': size,
        'addedAt': addedAt.toIso8601String(),
        'addedBy': addedBy,
      };

  static ProjectDocument fromJson(Map<String, Object?> j) => ProjectDocument(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        category: j['category'] as String,
        path: j['path'] as String,
        originalName: j['originalName'] as String,
        size: j['size'] as int? ?? 0,
        addedAt: DateTime.parse(j['addedAt'] as String),
        addedBy: j['addedBy'] as String? ?? '',
      );
}

class FieldVisit {
  FieldVisit({
    required this.id,
    required this.projectId,
    required this.number,
    required this.technician,
    required this.supervisor,
    required this.motive,
    required this.templateId,
    this.scheduledAt,
    this.status = ProjectStatus.asignado,
    this.startedAt,
    this.endedAt,
    this.startPoint,
    this.endPoint,
    this.template,
    Map<String, int>? instances,
    Map<String, String>? justifications,
    this.notes = '',
  })  : instances = instances ?? {},
        justifications = justifications ?? {};

  final String id;
  final String projectId;
  final int number;
  String technician;
  String supervisor;
  String motive;
  final String templateId;
  DateTime? scheduledAt;
  ProjectStatus status;
  DateTime? startedAt;
  DateTime? endedAt;
  GeoPoint? startPoint;
  GeoPoint? endPoint;

  /// Copia de la plantilla tomada al iniciar la visita. Así, editar la
  /// plantilla después no altera un levantamiento que ya está en curso.
  TemplateDef? template;

  /// Número de instancias por bloque repetible (id del bloque → cantidad).
  Map<String, int> instances;

  /// Pendientes obligatorios que el supervisor autorizó cerrar (clave → motivo).
  Map<String, String> justifications;
  String notes;

  String get label => 'VIS-${number.toString().padLeft(3, '0')}';
  bool get started => startedAt != null;
  bool get finished => endedAt != null;

  int instanceCount(GroupDef g) => g.repeatable ? (instances[g.id] ?? 1) : 1;

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'number': number,
        'technician': technician,
        'supervisor': supervisor,
        'motive': motive,
        'templateId': templateId,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'startPoint': startPoint?.toJson(),
        'endPoint': endPoint?.toJson(),
        'template': template == null ? null : jsonEncode(template!.toJson()),
        'instances': instances,
        'justifications': justifications,
        'notes': notes,
      };

  static FieldVisit fromJson(Map<String, Object?> j) => FieldVisit(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        number: j['number'] as int,
        technician: j['technician'] as String,
        supervisor: j['supervisor'] as String? ?? '',
        motive: j['motive'] as String? ?? '',
        templateId: j['templateId'] as String,
        scheduledAt: DateTime.tryParse(j['scheduledAt'] as String? ?? ''),
        status: ProjectStatus.values.byName(j['status'] as String),
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        endedAt: DateTime.tryParse(j['endedAt'] as String? ?? ''),
        startPoint: GeoPoint.fromJson(j['startPoint']),
        endPoint: GeoPoint.fromJson(j['endPoint']),
        template: j['template'] == null
            ? null
            : TemplateDef.fromJson((jsonDecode(j['template'] as String) as Map).cast<String, Object?>()),
        instances: (j['instances'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)),
        justifications: (j['justifications'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
        notes: j['notes'] as String? ?? '',
      );
}

enum EvidenceKind { photo, video, document, signature }

/// Archivo capturado durante una visita y ligado a una pregunta de la plantilla.
class Evidence {
  Evidence({
    required this.id,
    required this.visitId,
    required this.projectId,
    required this.key,
    required this.kind,
    required this.path,
    required this.capturedAt,
    required this.user,
    this.originalName = '',
    this.point,
    this.comment = '',
    this.imported = false,
  });

  final String id;
  final String visitId;
  final String projectId;

  /// Clave de la respuesta: `bloque#instancia/pregunta` (ver `AnswerKey`).
  final String key;
  final EvidenceKind kind;

  /// Ruta relativa a la carpeta de datos de la app.
  String path;
  DateTime capturedAt;
  final String user;
  String originalName;
  GeoPoint? point;
  String comment;

  /// Viene de la galería o de archivos (dron, termografía) y no de la cámara,
  /// por lo que no lleva marca de agua.
  bool imported;

  Map<String, Object?> toJson() => {
        'id': id,
        'visitId': visitId,
        'projectId': projectId,
        'key': key,
        'kind': kind.name,
        'path': path,
        'capturedAt': capturedAt.toIso8601String(),
        'user': user,
        'originalName': originalName,
        'point': point?.toJson(),
        'comment': comment,
        'imported': imported,
      };

  static Evidence fromJson(Map<String, Object?> j) => Evidence(
        id: j['id'] as String,
        visitId: j['visitId'] as String,
        projectId: j['projectId'] as String,
        key: j['key'] as String,
        kind: EvidenceKind.values.byName(j['kind'] as String),
        path: j['path'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        user: j['user'] as String? ?? '',
        originalName: j['originalName'] as String? ?? '',
        point: GeoPoint.fromJson(j['point']),
        comment: j['comment'] as String? ?? '',
        imported: j['imported'] as bool? ?? false,
      );
}

/// Clave con la que se guardan respuestas y evidencias de una pregunta dentro
/// de una instancia concreta de su bloque: `g_tablero#1/foto_itm`.
class AnswerKey {
  const AnswerKey(this.groupId, this.instance, this.questionId);
  final String groupId;
  final int instance;
  final String questionId;

  @override
  String toString() => '$groupId#$instance/$questionId';

  static AnswerKey parse(String s) {
    final hash = s.indexOf('#');
    final slash = s.indexOf('/', hash);
    return AnswerKey(s.substring(0, hash), int.parse(s.substring(hash + 1, slash)), s.substring(slash + 1));
  }

  @override
  bool operator ==(Object other) => other is AnswerKey && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}
