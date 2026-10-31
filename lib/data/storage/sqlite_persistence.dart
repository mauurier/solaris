import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'persistence.dart';

/// Persistencia en SQLite. Todo se escribe en el momento, así que cerrar la
/// app o apagar el teléfono no pierde lo capturado.
class SqlitePersistence implements Persistence {
  SqlitePersistence._(this._db, {required this.wiped});
  final Database _db;

  /// La base se vació al abrirla porque venía de una versión sin ids del
  /// servidor; los archivos de esos datos también hay que borrarlos.
  final bool wiped;

  /// 2: tabla `project_types` (tipos de proyecto editables por el admin).
  /// 3: tabla `visit_motives` (motivos de visita editables por el admin).
  /// 4: ids del servidor, clientes y sitios, columnas `pending` y `deleted`.
  ///    Los datos de antes eran de prueba y se borran.
  static const _version = 4;

  static Future<void> _createTable(DatabaseExecutor db, String t) async {
    await db.execute('CREATE TABLE IF NOT EXISTS $t ('
        'id TEXT PRIMARY KEY, '
        'parent TEXT, '
        'data TEXT NOT NULL, '
        'updated_at TEXT NOT NULL, '
        'pending INTEGER NOT NULL DEFAULT 1, '
        'deleted INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${t}_parent ON $t(parent)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_${t}_pending ON $t(pending)');
  }

  /// Abre (o crea) la base en [path]. En las pruebas se pasa una
  /// `DatabaseFactory` de sqflite_common_ffi.
  static Future<SqlitePersistence> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    var wiped = false;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        // PRAGMA devuelve una fila: con execute() Android lo rechaza.
        onConfigure: (db) => db.rawQuery('PRAGMA journal_mode = WAL'),
        onCreate: (db, _) async {
          for (final t in Tables.all) {
            await _createTable(db, t);
          }
        },
        onUpgrade: (db, from, _) async {
          if (from < 4) {
            final old = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
            for (final r in old) {
              await db.execute('DROP TABLE IF EXISTS ${r['name']}');
            }
            wiped = true;
          }
          for (final t in Tables.all) {
            await _createTable(db, t);
          }
        },
      ),
    );
    return SqlitePersistence._(db, wiped: wiped);
  }

  @override
  Future<List<Map<String, Object?>>> load(String table) async {
    final rows = await _db.query(table, columns: ['data'], where: 'deleted = 0');
    return rows.map((r) => (jsonDecode(r['data'] as String) as Map).cast<String, Object?>()).toList();
  }

  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true}) async {
    await _db.insert(
      table,
      {
        'id': id,
        'parent': parent,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
        'pending': pending ? 1 : 0,
        'deleted': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String table, String id) => _db.update(
        table,
        {'deleted': 1, 'pending': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<void> removeByParent(String table, String parent) => _db.update(
        table,
        {'deleted': 1, 'pending': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'parent = ? AND deleted = 0',
        whereArgs: [parent],
      );

  @override
  Future<List<PendingRow>> pending(String table) async {
    final rows = await _db.query(table, columns: ['id', 'parent', 'data', 'deleted'], where: 'pending = 1');
    return [
      for (final r in rows)
        PendingRow(
          id: r['id'] as String,
          parent: r['parent'] as String?,
          data: (jsonDecode(r['data'] as String) as Map).cast<String, Object?>(),
          deleted: r['deleted'] == 1,
        ),
    ];
  }

  @override
  Future<void> markSynced(String table, String id) =>
      _db.update(table, {'pending': 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> close() => _db.close();
}
