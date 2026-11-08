import 'dart:convert';

import '../auth/user_directory.dart';
import '../catalog.dart';
import '../models.dart';
import '../survey_store.dart';
import 'template.dart';

/// Nombre de un usuario para mostrar; los registros guardan su id de `perfil`.
String _userName(String? id) => UserDirectory.instance.nameOf(id);

SurveyStore? get _store => SurveyStore.isReady ? SurveyStore.instance : null;

/// Coordenada capturada por el GPS del teléfono.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  String get label => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  /// Dirección corta de Google Maps, la que se imprime en la marca de agua.
  String get mapsText => 'maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  /// Enlace que abre estas coordenadas en Google Maps (app o navegador).
  String get mapsUrl => 'https://$mapsText';

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

/// Cliente (tabla `cliente`).
class SurveyClient {
  SurveyClient({required this.id, required this.name, this.rfc = '', this.contact = ''});

  final String id;

  /// Razón social.
  String name;
  String rfc;
  String contact;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'rfc': rfc, 'contact': contact};

  static SurveyClient fromJson(Map<String, Object?> j) => SurveyClient(
        id: j['id'] as String,
        name: j['name'] as String,
        rfc: j['rfc'] as String? ?? '',
        contact: j['contact'] as String? ?? '',
      );
}

/// Sitio de un cliente (tabla `sitio`): nave, CEDIS, planta…
class SurveySite {
  SurveySite({required this.id, required this.clientId, required this.name, this.address = '', this.coords});

  final String id;
  final String clientId;
  String name;
  String address;
  GeoPoint? coords;

  Map<String, Object?> toJson() =>
      {'id': id, 'clientId': clientId, 'name': name, 'address': address, 'coords': coords?.toJson()};

  static SurveySite fromJson(Map<String, Object?> j) => SurveySite(
        id: j['id'] as String,
        clientId: j['clientId'] as String,
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
        coords: GeoPoint.fromJson(j['coords']),
      );
}

class SurveyProject {
  SurveyProject({
    required this.id,
    required this.code,
    required this.name,
    required this.siteId,
    required this.supervisorId,
    required this.technicianIds,
    required this.templateId,
    required this.typeId,
    required this.createdAt,
    this.scheduledAt,
    this.description = '',
    this.status = ProjectStatus.asignado,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;

  /// Clave del cliente o del sitio (REY01202). Da nombre al ZIP y a los archivos.
  String code;
  String name;
  String siteId;

  /// Ids de `perfil`.
  String? supervisorId;
  List<String> technicianIds;
  String templateId;
  String? typeId;
  String description;
  DateTime createdAt;
  DateTime? scheduledAt;
  ProjectStatus status;
  DateTime updatedAt;

  SurveySite? get _site => _store?.site(siteId);
  String? get clientId => _site?.clientId;
  String get client => _store?.client(clientId)?.name ?? '';
  String get site => _site?.name ?? '';
  String get address => _site?.address ?? '';
  GeoPoint? get coords => _site?.coords;
  String get supervisor => _userName(supervisorId);
  List<String> get technicians => List.unmodifiable([for (final id in technicianIds) _userName(id)]);
  String get type => _store?.catalogName(CatalogKind.projectTypes, typeId) ?? '';

  /// Copia los datos de [o] (la versión del servidor) sin cambiar de objeto,
  /// para que las pantallas abiertas vean el cambio.
  void assign(SurveyProject o) {
    code = o.code;
    name = o.name;
    siteId = o.siteId;
    supervisorId = o.supervisorId;
    technicianIds = o.technicianIds;
    templateId = o.templateId;
    typeId = o.typeId;
    description = o.description;
    createdAt = o.createdAt;
    scheduledAt = o.scheduledAt;
    status = o.status;
    updatedAt = o.updatedAt;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'siteId': siteId,
        'supervisorId': supervisorId,
        'technicianIds': technicianIds,
        'templateId': templateId,
        'typeId': typeId,
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
        siteId: j['siteId'] as String,
        supervisorId: j['supervisorId'] as String?,
        technicianIds: (j['technicianIds'] as List).cast<String>().toList(),
        templateId: j['templateId'] as String,
        typeId: j['typeId'] as String?,
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
    required this.addedById,
  });

  final String id;
  final String projectId;
  final String category;

  /// Ruta relativa a la carpeta de datos de la app (ver `FileStore`).
  final String path;
  final String originalName;
  final int size;
  final DateTime addedAt;

  /// Id de `perfil`.
  final String? addedById;
  String get addedBy => _userName(addedById);

  DocCategory get cat => DocCategory.byId(category);

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'category': category,
        'path': path,
        'originalName': originalName,
        'size': size,
        'addedAt': addedAt.toIso8601String(),
        'addedById': addedById,
      };

  static ProjectDocument fromJson(Map<String, Object?> j) => ProjectDocument(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        category: j['category'] as String,
        path: j['path'] as String,
        originalName: j['originalName'] as String,
        size: j['size'] as int? ?? 0,
        addedAt: DateTime.parse(j['addedAt'] as String),
        addedById: j['addedById'] as String?,
      );
}

class FieldVisit {
  FieldVisit({
    required this.id,
    required this.projectId,
    required this.number,
    required this.technicianId,
    required this.supervisorId,
    required this.motiveId,
    required this.templateId,
    this.scheduledAt,
    this.status = ProjectStatus.asignado,
    this.startedAt,
    this.endedAt,
    this.startPoint,
    this.endPoint,
    this.openedAt,
    this.template,
    Map<String, int>? instances,
    Map<String, String>? justifications,
    this.notes = '',
  })  : instances = instances ?? {},
        justifications = justifications ?? {};

  final String id;
  final String projectId;
  final int number;

  /// Ids de `perfil`.
  String? technicianId;
  String? supervisorId;

  /// Nulo en el levantamiento inicial (primera visita del proyecto).
  String? motiveId;
  String templateId;
  DateTime? scheduledAt;
  ProjectStatus status;
  DateTime? startedAt;
  DateTime? endedAt;
  GeoPoint? startPoint;
  GeoPoint? endPoint;

  /// Última vez que el técnico asignado abrió la visita o su proyecto.
  DateTime? openedAt;

  /// Copia de la plantilla tomada al iniciar la visita. Así, editar la
  /// plantilla después no altera un levantamiento que ya está en curso.
  TemplateDef? template;

  /// Número de instancias por bloque repetible (id del bloque → cantidad).
  Map<String, int> instances;

  /// Pendientes obligatorios que el supervisor autorizó cerrar (clave → motivo).
  Map<String, String> justifications;
  String notes;

  static const initialMotive = 'Levantamiento inicial';

  String get technician => _userName(technicianId);
  String get supervisor => _userName(supervisorId);
  String get motive =>
      motiveId == null ? initialMotive : _store?.catalogName(CatalogKind.visitMotives, motiveId) ?? '';

  String get label => 'VIS-${number.toString().padLeft(3, '0')}';
  bool get started => startedAt != null;
  bool get finished => endedAt != null;

  int instanceCount(GroupDef g) => g.repeatable ? (instances[g.id] ?? 1) : 1;

  /// Copia los datos de [o] (la versión del servidor) sin cambiar de objeto.
  void assign(FieldVisit o) {
    technicianId = o.technicianId;
    supervisorId = o.supervisorId;
    motiveId = o.motiveId;
    templateId = o.templateId;
    scheduledAt = o.scheduledAt;
    status = o.status;
    startedAt = o.startedAt;
    endedAt = o.endedAt;
    startPoint = o.startPoint;
    endPoint = o.endPoint;
    openedAt = o.openedAt;
    template = o.template;
    instances = o.instances;
    justifications = o.justifications;
    notes = o.notes;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'number': number,
        'technicianId': technicianId,
        'supervisorId': supervisorId,
        'motiveId': motiveId,
        'templateId': templateId,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'startPoint': startPoint?.toJson(),
        'endPoint': endPoint?.toJson(),
        'openedAt': openedAt?.toIso8601String(),
        'template': template == null ? null : jsonEncode(template!.toJson()),
        'instances': instances,
        'justifications': justifications,
        'notes': notes,
      };

  static FieldVisit fromJson(Map<String, Object?> j) => FieldVisit(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        number: j['number'] as int,
        technicianId: j['technicianId'] as String?,
        supervisorId: j['supervisorId'] as String?,
        motiveId: j['motiveId'] as String?,
        templateId: j['templateId'] as String,
        scheduledAt: DateTime.tryParse(j['scheduledAt'] as String? ?? ''),
        status: ProjectStatus.values.byName(j['status'] as String),
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        endedAt: DateTime.tryParse(j['endedAt'] as String? ?? ''),
        startPoint: GeoPoint.fromJson(j['startPoint']),
        endPoint: GeoPoint.fromJson(j['endPoint']),
        openedAt: DateTime.tryParse(j['openedAt'] as String? ?? ''),
        template: j['template'] == null
            ? null
            : TemplateDef.fromJson((jsonDecode(j['template'] as String) as Map).cast<String, Object?>()),
        instances: (j['instances'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)),
        justifications: (j['justifications'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)),
        notes: j['notes'] as String? ?? '',
      );
}

extension FieldVisitState on FieldVisit {
  /// Finalizada espera la aprobación del supervisor; al reabrirla vuelve a
  /// estar en curso.
  VisitState get state => !started
      ? VisitState.porIniciar
      : !finished
          ? VisitState.enCurso
          : status == ProjectStatus.aprobado
              ? VisitState.aprobada
              : VisitState.finalizada;
}

/// Problema que se encontró en la visita (tabla `hallazgo`): con código
/// propio de la visita (HZ-001), severidad y fotos. Se le da seguimiento
/// hasta cerrarlo.
class VisitFinding {
  VisitFinding({
    required this.id,
    required this.visitId,
    required this.code,
    required this.category,
    required this.severity,
    required this.description,
    required this.createdAt,
    this.userId,
    this.location = '',
    this.recommendation = '',
    this.status = FindingStatus.abierto,
    this.point,
  });

  final String id;
  final String visitId;

  /// HZ-001, único dentro de la visita.
  final String code;
  FindingCategory category;
  Severity severity;
  String description;
  String location;
  String recommendation;
  FindingStatus status;
  final GeoPoint? point;
  final DateTime createdAt;

  /// Id de `perfil` de quien lo registró.
  final String? userId;
  String get user => _userName(userId);

  bool get open => status != FindingStatus.cerrado;

  Map<String, Object?> toJson() => {
        'id': id,
        'visitId': visitId,
        'code': code,
        'category': category.name,
        'severity': severity.name,
        'description': description,
        'location': location,
        'recommendation': recommendation,
        'status': status.name,
        'point': point?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'userId': userId,
      };

  static VisitFinding fromJson(Map<String, Object?> j) => VisitFinding(
        id: j['id'] as String,
        visitId: j['visitId'] as String,
        code: j['code'] as String,
        category: FindingCategory.values.asNameMap()[j['category']] ?? FindingCategory.otro,
        severity: Severity.values.asNameMap()[j['severity']] ?? Severity.media,
        description: j['description'] as String? ?? '',
        location: j['location'] as String? ?? '',
        recommendation: j['recommendation'] as String? ?? '',
        status: FindingStatus.values.asNameMap()[j['status']] ?? FindingStatus.abierto,
        point: GeoPoint.fromJson(j['point']),
        createdAt: DateTime.parse(j['createdAt'] as String),
        userId: j['userId'] as String?,
      );
}

enum ReviewDecision { approved, corrections }

/// Decisión del supervisor sobre una visita terminada (tabla `revision`). No
/// se edita: cada vez que revisa queda un registro nuevo.
class VisitReview {
  VisitReview({
    required this.id,
    required this.visitId,
    required this.supervisorId,
    required this.decision,
    required this.createdAt,
    this.notes = '',
  });

  final String id;
  final String visitId;

  /// Id de `perfil` de quien revisó.
  final String? supervisorId;
  String get supervisor => _userName(supervisorId);
  final ReviewDecision decision;
  final String notes;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'visitId': visitId,
        'supervisorId': supervisorId,
        'decision': decision.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  static VisitReview fromJson(Map<String, Object?> j) => VisitReview(
        id: j['id'] as String,
        visitId: j['visitId'] as String,
        supervisorId: j['supervisorId'] as String?,
        decision: ReviewDecision.values.byName(j['decision'] as String),
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Algo que el supervisor pidió corregir en una revisión (tabla
/// `correccion`). El técnico la marca como atendida.
class Correction {
  Correction({
    required this.id,
    required this.reviewId,
    required this.visitId,
    required this.description,
    required this.createdAt,
    this.attendedAt,
  });

  final String id;
  final String reviewId;

  /// Visita de su revisión; en la base sólo se llega por la revisión.
  final String visitId;
  final String description;
  final DateTime createdAt;
  DateTime? attendedAt;
  bool get attended => attendedAt != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'reviewId': reviewId,
        'visitId': visitId,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'attendedAt': attendedAt?.toIso8601String(),
      };

  static Correction fromJson(Map<String, Object?> j) => Correction(
        id: j['id'] as String,
        reviewId: j['reviewId'] as String,
        visitId: j['visitId'] as String,
        description: j['description'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        attendedAt: j['attendedAt'] == null ? null : DateTime.parse(j['attendedAt'] as String),
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
    required this.userId,
    this.originalName = '',
    this.point,
    this.comment = '',
    this.imported = false,
    this.findingId,
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

  /// Id de `perfil` de quien capturó.
  final String? userId;
  String get user => _userName(userId);
  String originalName;
  GeoPoint? point;
  String comment;

  /// Viene de la galería o de archivos (dron, termografía) y no de la cámara,
  /// por lo que no lleva marca de agua.
  bool imported;

  /// Hallazgo al que pertenece; entonces no es de ninguna pregunta y [key]
  /// queda vacía.
  final String? findingId;

  Map<String, Object?> toJson() => {
        'id': id,
        'visitId': visitId,
        'projectId': projectId,
        'key': key,
        'kind': kind.name,
        'path': path,
        'capturedAt': capturedAt.toIso8601String(),
        'userId': userId,
        'originalName': originalName,
        'point': point?.toJson(),
        'comment': comment,
        'imported': imported,
        'findingId': findingId,
      };

  static Evidence fromJson(Map<String, Object?> j) => Evidence(
        id: j['id'] as String,
        visitId: j['visitId'] as String,
        projectId: j['projectId'] as String,
        key: j['key'] as String,
        kind: EvidenceKind.values.byName(j['kind'] as String),
        path: j['path'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        userId: j['userId'] as String?,
        originalName: j['originalName'] as String? ?? '',
        point: GeoPoint.fromJson(j['point']),
        comment: j['comment'] as String? ?? '',
        imported: j['imported'] as bool? ?? false,
        findingId: j['findingId'] as String?,
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

  /// Nula si [s] no es una clave (p. ej. la de una foto de hallazgo).
  static AnswerKey? tryParse(String s) => s.contains('#') && s.contains('/') ? parse(s) : null;

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
