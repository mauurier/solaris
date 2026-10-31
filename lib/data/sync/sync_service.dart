import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock_data.dart';
import '../remote_errors.dart';
import '../storage/persistence.dart';
import '../survey_store.dart';
import 'push.dart';
import 'remote_rows.dart';

typedef RemoteRow = Map<String, Object?>;

/// El servidor no aceptó una escritura (permisos, dato repetido…). La fila
/// sigue pendiente; los errores de red, en cambio, cortan la sincronización.
class RemoteRejected implements Exception {
  const RemoteRejected(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lo que la sincronización necesita del servidor. Las pruebas usan uno falso.
abstract class RemoteSource {
  /// Filas de [t] cambiadas desde [since] (todas si es nulo), borradas incluidas.
  Future<List<RemoteRow>> changed(RemoteTable t, DateTime? since);

  /// Filas de [t] cuyo [column] es uno de [ids].
  Future<List<RemoteRow>> where(RemoteTable t, String column, Iterable<String> ids);

  /// Ids sin borrar de [t] que el usuario puede ver ahora.
  Future<Set<String>> visibleIds(RemoteTable t);

  Future<void> insert(RemoteTable t, RemoteRow row);

  /// Cambia [values] en la fila que cumple [match]. Si RLS no la deja tocar
  /// (no cambia ninguna fila) también lanza [RemoteRejected].
  Future<void> update(RemoteTable t, Map<String, Object> match, RemoteRow values);

  /// Inserta o actualiza según [onConflict], columnas de una restricción única.
  Future<void> upsert(RemoteTable t, List<RemoteRow> rows, {required String onConflict});

  /// Sube [file] a `bucket/path`, reemplazando el que hubiera.
  Future<void> upload(String bucket, String path, File file, {required String contentType});

  /// Contenido de `bucket/path`. Si no existe lanza [RemoteRejected].
  Future<List<int>> download(String bucket, String path);

  Future<void> removeFile(String bucket, String path);
}

class SupabaseRemote implements RemoteSource {
  static const _page = 500;
  static const _chunk = 100;
  static const _timeout = Duration(seconds: 20);

  SupabaseClient get _c => Supabase.instance.client;

  /// Pide página por página hasta que una venga incompleta.
  Future<List<RemoteRow>> _paged(PostgrestTransformBuilder<List<RemoteRow>> Function(int from, int to) page) async {
    final out = <RemoteRow>[];
    for (var from = 0;; from += _page) {
      final rows = await page(from, from + _page - 1).timeout(_timeout);
      out.addAll(rows);
      if (rows.length < _page) return out;
    }
  }

  @override
  Future<List<RemoteRow>> changed(RemoteTable t, DateTime? since) => _paged((from, to) {
        var q = _c.from(t.name).select(t.columns);
        if (since != null) q = q.gte(t.timestamp, since.toUtc().toIso8601String());
        return q.order(t.timestamp, ascending: true).order(t.key, ascending: true).range(from, to);
      });

  @override
  Future<List<RemoteRow>> where(RemoteTable t, String column, Iterable<String> ids) async {
    final all = ids.toList();
    final out = <RemoteRow>[];
    for (var i = 0; i < all.length; i += _chunk) {
      final chunk = all.sublist(i, (i + _chunk).clamp(0, all.length));
      out.addAll(await _paged((from, to) => _c
          .from(t.name)
          .select(t.columns)
          .inFilter(column, chunk)
          .order(t.key, ascending: true)
          .range(from, to)));
    }
    return out;
  }

  @override
  Future<Set<String>> visibleIds(RemoteTable t) async {
    final rows = await _paged((from, to) =>
        _c.from(t.name).select('id').isFilter('eliminado_en', null).order('id', ascending: true).range(from, to));
    return {for (final r in rows) r['id'] as String};
  }

  /// Un archivo de 50 MB tarda en subir por datos móviles.
  static const _fileTimeout = Duration(minutes: 5);

  Future<T> _write<T>(Future<T> request, {Duration timeout = _timeout}) async {
    try {
      return await request.timeout(timeout);
    } on PostgrestException catch (e) {
      throw RemoteRejected(remoteErrorMessage(e));
    } on StorageException catch (e) {
      throw RemoteRejected(e.statusCode == '413' ? 'El archivo pesa más de 50 MB.' : e.message);
    }
  }

  @override
  Future<void> insert(RemoteTable t, RemoteRow row) => _write(_c.from(t.name).insert(row));

  @override
  Future<void> update(RemoteTable t, Map<String, Object> match, RemoteRow values) async {
    final rows = await _write(_c.from(t.name).update(values).match(match).select(t.key));
    if (rows.isEmpty) throw const RemoteRejected('No tienes permiso para cambiar este registro.');
  }

  @override
  Future<void> upsert(RemoteTable t, List<RemoteRow> rows, {required String onConflict}) async {
    for (var i = 0; i < rows.length; i += _page) {
      await _write(_c.from(t.name).upsert(rows.sublist(i, (i + _page).clamp(0, rows.length)), onConflict: onConflict));
    }
  }

  @override
  Future<void> upload(String bucket, String path, File file, {required String contentType}) => _write(
      _c.storage.from(bucket).upload(path, file, fileOptions: FileOptions(contentType: contentType, upsert: true)),
      timeout: _fileTimeout);

  @override
  Future<List<int>> download(String bucket, String path) =>
      _write(_c.storage.from(bucket).download(path), timeout: _fileTimeout);

  @override
  Future<void> removeFile(String bucket, String path) => _write(_c.storage.from(bucket).remove([path]));
}

/// Sube lo que cambió en el teléfono ([SyncPush]) y luego baja lo que cambió
/// en el servidor desde la última vez. La bajada no toca lo que el teléfono
/// cambió y aún no sube.
///
/// Por cada tabla guarda hasta qué `actualizado_en` ya bajó. Proyectos y
/// visitas además se comparan contra los que el usuario puede ver ahora:
/// así llegan los que le acaban de asignar (aunque no hayan cambiado) y se
/// van los que le quitaron.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final instance = SyncService._();

  /// Se cambia en las pruebas.
  RemoteSource remote = SupabaseRemote();

  /// Margen hacia atrás al pedir cambios: una escritura que tardó en
  /// confirmarse puede llevar una hora anterior a la última bajada.
  static const overlap = Duration(minutes: 2);
  static const _ownerKey = 'sync.usuario';
  static const _cursorPrefix = 'sync.desde.';

  bool running = false;
  String? error;
  DateTime? lastPull;
  Future<void>? _current;

  /// Documentos y evidencias que esperan Wi-Fi para subir (ver
  /// `AppState.syncOnWifiOnly`).
  int waitingForWifi = 0;

  /// Si ahora se pueden subir y bajar archivos. Se cambia en las pruebas.
  Future<bool> Function() filesAllowed = _filesAllowed;

  /// "Sólo con Wi-Fi" aplica a los archivos; los datos, que pesan poco, se
  /// sincronizan con cualquier conexión.
  static Future<bool> _filesAllowed() async {
    if (!AppState.instance.syncOnWifiOnly) return true;
    final network = await Connectivity().checkConnectivity();
    return network.contains(ConnectivityResult.wifi) || network.contains(ConnectivityResult.ethernet);
  }

  /// Sube y baja. Si ya hay una sincronización en curso, espera esa misma.
  Future<void> sync() => _current ??= _run(push: true).whenComplete(() => _current = null);

  /// Sólo baja.
  Future<void> pull() => _current ??= _run(push: false).whenComplete(() => _current = null);

  /// Al cerrar sesión: la siguiente cuenta empieza desde cero.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_cursorPrefix) || k == _ownerKey).toList()) {
      await prefs.remove(k);
    }
    error = null;
    lastPull = null;
  }

  Future<void> _run({required bool push}) async {
    // Modo demo: no hay sesión ni servidor.
    if (AppState.instance.profile == null || !SurveyStore.isReady) return;
    running = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_ownerKey) != AppState.instance.userId) {
        await reset();
        await prefs.setString(_ownerKey, AppState.instance.userId);
      }
      final store = SurveyStore.instance;
      final files = await filesAllowed();
      final up = SyncPush(store, remote, allowFiles: files);
      if (push) await up.run();
      await _pull(prefs, store, up.refetch);
      if (files) await _download(store);
      waitingForWifi = up.waitingForWifi;
      lastPull = DateTime.now();
      if (up.failures.isNotEmpty) {
        final n = up.failures.length;
        error = '${n == 1 ? 'Un cambio no se pudo subir' : '$n cambios no se pudieron subir'}: ${up.failures.first}';
      }
    } catch (e) {
      error = remoteErrorMessage(e);
    } finally {
      running = false;
      notifyListeners();
    }
  }

  /// [refetch]: ids que la subida no escribió y hay que pedir aunque el
  /// cursor ya los haya pasado (ver [SyncPush.refetch]).
  Future<void> _pull(SharedPreferences prefs, SurveyStore store, Map<String, Set<String>> refetch) async {
    Future<List<RemoteRow>> changed(RemoteTable t) {
      final last = DateTime.tryParse(prefs.getString('$_cursorPrefix${t.name}') ?? '');
      return remote.changed(t, last?.subtract(overlap));
    }

    /// Los de [refetch] que no vinieron en [rows].
    Set<String> again(RemoteTable t, Iterable<RemoteRow> rows, [String column = 'id']) =>
        (refetch[t.name] ?? const {}).difference({for (final r in rows) r[column]});

    Future<void> advance(RemoteTable t, List<RemoteRow> rows) async {
      final stamps = rows.map((r) => DateTime.tryParse('${r[t.timestamp]}')).nonNulls;
      if (stamps.isEmpty) return;
      final latest = stamps.reduce((a, b) => a.isAfter(b) ? a : b);
      await prefs.setString('$_cursorPrefix${t.name}', latest.toUtc().toIso8601String());
    }

    Iterable<String> deletedIds(List<RemoteRow> rows) => rows.where(RemoteRows.deleted).map((r) => r['id'] as String);
    Iterable<RemoteRow> alive(List<RemoteRow> rows) => rows.where((r) => !RemoteRows.deleted(r));

    // ----- 1. Catálogos, plantillas, clientes y sitios: todos los ven.
    for (final (t, toLocal) in [
      (RemoteTable.projectTypes, RemoteRows.catalogItem),
      (RemoteTable.visitMotives, RemoteRows.catalogItem),
      (RemoteTable.templates, RemoteRows.template),
      (RemoteTable.clients, RemoteRows.client),
      (RemoteTable.sites, RemoteRows.site),
    ]) {
      final rows = await changed(t);
      final missed = again(t, rows);
      final all = [...rows, if (missed.isNotEmpty) ...await remote.where(t, 'id', missed)];
      await store.mergeRemote(t.local, rows: alive(all).map(toLocal).toList(), removed: deletedIds(all));
      await advance(t, rows);
    }

    // ----- 2. Proyectos y sus técnicos.
    const pt = RemoteTable.projects;
    final changedProjects = await changed(pt);
    final visibleProjects = await remote.visibleIds(pt);
    final localProjects = {for (final p in store.projects) p.id};
    final changedIds = {for (final r in changedProjects) r['id'] as String};
    final appeared = visibleProjects.difference(localProjects).difference(changedIds);
    final missedProjects = again(pt, changedProjects);
    final projectRows = [
      ...changedProjects,
      if (appeared.isNotEmpty || missedProjects.isNotEmpty)
        ...await remote.where(pt, 'id', {...appeared, ...missedProjects}),
    ];
    // Nuevos o pedidos otra vez: sus técnicos se toman completos del servidor.
    final newProjects = {
      ...{for (final r in alive(projectRows)) r['id'] as String}.difference(localProjects),
      ...missedProjects,
    };

    const tt = RemoteTable.projectTechnicians;
    final changedTechs = await changed(tt);
    final techRows = [
      ...changedTechs,
      if (newProjects.isNotEmpty) ...await remote.where(tt, 'id_proyecto', newProjects),
    ]..sort((a, b) => '${a['creado_en']}'.compareTo('${b['creado_en']}'));

    // Técnicos de cada proyecto: los que ya tenía el teléfono más los cambios.
    final techs = <String, List<String>>{
      for (final p in store.projects) p.id: [...p.technicianIds],
      for (final id in newProjects) id: <String>[],
    };
    final touched = <String>{};
    for (final r in techRows) {
      final list = techs[r['id_proyecto']];
      if (list == null) continue;
      final tech = r['id_tecnico'] as String;
      list.remove(tech);
      if (!RemoteRows.deleted(r)) list.add(tech);
      touched.add(r['id_proyecto'] as String);
    }

    final fromServer = {for (final r in alive(projectRows)) r['id'] as String};
    await store.mergeRemote(
      Tables.projects,
      rows: [
        for (final r in alive(projectRows)) RemoteRows.project(r, techs[r['id']] ?? const []),
        // Sólo cambió la lista de técnicos.
        for (final id in touched.difference(fromServer))
          if (store.project(id) case final p?) {...p.toJson(), 'technicianIds': techs[id]},
      ],
      removed: {...deletedIds(projectRows), ...localProjects.difference(visibleProjects)},
    );
    await advance(pt, changedProjects);
    await advance(tt, changedTechs);

    // ----- 3. Visitas.
    const vt = RemoteTable.visits;
    final changedVisits = await changed(vt);
    final visibleVisits = await remote.visibleIds(vt);
    final localVisits = {for (final v in store.visits) v.id};
    final changedVisitIds = {for (final r in changedVisits) r['id'] as String};
    final appearedVisits = {
      ...visibleVisits.difference(localVisits).difference(changedVisitIds),
      ...again(vt, changedVisits),
    };
    final visitRows = [
      ...changedVisits,
      if (appearedVisits.isNotEmpty) ...await remote.where(vt, 'id', appearedVisits),
    ];
    await store.mergeRemote(
      Tables.visits,
      rows: alive(visitRows).map(RemoteRows.visit).toList(),
      removed: {...deletedIds(visitRows), ...localVisits.difference(visibleVisits)},
    );
    await advance(vt, changedVisits);

    // ----- 4. Respuestas: las que cambiaron y todas las de visitas nuevas.
    const at = RemoteTable.answers;
    final newVisits = {
      ...{for (final r in alive(visitRows)) r['id'] as String}.difference(localVisits),
      ...?refetch[at.name],
    };
    final changedAnswers = await changed(at);
    final answerRows = [
      ...changedAnswers,
      if (newVisits.isNotEmpty) ...await remote.where(at, 'id_visita', newVisits),
    ].where((r) => store.visit(r['id_visita'] as String) != null).toList();
    await store.mergeRemote(
      Tables.answers,
      rows: alive(answerRows).map(RemoteRows.answer).toList(),
      removed: answerRows.where(RemoteRows.deleted).map(RemoteRows.answerRowId),
    );
    await advance(at, changedAnswers);

    // ----- 5. Documentos y evidencias: las filas; los archivos se bajan aparte.
    for (final (t, parentColumn, parents, exists, toLocal) in [
      (RemoteTable.documents, 'id_proyecto', newProjects, (String id) => store.project(id) != null, RemoteRows.document),
      (RemoteTable.evidences, 'id_visita', newVisits, (String id) => store.visit(id) != null, RemoteRows.evidence),
    ]) {
      final rows = await changed(t);
      final missed = again(t, rows);
      final all = [
        ...rows,
        if (parents.isNotEmpty) ...await remote.where(t, parentColumn, parents),
        if (missed.isNotEmpty) ...await remote.where(t, 'id', missed),
      ].where((r) => exists(r[parentColumn] as String)).toList();
      await store.mergeRemote(t.local, rows: alive(all).map(toLocal).toList(), removed: deletedIds(all));
      await advance(t, rows);
    }
  }

  /// Baja los archivos de documentos y evidencias que el teléfono no tiene.
  /// Uno que no está en Storage (p. ej. se rechazó) se salta.
  Future<void> _download(SurveyStore store) async {
    var got = 0;
    for (final (table, j) in store.missingFiles) {
      final t = table == Tables.documents ? RemoteTable.documents : RemoteTable.evidences;
      final path = j['path'] as String;
      try {
        final bytes = await remote.download(t.bucket!, RemoteRows.remotePath(table, j));
        await store.files.writeBytes(bytes, p.dirname(path), p.basename(path));
        got++;
      } on RemoteRejected {
        continue;
      }
    }
    if (got > 0) store.filesArrived();
  }
}
