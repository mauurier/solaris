import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
    return init(db, FileStore(Directory(p.join(dir.path, 'solaris_media'))));
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
  final projects = <SurveyProject>[];
  final documents = <ProjectDocument>[];
  final visits = <FieldVisit>[];
  final _answers = <String, Map<String, String>>{};
  final evidences = <Evidence>[];

  String get _user => AppState.instance.userName;

  Future<void> _load() async {
    templates.addAll((await db.load(Tables.templates)).map(TemplateDef.fromJson));
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
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // ---------------------------------------------------------------- plantillas

  TemplateDef? template(String id) => templates.where((t) => t.id == id).firstOrNull;

  List<TemplateDef> get activeTemplates => templates.where((t) => t.active).toList();

  bool templateInUse(TemplateDef t) => projects.any((p) => p.templateId == t.id);

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
      'id': 'tpl-${_uuid.v4()}',
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
    if (templateInUse(t)) throw StateError('La plantilla está asignada a proyectos');
    templates.remove(t);
    await db.remove(Tables.templates, t.id);
    notifyListeners();
  }

  // ---------------------------------------------------------------- proyectos

  SurveyProject? project(String id) => projects.where((p) => p.id == id).firstOrNull;

  /// El técnico sólo ve los proyectos que tiene asignados.
  List<SurveyProject> projectsFor(UserRole role, String user) {
    if (role != UserRole.tecnico) return List.of(projects);
    return projects.where((p) => p.technicians.contains(user)).toList();
  }

  Future<SurveyProject> createProject({
    required String code,
    required String name,
    required String client,
    required String site,
    required String address,
    required GeoPoint? coords,
    required DateTime? scheduledAt,
    required String supervisor,
    required List<String> technicians,
    required TemplateDef template,
    required String type,
    String description = '',
    List<PickedDocument> docs = const [],
  }) async {
    final now = DateTime.now();
    final project = SurveyProject(
      id: _uuid.v4(),
      code: code.trim().toUpperCase(),
      name: name.trim(),
      client: client,
      site: site.trim(),
      address: address.trim(),
      coords: coords,
      scheduledAt: scheduledAt,
      supervisor: supervisor,
      technicians: technicians,
      templateId: template.id,
      type: type,
      description: description.trim(),
      createdAt: now,
      status: technicians.isEmpty ? ProjectStatus.borrador : ProjectStatus.asignado,
    );
    projects.insert(0, project);
    await db.put(Tables.projects, project.id, project.toJson());
    for (final d in docs) {
      await _addDocument(project.id, d.category, d.file, d.name);
    }
    if (technicians.isNotEmpty) {
      await _createVisit(project, technicians.first, 'Levantamiento inicial', scheduledAt);
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
      addedBy: _user,
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
  FieldVisit? activeVisitFor(String user) {
    final list = visits.where((v) => v.started && !v.finished && v.technician == user).toList()
      ..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
    return list.firstOrNull;
  }

  Future<FieldVisit> createVisit(SurveyProject project,
      {required String technician, required String motive, DateTime? scheduledAt}) async {
    final v = await _createVisit(project, technician, motive, scheduledAt);
    if (!project.technicians.contains(technician)) project.technicians.add(technician);
    project.status = ProjectStatus.asignado;
    await updateProject(project);
    return v;
  }

  Future<FieldVisit> _createVisit(
      SurveyProject project, String technician, String motive, DateTime? scheduledAt) async {
    final number = visitsOf(project.id).fold(0, (m, v) => v.number > m ? v.number : m) + 1;
    final v = FieldVisit(
      id: _uuid.v4(),
      projectId: project.id,
      number: number,
      technician: technician,
      supervisor: project.supervisor,
      motive: motive,
      templateId: project.templateId,
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
      v.justifications[key.toString()] = '${reason.trim()} — $_user';
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
        {'visitId': v.id, 'key': k, 'value': value, 'user': _user, 'at': DateTime.now().toIso8601String()},
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
      user: _user,
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

  Future<void> _touch(String projectId) async {
    final proj = project(projectId);
    if (proj == null) return;
    proj.updatedAt = DateTime.now();
    await db.put(Tables.projects, proj.id, proj.toJson());
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
