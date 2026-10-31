import '../storage/persistence.dart';
import '../survey_store.dart';
import 'remote_rows.dart';
import 'sync_service.dart';

/// Qué pasó con una fila pendiente.
enum _Result {
  /// Se escribió en el servidor; la bajada la trae de vuelta por su
  /// `actualizado_en`.
  written,

  /// No había nada que escribir y el teléfono ya coincide con el servidor.
  synced,

  /// No se escribió y el servidor tiene algo que el teléfono no (ganó el
  /// servidor, o cambió mientras la fila estaba pendiente): hay que bajarla.
  stale,
}

/// Sube lo que cambió en el teléfono, en el orden de las llaves foráneas:
/// catálogos y plantillas, cliente, sitio, proyecto con sus técnicos, visita,
/// respuestas, documentos y evidencias. De estos dos últimos primero sube el
/// archivo a Storage y después la fila con `subido_en`: una fila en el
/// servidor siempre tiene su archivo. Al final, las visitas terminadas que ya
/// subieron todo pasan a revisión.
///
/// Cada columna se compara en tres versiones: la del teléfono, su base (como
/// estaba la última vez que coincidió con el servidor) y la del servidor.
/// Sólo se sube lo que cambió el teléfono, así no se pisa lo que otra persona
/// cambió en otras columnas. Si los dos cambiaron la misma, gana el cambio
/// más reciente.
class SyncPush {
  SyncPush(this.store, this.remote, {this.allowFiles = true});

  final SurveyStore store;
  final RemoteSource remote;

  /// Falso con "Sólo con Wi-Fi" y sin Wi-Fi: lo que lleva archivo espera.
  final bool allowFiles;

  /// Documentos y evidencias que esperan Wi-Fi para subir su archivo.
  var waitingForWifi = 0;

  /// Ids que la bajada debe volver a pedir, por tabla del servidor: mientras
  /// estaban pendientes se saltó sus cambios. En `respuesta` son ids de visita.
  final refetch = <String, Set<String>>{};

  /// Lo que el servidor rechazó. Esas filas siguen pendientes.
  final failures = <String>[];

  /// Ids que no existen en el servidor (modo demo, o se rechazó su alta):
  /// lo que cuelga de ellos tampoco se sube.
  final _missing = <String>{};

  /// Ids de `perfil` del modo demo (`AppState.setRole`); no existen arriba.
  static const _demoPrefix = 'demo-';

  static const _answerKey = 'id_visita,clave_grupo,numero_repeticion,clave_pregunta';

  Future<void> run() async {
    // Visitas con algo que subir; si terminan subiendo todo, van a revisión.
    final touched = {
      for (final r in await store.db.pending(Tables.visits)) r.id,
      for (final t in [Tables.answers, Tables.evidences])
        for (final r in await store.db.pending(t)) ?r.parent,
    };
    for (final t in [RemoteTable.projectTypes, RemoteTable.visitMotives, RemoteTable.templates, RemoteTable.clients]) {
      await _table(t);
    }
    await _table(RemoteTable.sites, parent: 'clientId');
    await _table(RemoteTable.projects, parent: 'siteId');
    await _table(RemoteTable.visits, parent: 'projectId');
    await _answers();
    await _table(RemoteTable.documents, parent: 'projectId');
    await _table(RemoteTable.evidences, parent: 'visitId');
    await _sendToReview(touched);
  }

  // ---------------------------------------------------------------- filas

  Future<void> _table(RemoteTable t, {String? parent}) async {
    final rows = await _pending(t.local, (r) => parent == null ? null : r.data[parent] as String?);
    if (rows.isEmpty) return;
    final server = {for (final r in await remote.where(t, 'id', rows.map((r) => r.id))) r['id'] as String: r};
    final results = <(PendingRow, _Result)>[];
    for (final row in rows) {
      if (!allowFiles && _needsUpload(t, row, server[row.id])) {
        waitingForWifi++;
        continue;
      }
      try {
        results.add((row, await _row(t, row, server[row.id])));
      } on RemoteRejected catch (e) {
        failures.add(e.message);
        if (server[row.id] == null) _missing.add(row.id);
      }
    }
    if (t == RemoteTable.projects) await _technicians(results);
    for (final (row, result) in results) {
      await _done(t, row, result, refetchId: row.id);
    }
  }

  Future<_Result> _row(RemoteTable t, PendingRow row, RemoteRow? server) async {
    final local = RemoteRows.toDb(t.local, row.data);
    // Columnas del archivo, si hay que subirlo antes de escribir la fila.
    Future<RemoteRow> file() async => _needsUpload(t, row, server) ? await _upload(t, row, local) : const {};
    if (server == null) {
      // Borrada antes de llegar arriba: no hay nada que hacer.
      if (row.deleted) return _Result.synced;
      await remote.insert(t, {'id': row.id, ...local, ...await file()});
      return _Result.written;
    }
    final serverNewer = _serverNewer(server, row.editedAt);
    final base = row.base == null ? null : RemoteRows.toDb(t.local, row.base!);

    if (RemoteRows.deleted(server)) {
      if (row.deleted) return _Result.synced;
      // Borrada allá y cambiada aquí: si lo de aquí es más reciente, revive.
      if (serverNewer) return _Result.stale;
      await remote.update(t, {'id': row.id}, {..._diff(local, server), ...await file(), 'eliminado_en': null});
      return _Result.written;
    }
    if (row.deleted) {
      // Si alguien la cambió después de que se borró aquí, se queda.
      if (serverNewer && base != null && _diff(base, server).isNotEmpty) return _Result.stale;
      await remote.update(t, {'id': row.id}, {'eliminado_en': _now()});
      return _Result.written;
    }
    final changes = {..._merge(local, base ?? server, server, localWins: !serverNewer), ...await file()};
    if (changes.isEmpty) return _diff(local, server).isEmpty ? _Result.synced : _Result.stale;
    await remote.update(t, {'id': row.id}, changes);
    // Se reemplazó el archivo: el anterior ya no lo usa nadie.
    final old = server['ruta_archivo'];
    if (changes.containsKey('subido_en') && server['subido_en'] != null && old is String && old != local['ruta_archivo']) {
      try {
        await remote.removeFile(t.bucket!, old);
      } on RemoteRejected {
        // Queda huérfano en Storage; no afecta a la app.
      }
    }
    return _Result.written;
  }

  /// La fila lleva archivo y en el servidor no está el actual.
  static bool _needsUpload(RemoteTable t, PendingRow row, RemoteRow? server) =>
      t.bucket != null &&
      !row.deleted &&
      (server == null ||
          server['subido_en'] == null ||
          server['ruta_archivo'] != RemoteRows.remotePath(t.local, row.data));

  Future<RemoteRow> _upload(RemoteTable t, PendingRow row, RemoteRow local) async {
    final f = store.files.file(row.data['path'] as String);
    if (!f.existsSync()) throw RemoteRejected('Falta en el teléfono el archivo ${row.data['originalName']}.');
    await remote.upload(t.bucket!, local['ruta_archivo'] as String, f, contentType: local['mime_type'] as String);
    return {'tamano': f.lengthSync(), 'subido_en': _now()};
  }

  /// Visitas terminadas cuyo todo ya está arriba: pasan a revisión y se suben
  /// otra vez la visita y el proyecto con su estado nuevo.
  Future<void> _sendToReview(Set<String> visitIds) async {
    final waiting = {
      for (final t in [Tables.visits, Tables.answers, Tables.evidences])
        for (final r in await store.db.pending(t)) t == Tables.visits ? r.id : r.parent,
    };
    var moved = false;
    for (final id in visitIds.difference(waiting).difference(_missing)) {
      final v = store.visit(id);
      if (v != null && await store.sendToReview(v)) moved = true;
    }
    if (moved) {
      await _table(RemoteTable.projects, parent: 'siteId');
      await _table(RemoteTable.visits, parent: 'projectId');
    }
  }

  /// Altas y bajas de técnicos (`proyecto_tecnico`) respecto a la base del
  /// proyecto. Si alguna falla, el proyecto sigue pendiente para reintentarla.
  Future<void> _technicians(List<(PendingRow, _Result)> results) async {
    final rows = [
      for (final (row, result) in results)
        if (!row.deleted && result != _Result.stale) row,
    ];
    if (rows.isEmpty) return;
    const t = RemoteTable.projectTechnicians;
    final server = <String, Map<String, RemoteRow>>{};
    for (final r in await remote.where(t, 'id_proyecto', rows.map((r) => r.id))) {
      server.putIfAbsent(r['id_proyecto'] as String, () => {})[r['id_tecnico'] as String] = r;
    }
    Set<String> ids(Map<String, Object?> j) => {...(j['technicianIds'] as List? ?? const []).cast<String>()};

    for (final row in rows) {
      final assigned = server[row.id] ?? const {};
      final local = ids(row.data);
      final base = row.base == null
          ? {for (final e in assigned.entries) if (!RemoteRows.deleted(e.value)) e.key}
          : ids(row.base!);
      Map<String, Object> key(String tech) => {'id_proyecto': row.id, 'id_tecnico': tech};
      try {
        for (final tech in local.difference(base)) {
          final s = assigned[tech];
          if (s == null) {
            await remote.insert(t, key(tech));
          } else if (RemoteRows.deleted(s)) {
            // Lo quitaron allá después de asignarlo aquí: se queda quitado.
            if (_serverNewer(s, row.editedAt)) {
              _refetch(RemoteTable.projects, row.id);
            } else {
              await remote.update(t, key(tech), {'eliminado_en': null});
            }
          }
        }
        for (final tech in base.difference(local)) {
          final s = assigned[tech];
          if (s == null || RemoteRows.deleted(s)) continue;
          if (_serverNewer(s, row.editedAt)) {
            _refetch(RemoteTable.projects, row.id);
          } else {
            await remote.update(t, key(tech), {'eliminado_en': _now()});
          }
        }
      } on RemoteRejected catch (e) {
        failures.add(e.message);
        results.removeWhere((r) => r.$1 == row);
      }
    }
  }

  // ---------------------------------------------------------------- respuestas

  /// Una petición por visita: si el servidor rechaza una (p. ej. la visita ya
  /// se aprobó), las de las demás visitas sí se suben.
  Future<void> _answers() async {
    const t = RemoteTable.answers;
    final rows = await _pending(Tables.answers, (r) => r.parent);
    if (rows.isEmpty) return;
    final server = {
      for (final r in await remote.where(t, 'id_visita', {for (final r in rows) r.parent!})) RemoteRows.answerRowId(r): r,
    };
    final byVisit = <String, List<PendingRow>>{};
    for (final r in rows) {
      byVisit.putIfAbsent(r.parent!, () => []).add(r);
    }
    for (final MapEntry(key: visitId, value: group) in byVisit.entries) {
      final writes = [for (final row in group) (row, _answerWrite(row, server[row.id]))];
      try {
        final upserts = [for (final (_, (write, _)) in writes) ?write];
        if (upserts.isNotEmpty) await remote.upsert(t, upserts, onConflict: _answerKey);
      } on RemoteRejected catch (e) {
        failures.add(e.message);
        continue;
      }
      for (final (row, (_, result)) in writes) {
        await _done(t, row, result, refetchId: visitId);
      }
    }
  }

  /// La fila a escribir en `respuesta` (con su `eliminado_en`), o nula si no
  /// hay que escribir nada; en ese caso, si el teléfono está al día.
  (RemoteRow?, _Result) _answerWrite(PendingRow row, RemoteRow? server) {
    final local = RemoteRows.toDb(Tables.answers, row.data);
    RemoteRow alive() => {...local, 'eliminado_en': null};
    if (server == null) return row.deleted ? (null, _Result.synced) : (alive(), _Result.written);
    final serverNewer = _serverNewer(server, row.editedAt);
    final base = row.base == null ? null : RemoteRows.toDb(Tables.answers, row.base!);

    if (RemoteRows.deleted(server)) {
      if (row.deleted) return (null, _Result.synced);
      return serverNewer ? (null, _Result.stale) : (alive(), _Result.written);
    }
    if (row.deleted) {
      if (serverNewer && base != null && !RemoteRows.same(base['valor'], server['valor'])) {
        return (null, _Result.stale);
      }
      return ({...local, 'valor': server['valor'], 'eliminado_en': _now()}, _Result.written);
    }
    if (_merge(local, base ?? server, server, localWins: !serverNewer).isNotEmpty) return (alive(), _Result.written);
    return (null, RemoteRows.same(local['valor'], server['valor']) ? _Result.synced : _Result.stale);
  }

  // ---------------------------------------------------------------- ayuda

  /// Pendientes que se pueden subir. Lo del modo demo o lo que cuelga de algo
  /// que no está en el servidor se queda en el teléfono.
  Future<List<PendingRow>> _pending(String table, String? Function(PendingRow) parentOf) async {
    final out = <PendingRow>[];
    for (final r in await store.db.pending(table)) {
      if (_hasDemoIds(r.data) || _missing.contains(parentOf(r))) {
        _missing.add(r.id);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  static bool _hasDemoIds(Map<String, Object?> j) => [
        j['supervisorId'],
        j['technicianId'],
        j['userId'],
        j['addedById'],
        ...?(j['technicianIds'] as List?),
      ].any((v) => v is String && v.startsWith(_demoPrefix));

  Future<void> _done(RemoteTable t, PendingRow row, _Result result, {required String refetchId}) async {
    await store.db.markSynced(t.local, row.id, editedAt: row.editedAt, base: row.deleted ? null : row.data);
    if (result == _Result.stale) _refetch(t, refetchId);
  }

  void _refetch(RemoteTable t, String id) => refetch.putIfAbsent(t.name, () => {}).add(id);

  /// Columnas que cambió el teléfono respecto a [base]. Si el servidor también
  /// cambió una a otro valor, se sube sólo si gana el teléfono ([localWins]).
  static Map<String, Object?> _merge(
    Map<String, Object?> local,
    Map<String, Object?> base,
    Map<String, Object?> server, {
    required bool localWins,
  }) =>
      {
        for (final c in local.keys)
          if (!RemoteRows.same(local[c], base[c]) &&
              !RemoteRows.same(local[c], server[c]) &&
              (localWins || RemoteRows.same(server[c], base[c])))
            c: local[c],
      };

  /// Columnas de [a] con otro valor en [b].
  static Map<String, Object?> _diff(Map<String, Object?> a, Map<String, Object?> b) => {
        for (final c in a.keys)
          if (!RemoteRows.same(a[c], b[c])) c: a[c],
      };

  /// El servidor cambió la fila después de que el teléfono la editó.
  static bool _serverNewer(RemoteRow server, String editedAt) =>
      DateTime.parse('${server['actualizado_en']}').isAfter(DateTime.parse(editedAt));

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
