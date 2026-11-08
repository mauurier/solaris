import 'dart:io';

import 'package:proyecto_app/data/sync/remote_rows.dart';
import 'package:proyecto_app/data/sync/sync_service.dart';

/// Servidor en memoria: tablas con filas en el formato de Supabase.
class FakeRemote implements RemoteSource {
  final tables = <String, List<RemoteRow>>{};

  /// Ids que RLS deja ver al usuario, por tabla. Sin entrada: todos.
  final visible = <String, Set<String>>{};

  /// `since` con el que se pidió cada tabla la última vez.
  final asked = <String, DateTime?>{};

  List<RemoteRow> rows(String table) => tables.putIfAbsent(table, () => []);

  bool _sees(RemoteTable t, RemoteRow r) {
    final ids = visible[t.name];
    if (ids == null) return true;
    final id = t == RemoteTable.projectTechnicians ? r['id_proyecto'] : r['id'];
    return ids.contains(id);
  }

  @override
  Future<List<RemoteRow>> changed(RemoteTable t, DateTime? since) async {
    asked[t.name] = since;
    return rows(t.name)
        .where((r) => _sees(t, r))
        .where((r) => since == null || !DateTime.parse(r[t.timestamp] as String).isBefore(since))
        .map(Map.of)
        .toList();
  }

  @override
  Future<List<RemoteRow>> where(RemoteTable t, String column, Iterable<String> ids) async =>
      rows(t.name).where((r) => _sees(t, r) && ids.contains(r[column])).map(Map.of).toList();

  @override
  Future<Set<String>> visibleIds(RemoteTable t) async =>
      {for (final r in rows(t.name).where((r) => _sees(t, r) && !RemoteRows.deleted(r))) r['id'] as String};

  /// Escrituras en orden: `tabla:insert`, `tabla:update`, `tabla:upsert`.
  final writes = <String>[];

  /// Tablas donde RLS no deja cambiar filas.
  final readOnly = <String>{};

  /// Storage: `bucket/ruta` → contenido.
  final files = <String, List<int>>{};

  @override
  Future<void> upload(String bucket, String path, File file, {required String contentType}) async {
    _log(bucket, 'upload');
    files['$bucket/$path'] = file.readAsBytesSync();
  }

  @override
  Future<List<int>> download(String bucket, String path) async =>
      files['$bucket/$path'] ?? (throw const RemoteRejected('Object not found'));

  @override
  Future<void> removeFile(String bucket, String path) async {
    _log(bucket, 'remove');
    files.remove('$bucket/$path');
  }

  /// Columnas de cada `update`, por tabla.
  final updated = <String, List<Set<String>>>{};

  /// Se llama en cada escritura, antes de aplicarla.
  void Function(String table, String op)? onWrite;

  var _ids = 0;
  static String now() => DateTime.now().toUtc().toIso8601String();

  void _log(String table, String op) {
    writes.add('$table:$op');
    onWrite?.call(table, op);
  }

  bool _matches(RemoteRow r, Map<String, Object?> match) => match.entries.every((m) => r[m.key] == m.value);

  @override
  Future<void> insert(RemoteTable t, RemoteRow row) async {
    _log(t.name, 'insert');
    rows(t.name).add({'creado_en': now(), 'eliminado_en': null, ...row, 'actualizado_en': now()});
  }

  @override
  Future<void> update(RemoteTable t, Map<String, Object> match, RemoteRow values) async {
    _log(t.name, 'update');
    updated.putIfAbsent(t.name, () => []).add(values.keys.toSet());
    final hits = rows(t.name).where((r) => _matches(r, match)).toList();
    if (hits.isEmpty || readOnly.contains(t.name)) {
      throw const RemoteRejected('No tienes permiso para cambiar este registro.');
    }
    for (final r in hits) {
      r
        ..addAll(values)
        ..['actualizado_en'] = now();
    }
  }

  @override
  Future<void> upsert(RemoteTable t, List<RemoteRow> list, {required String onConflict}) async {
    _log(t.name, 'upsert');
    final cols = onConflict.split(',');
    for (final row in list) {
      final hit = rows(t.name).where((r) => _matches(r, {for (final c in cols) c: row[c]})).firstOrNull;
      if (hit != null) {
        hit
          ..addAll(row)
          ..['actualizado_en'] = now();
      } else {
        rows(t.name).add({'id': 'r${++_ids}', 'creado_en': now(), ...row, 'actualizado_en': now()});
      }
    }
  }
}
