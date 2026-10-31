import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'catalog.dart';
import 'mock_data.dart';
import 'models.dart';
import 'storage/file_store.dart';
import 'storage/persistence.dart';
import 'storage/sqlite_persistence.dart';
import 'survey/default_template.dart';
import 'survey/entities.dart';
import 'survey/template.dart';
import 'survey/visit_engine.dart';

const _uuid = Uuid();

/// Documento elegido en el alta de proyecto, antes de copiarse a la app.
class PickedDocument {
  const PickedDocument({required this.category, required this.file, required this.name});
  final String category;
  final File file;
  final String name;
}

/// Fuente única de datos del levantamiento (offline).
///
/// Mantiene en memoria proyectos, visitas, respuestas y evidencias, y escribe
/// cada cambio en [Persistence] antes de notificar a la interfaz.
class SurveyStore extends ChangeNotifier {
  SurveyStore._(this.db, this.files);

  final Persistence db;
  final FileStore files;

  static SurveyStore? _instance;
  static SurveyStore get instance {
    final s = _instance;
    if (s == null) throw StateError('SurveyStore.init() no se ha llamado');
    return s;
  }

  static bool get isReady => _instance != null;

  /// Abre SQLite en la carpeta de documentos de la app.
  static Future<SurveyStore> initDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = await SqlitePersistence.open(p.join(dir.path, 'solaris.db'));
    final files = FileStore(Directory(p.join(dir.path, 'solaris_media')));
    // Los archivos de los datos de prueba borrados con la base anterior.
    if (db.wiped) await files.deleteDir('media');
    return init(db, files);
  }

  static Future<SurveyStore> init(Persistence db, FileStore files) async {
    final s = SurveyStore._(db, files);
    await s._load();
    _instance = s;
    return s;
  }

  /// Sólo para pruebas: deja el store listo sin tocar disco para metadatos.
  @visibleForTesting
  static void reset() => _instance = null;

  final templates = <TemplateDef>[];
  final clients = <SurveyClient>[];
  final sites = <SurveySite>[];
  final projects = <SurveyProject>[];
  final documents = <ProjectDocument>[];
  final visits = <FieldVisit>[];
  final _answers = <String, Map<String, String>>{};
  final evidences = <Evidence>[];

  /// Valores con los que arranca cada catálogo en una instalación nueva. Los
  /// ids son los de la semilla de la migración en Supabase.
  static const catalogDefaults = {
    CatalogKind.projectTypes: [
      ('e6b6d468-97a4-426b-bd03-1e2e5206ffed', 'Viabilidad FV'),
      ('ea668741-7260-4c3e-8315-427c745def20', 'Levantamiento eléctrico'),
      ('6e0e2d68-e19c-4055-aa64-543ce1117e3b', 'Auditoría FV'),
      ('b81f5896-3ab3-4818-b041-6d59c6952b3d', 'Mantenimiento FV'),
    ],
    CatalogKind.visitMotives: [
      ('24a85d2f-329a-4480-98cf-35df3e5b115b', 'Información incompleta'),
      ('4dcae868-a14f-461c-8554-ce15db2bf717', 'Mediciones adicionales'),
      ('5cf58ef5-c63d-4ebe-a9a3-a1273fbf640c', 'Corrección de información'),
      ('b95699bc-09d3-4d43-8918-6cdf92070694', 'Actividades posteriores'),
    ],
  };

  late final _catalogs = {
    CatalogKind.projectTypes: Catalog(
      db,
      Tables.projectTypes,
      uses: (id) => projects.where((p) => p.typeId == id).length,
    ),
    CatalogKind.visitMotives: Catalog(
      db,
      Tables.visitMotives,
      uses: (id) => visits.where((v) => v.motiveId == id).length,
    ),
  };

  /// Id de `perfil` de quien hace el cambio.
  String get _userId => AppState.instance.userId;
  String get _userName => AppState.instance.userName;

  Future<void> _load() async {
    templates.addAll((await db.load(Tables.templates)).map(TemplateDef.fromJson));
    clients.addAll((await db.load(Tables.clients)).map(SurveyClient.fromJson));
    sites.addAll((await db.load(Tables.sites)).map(SurveySite.fromJson));
    projects.addAll((await db.load(Tables.projects)).map(SurveyProject.fromJson));
    documents.addAll((await db.load(Tables.documents)).map(ProjectDocument.fromJson));
    visits.addAll((await db.load(Tables.visits)).map(FieldVisit.fromJson));
    evidences.addAll((await db.load(Tables.evidences)).map(Evidence.fromJson));
    for (final row in await db.load(Tables.answers)) {
      _answers.putIfAbsent(row['visitId'] as String, () => {})[row['key'] as String] = row['value'] as String;
    }
    if (templates.isEmpty) {
      final t = defaultElectricTemplate();
      templates.add(t);
      await db.put(Tables.templates, t.id, t.toJson());
    }
    for (final e in _catalogs.entries) {
      await e.value.load(catalogDefaults[e.key]!);
    }
    clients.sort(_byName);
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static int _byName(SurveyClient a, SurveyClient b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

  // ---------------------------------------------------------------- plantillas

  TemplateDef? template(String id) => templates.where((t) => t.id == id).firstOrNull;

  List<TemplateDef> get activeTemplates => templates.where((t) => t.active).toList();

  /// Una visita puede usar una plantilla distinta a la de su proyecto.
  bool templateInUse(TemplateDef t) =>
      projects.any((p) => p.templateId == t.id) || visits.any((v) => v.templateId == t.id);

  /// Guarda cambios del editor como versión menor nueva (v1.0 → v1.1).
  /// Las visitas ya iniciadas conservan su copia y no se ven afectadas.
  Future<void> saveTemplate(TemplateDef edited) async {
    final i = templates.indexWhere((t) => t.id == edited.id);
    edited.updatedAt = DateTime.now();
    if (i >= 0) {
      edited.minor = templates[i].minor + 1;
      edited.major = templates[i].major;
      templates[i] = edited;
    } else {
      templates.add(edited);
    }
    await db.put(Tables.templates, edited.id, edited.toJson());
    notifyListeners();
  }

  Future<TemplateDef> duplicateTemplate(TemplateDef source) async {
    final copy = TemplateDef.fromJson({
      ...source.toJson(),
      'id': _uuid.v4(),
      'name': '${source.name} (copia)',
      'major': 1,
      'minor': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    templates.add(copy);
    await db.put(Tables.templates, copy.id, copy.toJson());
    notifyListeners();
    return copy;
  }

  Future<void> setTemplateActive(TemplateDef t, bool active) async {
    t.active = active;
    await db.put(Tables.templates, t.id, t.toJson());
    notifyListeners();
  }

  Future<void> deleteTemplate(TemplateDef t) async {
    if (templateInUse(t)) throw StateError('La plantilla está asignada a proyectos o visitas');
    templates.remove(t);
    await db.remove(Tables.templates, t.id);
    notifyListeners();
  }

  // ---------------------------------------------------------------- catálogos

  List<CatalogItem> catalog(CatalogKind kind) => _catalogs[kind]!.items;

  /// Nombre del elemento; vacío si no existe (p. ej. se borró).
  String catalogName(CatalogKind kind, String? id) => _catalogs[kind]!.byId(id)?.name ?? '';

  /// Registros que usan el elemento; sólo se puede borrar si no hay ninguno.
  int catalogUses(CatalogKind kind, CatalogItem item) => _catalogs[kind]!.uses(item.id);

  /// Motivo por el que [name] no es válido, o `null` si se puede usar.
  String? validateCatalogName(CatalogKind kind, String name, {CatalogItem? except}) =>
      _catalogs[kind]!.validate(name, except: except);

  Future<CatalogItem> addCatalogItem(CatalogKind kind, String name) async {
    final item = await _catalogs[kind]!.add(name);
    notifyListeners();
    return item;
  }

  Future<void> renameCatalogItem(CatalogKind kind, CatalogItem item, String name) async {
    await _catalogs[kind]!.rename(item, name);
    notifyListeners();
  }

  Future<void> removeCatalogItem(CatalogKind kind, CatalogItem item) async {
    await _catalogs[kind]!.remove(item);
    notifyListeners();
  }

  // --------------------------------------------------------- clientes y sitios

  SurveyClient? client(String? id) => clients.where((c) => c.id == id).firstOrNull;
  SurveySite? site(String? id) => sites.where((s) => s.id == id).firstOrNull;
  List<SurveySite> sitesOf(String clientId) => sites.where((s) => s.clientId == clientId).toList();

  /// Proyectos de los sitios del cliente.
  int projectsOfClient(String clientId) => projects.where((p) => p.clientId == clientId).length;

  /// Motivo por el que el cliente no es válido, o `null` si se puede guardar.
  String? validateClient(String name, {String rfc = '', SurveyClient? except}) {
    final n = name.trim();
    if (n.isEmpty) return 'Escribe la razón social';
    final r = rfc.trim().toUpperCase();
    if (r.isNotEmpty && clients.any((c) => c != except && c.rfc.toUpperCase() == r)) {
      return 'Ya hay un cliente con ese RFC';
    }
    if (clients.any((c) => c != except && c.name.toLowerCase() == n.toLowerCase())) {
      return 'Ya existe un cliente con ese nombre';
    }
    return null;
  }

  Future<SurveyClient> addClient(String name, {String rfc = '', String contact = ''}) async {
    final error = validateClient(name, rfc: rfc);
    if (error != null) throw ArgumentError(error);
    final c = SurveyClient(id: _uuid.v4(), name: name.trim(), rfc: rfc.trim().toUpperCase(), contact: contact.trim());
    clients
      ..add(c)
      ..sort(_byName);
    await db.put(Tables.clients, c.id, c.toJson());
    notifyListeners();
    return c;
  }

  Future<void> updateClient(SurveyClient c) async {
    clients.sort(_byName);
    await db.put(Tables.clients, c.id, c.toJson());
    notifyListeners();
  }

  /// El sitio del cliente con ese nombre, o uno nuevo. La dirección y las
  /// coordenadas escritas en el alta de proyecto actualizan las del sitio.
  Future<SurveySite> _siteFor(String clientId, String name, String address, GeoPoint? coords) async {
    final n = name.trim();
    final existing = sitesOf(clientId).where((s) => s.name.toLowerCase() == n.toLowerCase()).firstOrNull;
    final site = existing ?? SurveySite(id: _uuid.v4(), clientId: clientId, name: n);
    if (existing == null) sites.add(site);
    if (address.trim().isNotEmpty) site.address = address.trim();
    if (coords != null) site.coords = coords;
    await db.put(Tables.sites, site.id, site.toJson(), parent: clientId);
    return site;
  }

  // ---------------------------------------------------------------- proyectos

  SurveyProject? project(String id) => projects.where((p) => p.id == id).firstOrNull;

  /// El técnico sólo ve los proyectos que tiene asignados.
  List<SurveyProject> projectsFor(UserRole role, String userId) {
    if (role != UserRole.tecnico) return List.of(projects);
    return projects.where((p) => p.technicianIds.contains(userId)).toList();
  }

  /// [supervisorId] y [technicianIds] son ids de `perfil`; el primer técnico
  /// recibe el levantamiento inicial.
  Future<SurveyProject> createProject({
    required String code,
    required String name,
    required String clientId,
    required String site,
    required String address,
    required GeoPoint? coords,
    required DateTime? scheduledAt,
    required String? supervisorId,
    required List<String> technicianIds,
    required TemplateDef template,
    required String? typeId,
    String description = '',
    List<PickedDocument> docs = const [],
  }) async {
    final now = DateTime.now();
    final s = await _siteFor(clientId, site, address, coords);
    final project = SurveyProject(
      id: _uuid.v4(),
      code: code.trim().toUpperCase(),
      name: name.trim(),
      siteId: s.id,
      scheduledAt: scheduledAt,
      supervisorId: supervisorId,
      technicianIds: technicianIds,
      templateId: template.id,
      typeId: typeId,
      description: description.trim(),
      createdAt: now,
      status: technicianIds.isEmpty ? ProjectStatus.borrador : ProjectStatus.asignado,
    );
    projects.insert(0, project);
    await db.put(Tables.projects, project.id, project.toJson());
    for (final d in docs) {
      await _addDocument(project.id, d.category, d.file, d.name);
    }
    if (technicianIds.isNotEmpty) {
      await _createVisit(project, technicianIds.first, null, scheduledAt);
    }
    notifyListeners();
    return project;
  }

  Future<void> updateProject(SurveyProject proj) async {
    proj.updatedAt = DateTime.now();
    await db.put(Tables.projects, proj.id, proj.toJson());
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<void> deleteProject(SurveyProject proj) async {
    for (final v in visitsOf(proj.id)) {
      await db.removeByParent(Tables.answers, v.id);
      await db.removeByParent(Tables.evidences, v.id);
      _answers.remove(v.id);
    }
    await db.removeByParent(Tables.visits, proj.id);
    await db.removeByParent(Tables.documents, proj.id);
    await db.remove(Tables.projects, proj.id);
    visits.removeWhere((v) => v.projectId == proj.id);
    documents.removeWhere((d) => d.projectId == proj.id);
    evidences.removeWhere((e) => e.projectId == proj.id);
    projects.remove(proj);
    await files.deleteDir(p.join('media', proj.id));
    notifyListeners();
  }

  // ---------------------------------------------------------------- documentos

  List<ProjectDocument> documentsOf(String projectId) =>
      documents.where((d) => d.projectId == projectId).toList()..sort((a, b) => a.addedAt.compareTo(b.addedAt));

  Set<String> docCategoriesOf(String projectId) => documentsOf(projectId).map((d) => d.category).toSet();

  Future<ProjectDocument> addDocument(String projectId, String category, File file, String name) async {
    final doc = await _addDocument(projectId, category, file, name);
    await _touch(projectId);
    notifyListeners();
    return doc;
  }

  Future<ProjectDocument> _addDocument(String projectId, String category, File file, String name) async {
    final id = _uuid.v4();
    final rel = await files.importFile(file, p.join('media', projectId, 'docs'), '$id${p.extension(name)}');
    final doc = ProjectDocument(
      id: id,
      projectId: projectId,
      category: category,
      path: rel,
      originalName: name,
      size: files.sizeOf(rel),
      addedAt: DateTime.now(),
      addedById: _userId,
    );
    documents.add(doc);
    await db.put(Tables.documents, doc.id, doc.toJson(), parent: projectId);
    return doc;
  }

  Future<void> removeDocument(ProjectDocument d) async {
    documents.remove(d);
    await db.remove(Tables.documents, d.id);
    await files.delete(d.path);
    notifyListeners();
  }

  // ------------------------------------------------------------------ visitas

  FieldVisit? visit(String id) => visits.where((v) => v.id == id).firstOrNull;

  List<FieldVisit> visitsOf(String projectId) =>
      visits.where((v) => v.projectId == projectId).toList()..sort((a, b) => b.number.compareTo(a.number));

  FieldVisit? latestVisit(String projectId) => visitsOf(projectId).firstOrNull;

  /// Visita que el usuario tiene iniciada y sin cerrar, si hay alguna.
  /// Visita en curso del técnico: la del último proyecto activo que abrió.
  /// Si aún no ha abierto ninguna, la iniciada más recientemente.
  FieldVisit? activeVisitFor(String userId) => activeVisitsFor(userId).firstOrNull;

  /// Visitas en curso del técnico, de la que abrió al último a la más antigua.
  List<FieldVisit> activeVisitsFor(String userId) {
    DateTime last(FieldVisit v) => v.openedAt ?? v.startedAt!;
    return visits.where((v) => v.started && !v.finished && v.technicianId == userId).toList()
      ..sort((a, b) => last(b).compareTo(last(a)));
  }

  /// Visita de referencia del inicio del técnico: la en curso que abrió al
  /// último o, si no tiene ninguna, la que terminó más recientemente.
  FieldVisit? recentVisitFor(String userId) {
    final active = activeVisitFor(userId);
    if (active != null) return active;
    final done = visits.where((v) => v.finished && v.technicianId == userId).toList()
      ..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
    return done.firstOrNull;
  }

  /// El técnico abrió la visita; sólo cuenta si es suya y está en curso.
  Future<void> markVisitOpened(FieldVisit v, String userId) async {
    if (v.technicianId != userId || !v.started || v.finished) return;
    v.openedAt = DateTime.now();
    // Abrir no es modificar: no se toca la actividad del proyecto.
    await db.put(Tables.visits, v.id, v.toJson(), parent: v.projectId);
    notifyListeners();
  }

  /// El técnico abrió el proyecto: cuenta como abrir su visita en curso.
  Future<void> markProjectOpened(String projectId, String userId) async {
    final v = visitsOf(projectId).where((v) => v.started && !v.finished && v.technicianId == userId).firstOrNull;
    if (v != null) await markVisitOpened(v, userId);
  }

  /// Visita adicional. Por defecto usa la plantilla del proyecto, pero puede
  /// llevar otra (p. ej. una de mantenimiento en un proyecto de viabilidad).
  /// [motiveId] nulo = levantamiento inicial.
  Future<FieldVisit> createVisit(SurveyProject project,
      {required String technicianId, required String? motiveId, DateTime? scheduledAt, String? templateId}) async {
    final v = await _createVisit(project, technicianId, motiveId, scheduledAt, templateId: templateId);
    if (!project.technicianIds.contains(technicianId)) project.technicianIds.add(technicianId);
    project.status = ProjectStatus.asignado;
    await updateProject(project);
    return v;
  }

  Future<FieldVisit> _createVisit(SurveyProject project, String technicianId, String? motiveId, DateTime? scheduledAt,
      {String? templateId}) async {
    final number = visitsOf(project.id).fold(0, (m, v) => v.number > m ? v.number : m) + 1;
    final v = FieldVisit(
      id: _uuid.v4(),
      projectId: project.id,
      number: number,
      technicianId: technicianId,
      supervisorId: project.supervisorId,
      motiveId: motiveId,
      templateId: templateId ?? project.templateId,
      scheduledAt: scheduledAt,
    );
    visits.add(v);
    await db.put(Tables.visits, v.id, v.toJson(), parent: project.id);
    return v;
  }

  /// Guarda cambios de técnico o supervisor de una visita no iniciada.
  Future<void> updateVisitAssignment(FieldVisit v) async {
    await _saveVisit(v);
    notifyListeners();
  }

  TemplateDef templateFor(FieldVisit v) =>
      v.template ?? template(v.templateId) ?? templates.firstWhere((t) => t.active, orElse: () => templates.first);

  Future<void> _saveVisit(FieldVisit v) async {
    await db.put(Tables.visits, v.id, v.toJson(), parent: v.projectId);
    await _touch(v.projectId);
  }

  /// Registra hora y ubicación de inicio y congela la plantilla vigente.
  Future<void> startVisit(FieldVisit v, GeoPoint? point) async {
    v.startedAt = DateTime.now();
    v.startPoint = point;
    v.template = templateFor(v).copy();
    v.status = ProjectStatus.enCaptura;
    final proj = project(v.projectId);
    if (proj != null) proj.status = ProjectStatus.enCaptura;
    await _saveVisit(v);
    notifyListeners();
  }

  /// Cierra la visita. Queda pendiente de sincronizar hasta que exista backend.
  Future<void> finishVisit(FieldVisit v, GeoPoint? point, {String notes = ''}) async {
    v.endedAt = DateTime.now();
    v.endPoint = point;
    v.notes = notes;
    v.status = ProjectStatus.pendienteSync;
    final proj = project(v.projectId);
    if (proj != null) proj.status = ProjectStatus.pendienteSync;
    await _saveVisit(v);
    notifyListeners();
  }

  /// El supervisor puede reabrir una visita cerrada para corregirla.
  /// Visitas finalizadas que esperan aprobación, la más antigua primero.
  List<FieldVisit> get visitsToApprove => visits.where((v) => v.state == VisitState.finalizada).toList()
    ..sort((a, b) => a.endedAt!.compareTo(b.endedAt!));

  /// El supervisor aprueba una visita finalizada. El proyecto queda aprobado
  /// cuando todas sus visitas lo están.
  Future<void> approveVisit(FieldVisit v) async {
    if (!v.finished) throw StateError('Sólo se aprueba una visita finalizada');
    v.status = ProjectStatus.aprobado;
    final proj = project(v.projectId);
    if (proj != null && visitsOf(proj.id).every((x) => x.status == ProjectStatus.aprobado)) {
      proj.status = ProjectStatus.aprobado;
    }
    await _saveVisit(v);
    notifyListeners();
  }

  Future<void> reopenVisit(FieldVisit v) async {
    v.endedAt = null;
    v.endPoint = null;
    v.status = ProjectStatus.enCaptura;
    final proj = project(v.projectId);
    if (proj != null) proj.status = ProjectStatus.conCorrecciones;
    await _saveVisit(v);
    notifyListeners();
  }

  Future<void> addInstance(FieldVisit v, GroupDef g) async {
    v.instances[g.id] = v.instanceCount(g) + 1;
    await _saveVisit(v);
    notifyListeners();
  }

  /// Quita la última instancia de un bloque junto con sus respuestas y archivos.
  Future<void> removeLastInstance(FieldVisit v, GroupDef g) async {
    final count = v.instanceCount(g);
    if (count <= 1) return;
    final last = count - 1;
    final prefix = '${g.id}#$last/';
    final answers = _answers[v.id] ?? {};
    for (final k in answers.keys.where((k) => k.startsWith(prefix)).toList()) {
      answers.remove(k);
      await db.remove(Tables.answers, '${v.id}|$k');
    }
    for (final e in evidences.where((e) => e.visitId == v.id && e.key.startsWith(prefix)).toList()) {
      await _deleteEvidence(e);
    }
    v.instances[g.id] = last;
    await _saveVisit(v);
    notifyListeners();
  }

  Future<void> justify(FieldVisit v, AnswerKey key, String? reason) async {
    if (reason == null || reason.trim().isEmpty) {
      v.justifications.remove(key.toString());
    } else {
      v.justifications[key.toString()] = '${reason.trim()} — $_userName';
    }
    await _saveVisit(v);
    notifyListeners();
  }

  // ----------------------------------------------------------------- respuestas

  Map<String, String> answersOf(String visitId) => _answers[visitId] ?? const {};

  Future<void> setAnswer(FieldVisit v, AnswerKey key, String? value) async {
    final map = _answers.putIfAbsent(v.id, () => {});
    final k = key.toString();
    final rowId = '${v.id}|$k';
    if (value == null || value.isEmpty) {
      if (map.remove(k) == null) return;
      await db.remove(Tables.answers, rowId);
    } else {
      if (map[k] == value) return;
      map[k] = value;
      await db.put(
        Tables.answers,
        rowId,
        {'visitId': v.id, 'key': k, 'value': value, 'userId': _userId, 'at': DateTime.now().toIso8601String()},
        parent: v.id,
      );
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- evidencias

  List<Evidence> evidenceOf(String visitId, [AnswerKey? key]) {
    final k = key?.toString();
    return evidences.where((e) => e.visitId == visitId && (k == null || e.key == k)).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  }

  List<Evidence> evidenceOfProject(String projectId) =>
      evidences.where((e) => e.projectId == projectId).toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

  Future<Evidence> addEvidence({
    required FieldVisit visit,
    required AnswerKey key,
    required EvidenceKind kind,
    required File file,
    String originalName = '',
    GeoPoint? point,
    DateTime? capturedAt,
    String comment = '',
    bool imported = false,
    bool moveFile = false,
  }) async {
    final id = _uuid.v4();
    final ext = p.extension(originalName.isNotEmpty ? originalName : file.path);
    final rel = await files.importFile(file, p.join('media', visit.projectId, visit.id), '$id$ext', move: moveFile);
    final e = Evidence(
      id: id,
      visitId: visit.id,
      projectId: visit.projectId,
      key: key.toString(),
      kind: kind,
      path: rel,
      capturedAt: capturedAt ?? DateTime.now(),
      userId: _userId,
      originalName: originalName.isNotEmpty ? originalName : p.basename(file.path),
      point: point,
      comment: comment,
      imported: imported,
    );
    evidences.add(e);
    await db.put(Tables.evidences, e.id, e.toJson(), parent: visit.id);
    await _touch(visit.projectId);
    notifyListeners();
    return e;
  }

  /// "Reemplazar fotografía": conserva el registro y cambia el archivo.
  Future<void> replaceEvidenceFile(Evidence e, File file,
      {GeoPoint? point, DateTime? capturedAt, bool imported = false, bool moveFile = false}) async {
    final old = e.path;
    final ext = p.extension(file.path);
    final rel = await files.importFile(
        file, p.dirname(old), '${e.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
        move: moveFile);
    e.path = rel;
    e.point = point;
    e.capturedAt = capturedAt ?? DateTime.now();
    e.imported = imported;
    await db.put(Tables.evidences, e.id, e.toJson(), parent: e.visitId);
    await files.delete(old);
    notifyListeners();
  }

  Future<void> updateEvidence(Evidence e) async {
    await db.put(Tables.evidences, e.id, e.toJson(), parent: e.visitId);
    notifyListeners();
  }

  Future<void> removeEvidence(Evidence e) async {
    await _deleteEvidence(e);
    notifyListeners();
  }

  Future<void> _deleteEvidence(Evidence e) async {
    evidences.remove(e);
    await db.remove(Tables.evidences, e.id);
    await files.delete(e.path);
  }

  // ------------------------------------------------------------------- cálculo

  VisitEngine engineFor(FieldVisit v) => VisitEngine(
        template: templateFor(v),
        instances: v.instances,
        answers: answersOf(v.id),
        evidences: evidenceOf(v.id),
        projectDocCategories: docCategoriesOf(v.projectId),
        justifications: v.justifications,
      );

  /// Avance del proyecto = avance de su visita más reciente.
  double progressOf(SurveyProject proj) {
    final v = latestVisit(proj.id);
    if (v == null || !v.started) return 0;
    return engineFor(v).overall.value;
  }

  /// Pendientes obligatorios de las visitas en curso del proyecto.
  int blockingPendingsOf(String projectId) => visitsOf(projectId)
      .where((v) => v.started && !v.finished)
      .fold(0, (a, v) => a + engineFor(v).blockingCount);

  Future<void> _touch(String projectId) async {
    final proj = project(projectId);
    if (proj == null) return;
    proj.updatedAt = DateTime.now();
    await db.put(Tables.projects, proj.id, proj.toJson());
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
