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
  /// 5: la plantilla inicial ya no viene en la app. Se borra la copia local,
  ///    que quedaba pendiente de subir, para que baje la del servidor.
  /// 6: columna `base`: la fila como estaba la última vez que coincidió con
  ///    el servidor. La subida compara contra ella.
  static const _version = 6;
  static const _builtInTemplate = '015c2871-6002-4d95-94ca-8e95d12e8b35';

  static Future<void> _createTable(DatabaseExecutor db, String t) async {
    await db.execute('CREATE TABLE IF NOT EXISTS $t ('
        'id TEXT PRIMARY KEY, '
        'parent TEXT, '
        'data TEXT NOT NULL, '
        'updated_at TEXT NOT NULL, '
        'pending INTEGER NOT NULL DEFAULT 1, '
        'deleted INTEGER NOT NULL DEFAULT 0, '
        'base TEXT)');
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
          } else {
            if (from == 4) {
              await db.delete(Tables.templates, where: 'id = ?', whereArgs: [_builtInTemplate]);
            }
            if (from < 6) {
              final existing = {
                for (final r in await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'")) r['name'],
              };
              for (final t in Tables.all.where(existing.contains)) {
                await db.execute('ALTER TABLE $t ADD COLUMN base TEXT');
              }
            }
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

  /// Un cambio local conserva la `base` que ya tenía la fila. Sin
  /// `ON CONFLICT DO UPDATE`: Android 9 y 10 traen SQLite 3.22.
  @override
  Future<void> put(String table, String id, Map<String, Object?> data, {String? parent, bool pending = true}) async {
    final json = jsonEncode(data);
    final values = {
      'parent': parent,
      'data': json,
      'updated_at': editStamp(),
      'pending': pending ? 1 : 0,
      'deleted': 0,
      if (!pending) 'base': json,
    };
    await _db.transaction((txn) async {
      final n = await txn.update(table, values, where: 'id = ?', whereArgs: [id]);
      if (n == 0) await txn.insert(table, {'id': id, ...values});
    });
  }

  @override
  Future<void> remove(String table, String id) => _db.update(
        table,
        {'deleted': 1, 'pending': 1, 'updated_at': editStamp()},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<void> removeByParent(String table, String parent) => _db.update(
        table,
        {'deleted': 1, 'pending': 1, 'updated_at': editStamp()},
        where: 'parent = ? AND deleted = 0',
        whereArgs: [parent],
      );

  @override
  Future<List<PendingRow>> pending(String table) async {
    final rows = await _db.query(table,
        columns: ['id', 'parent', 'data', 'deleted', 'updated_at', 'base'], where: 'pending = 1');
    Map<String, Object?> decode(Object? v) => (jsonDecode(v as String) as Map).cast<String, Object?>();
    return [
      for (final r in rows)
        PendingRow(
          id: r['id'] as String,
          parent: r['parent'] as String?,
          data: decode(r['data']),
          deleted: r['deleted'] == 1,
          editedAt: r['updated_at'] as String,
          base: r['base'] == null ? null : decode(r['base']),
        ),
    ];
  }

  @override
  Future<void> markSynced(String table, String id, {required String editedAt, Map<String, Object?>? base}) =>
      _db.transaction((txn) async {
        await txn.update(table, {'base': base == null ? null : jsonEncode(base)}, where: 'id = ?', whereArgs: [id]);
        await txn.update(table, {'pending': 0}, where: 'id = ? AND updated_at = ?', whereArgs: [id, editedAt]);
        await txn.delete(table, where: 'id = ? AND pending = 0 AND deleted = 1', whereArgs: [id]);
      });

  @override
  Future<void> forget(String table, String id) => _db.delete(table, where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> forgetByParent(String table, String parent) =>
      _db.delete(table, where: 'parent = ?', whereArgs: [parent]);

  Future<void> close() => _db.close();
}
