/// Almacén de registros usado por `SurveyStore`.
///
/// Cada tabla guarda filas `id → datos JSON`, con un `parent` opcional
/// (proyecto o visita) para borrar en cascada. La implementación real es
/// SQLite ([SqlitePersistence]); las pruebas usan [MemoryPersistence].
abstract class Persistence {
  Future<List<Map<String, Object?>>> load(String table);
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent});
  Future<void> remove(String table, String id);
  Future<void> removeByParent(String table, String parent);
}

/// Tablas del esquema. Mantener en sincronía con [SqlitePersistence].
class Tables {
  Tables._();
  static const templates = 'templates';
  static const projects = 'projects';
  static const documents = 'documents';
  static const visits = 'visits';
  static const answers = 'answers';
  static const evidences = 'evidences';

  static const all = [templates, projects, documents, visits, answers, evidences];
}

class MemoryPersistence implements Persistence {
  final _tables = <String, Map<String, ({String? parent, Map<String, Object?> data})>>{};

  Map<String, ({String? parent, Map<String, Object?> data})> _t(String table) =>
      _tables.putIfAbsent(table, () => {});

  @override
  Future<List<Map<String, Object?>>> load(String table) async =>
      _t(table).values.map((r) => Map<String, Object?>.of(r.data)).toList();

  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent}) async {
    _t(table)[id] = (parent: parent, data: Map.of(data));
  }

  @override
  Future<void> remove(String table, String id) async => _t(table).remove(id);

  @override
  Future<void> removeByParent(String table, String parent) async =>
      _t(table).removeWhere((_, r) => r.parent == parent);
}
