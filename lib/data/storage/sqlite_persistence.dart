import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'persistence.dart';

/// Persistencia en SQLite. Todo se escribe en el momento, así que cerrar la
/// app o apagar el teléfono no pierde lo capturado.
class SqlitePersistence implements Persistence {
  SqlitePersistence._(this._db);
  final Database _db;

  static const _version = 1;

  /// Abre (o crea) la base en [path]. En las pruebas se pasa una
  /// `DatabaseFactory` de sqflite_common_ffi.
  static Future<SqlitePersistence> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        // PRAGMA devuelve una fila: con execute() Android lo rechaza.
        onConfigure: (db) => db.rawQuery('PRAGMA journal_mode = WAL'),
        onCreate: (db, _) async {
          for (final t in Tables.all) {
            await db.execute('CREATE TABLE $t ('
                'id TEXT PRIMARY KEY, '
                'parent TEXT, '
                'data TEXT NOT NULL, '
                'updated_at TEXT NOT NULL)');
            await db.execute('CREATE INDEX idx_${t}_parent ON $t(parent)');
          }
        },
      ),
    );
    return SqlitePersistence._(db);
  }

  @override
  Future<List<Map<String, Object?>>> load(String table) async {
    final rows = await _db.query(table, columns: ['data']);
    return rows.map((r) => (jsonDecode(r['data'] as String) as Map).cast<String, Object?>()).toList();
  }

  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent}) async {
    await _db.insert(
      table,
      {
        'id': id,
        'parent': parent,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String table, String id) => _db.delete(table, where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> removeByParent(String table, String parent) =>
      _db.delete(table, where: 'parent = ?', whereArgs: [parent]);

  Future<void> close() => _db.close();
}
