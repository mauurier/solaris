/// Fila que cambió en el teléfono y falta subir al servidor.
class PendingRow {
  const PendingRow({required this.id, required this.data, required this.deleted, this.parent});
  final String id;
  final String? parent;
  final Map<String, Object?> data;

  /// Se borró en el teléfono: en el servidor se marca `eliminado_en`.
  final bool deleted;
}

/// Almacén de registros usado por `SurveyStore`.
///
/// Cada tabla guarda filas `id → datos JSON`, con un `parent` opcional
/// (proyecto o visita) para borrar en cascada. Nada se borra de verdad: las
/// filas borradas se ocultan y quedan pendientes, para que la sincronización
/// también borre en el servidor. Cada escritura marca la fila como pendiente
/// de subir. La implementación real es SQLite ([SqlitePersistence]); las
/// pruebas usan [MemoryPersistence].
abstract class Persistence {
  /// Filas no borradas.
  Future<List<Map<String, Object?>>> load(String table);

  /// [pending] en falso es para lo que llega del servidor: ya está arriba.
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true});
  Future<void> remove(String table, String id);
  Future<void> removeByParent(String table, String parent);

  /// Filas cambiadas o borradas que falta subir.
  Future<List<PendingRow>> pending(String table);

  /// La fila ya está en el servidor.
  Future<void> markSynced(String table, String id);
}

/// Tablas del esquema. Mantener en sincronía con [SqlitePersistence].
class Tables {
  Tables._();
  static const templates = 'templates';
  static const clients = 'clients';
  static const sites = 'sites';
  static const projects = 'projects';
  static const documents = 'documents';
  static const visits = 'visits';
  static const answers = 'answers';
  static const evidences = 'evidences';
  static const projectTypes = 'project_types';
  static const visitMotives = 'visit_motives';

  static const all = [
    templates,
    clients,
    sites,
    projects,
    documents,
    visits,
    answers,
    evidences,
    projectTypes,
    visitMotives,
  ];
}

class MemoryPersistence implements Persistence {
  final _tables = <String, Map<String, ({String? parent, Map<String, Object?> data, bool pending, bool deleted})>>{};

  Map<String, ({String? parent, Map<String, Object?> data, bool pending, bool deleted})> _t(String table) =>
      _tables.putIfAbsent(table, () => {});

  @override
  Future<List<Map<String, Object?>>> load(String table) async =>
      _t(table).values.where((r) => !r.deleted).map((r) => Map<String, Object?>.of(r.data)).toList();

  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true}) async {
    _t(table)[id] = (parent: parent, data: Map.of(data), pending: pending, deleted: false);
  }

  @override
  Future<void> remove(String table, String id) async {
    final r = _t(table)[id];
    if (r != null) _t(table)[id] = (parent: r.parent, data: r.data, pending: true, deleted: true);
  }

  @override
  Future<void> removeByParent(String table, String parent) async {
    for (final e in _t(table).entries.where((e) => e.value.parent == parent && !e.value.deleted).toList()) {
      await remove(table, e.key);
    }
  }

  @override
  Future<List<PendingRow>> pending(String table) async => [
        for (final e in _t(table).entries.where((e) => e.value.pending))
          PendingRow(id: e.key, parent: e.value.parent, data: Map.of(e.value.data), deleted: e.value.deleted),
      ];

  @override
  Future<void> markSynced(String table, String id) async {
    final r = _t(table)[id];
    if (r != null) _t(table)[id] = (parent: r.parent, data: r.data, pending: false, deleted: r.deleted);
  }
}
