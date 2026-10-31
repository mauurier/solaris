/// Fila que cambió en el teléfono y falta subir al servidor.
class PendingRow {
  const PendingRow({
    required this.id,
    required this.data,
    required this.deleted,
    required this.editedAt,
    this.parent,
    this.base,
  });
  final String id;
  final String? parent;
  final Map<String, Object?> data;

  /// Se borró en el teléfono: en el servidor se marca `eliminado_en`.
  final bool deleted;

  /// Cuándo cambió en el teléfono (hora local, ISO). También dice si volvió a
  /// cambiar mientras se subía (ver [Persistence.markSynced]).
  final String editedAt;

  /// La fila como estaba la última vez que coincidió con el servidor; nula si
  /// nunca ha estado arriba. Comparando contra ella se sabe qué cambió el
  /// teléfono y qué cambió el servidor.
  final Map<String, Object?>? base;
}

DateTime _lastEdit = DateTime(0);

/// Hora local de una escritura, siempre creciente: dos cambios seguidos nunca
/// comparten hora y [Persistence.markSynced] puede distinguirlos.
String editStamp() {
  var now = DateTime.now();
  if (!now.isAfter(_lastEdit)) now = _lastEdit.add(const Duration(microseconds: 1));
  _lastEdit = now;
  return now.toIso8601String();
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

  /// [pending] en falso es para lo que llega del servidor: ya está arriba y
  /// queda como la base de la fila.
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true});
  Future<void> remove(String table, String id);
  Future<void> removeByParent(String table, String parent);

  /// Filas cambiadas o borradas que falta subir.
  Future<List<PendingRow>> pending(String table);

  /// La fila ya se subió y [base] es como quedó en el servidor. Si cambió
  /// otra vez después de [editedAt] (mientras se subía) sigue pendiente. Una
  /// fila borrada se quita.
  Future<void> markSynced(String table, String id, {required String editedAt, Map<String, Object?>? base});

  /// Quita la fila sin dejarla pendiente: se borró en el servidor o el
  /// usuario ya no tiene permiso de verla.
  Future<void> forget(String table, String id);
  Future<void> forgetByParent(String table, String parent);
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

typedef _MemoryRow = ({
  String? parent,
  Map<String, Object?> data,
  bool pending,
  bool deleted,
  String editedAt,
  Map<String, Object?>? base,
});

class MemoryPersistence implements Persistence {
  final _tables = <String, Map<String, _MemoryRow>>{};

  Map<String, _MemoryRow> _t(String table) => _tables.putIfAbsent(table, () => {});

  @override
  Future<List<Map<String, Object?>>> load(String table) async =>
      _t(table).values.where((r) => !r.deleted).map((r) => Map<String, Object?>.of(r.data)).toList();

  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true}) async {
    _t(table)[id] = (
      parent: parent,
      data: Map.of(data),
      pending: pending,
      deleted: false,
      editedAt: editStamp(),
      base: pending ? _t(table)[id]?.base : Map.of(data),
    );
  }

  @override
  Future<void> remove(String table, String id) async {
    final r = _t(table)[id];
    if (r != null) {
      _t(table)[id] = (parent: r.parent, data: r.data, pending: true, deleted: true, editedAt: editStamp(), base: r.base);
    }
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
          PendingRow(
            id: e.key,
            parent: e.value.parent,
            data: Map.of(e.value.data),
            deleted: e.value.deleted,
            editedAt: e.value.editedAt,
            base: e.value.base,
          ),
      ];

  @override
  Future<void> markSynced(String table, String id, {required String editedAt, Map<String, Object?>? base}) async {
    final r = _t(table)[id];
    if (r == null) return;
    final done = r.editedAt == editedAt;
    if (done && r.deleted) {
      _t(table).remove(id);
      return;
    }
    _t(table)[id] = (
      parent: r.parent,
      data: r.data,
      pending: r.pending && !done,
      deleted: r.deleted,
      editedAt: r.editedAt,
      base: base == null ? null : Map.of(base),
    );
  }

  @override
  Future<void> forget(String table, String id) async => _t(table).remove(id);

  @override
  Future<void> forgetByParent(String table, String parent) async =>
      _t(table).removeWhere((_, r) => r.parent == parent);
}
