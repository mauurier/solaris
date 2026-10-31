import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/auth/profile.dart';
import 'package:proyecto_app/data/catalog.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/storage/persistence.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:proyecto_app/data/sync/remote_rows.dart';
import 'package:proyecto_app/data/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/electric_template.dart';
import 'test_helpers.dart';

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

const me = '11111111-1111-1111-1111-111111111111';
const sup = '22222222-2222-2222-2222-222222222222';
const clientId = 'c0000000-0000-0000-0000-000000000001';
const siteId = 's0000000-0000-0000-0000-000000000001';
const projectId = 'p0000000-0000-0000-0000-000000000001';
const visitId = 'v0000000-0000-0000-0000-000000000001';

String at(int minute) => DateTime.utc(2026, 10, 30, 10, minute).toIso8601String();

void fillServer(FakeRemote r) {
  r.rows('cliente').add({'id': clientId, 'razon_social': 'TRUPER', 'rfc': 'TRU850214QW3', 'contacto': null,
      'actualizado_en': at(0), 'eliminado_en': null});
  r.rows('sitio').add({'id': siteId, 'id_cliente': clientId, 'nombre': 'CEDIS Monterrey', 'direccion': 'Apodaca',
      'latitud': 25.7834, 'longitud': '-100.1889', 'actualizado_en': at(0), 'eliminado_en': null});
  r.rows('motivo_visita').add({'id': 'b95699bc-09d3-4d43-8918-6cdf92070694', 'nombre': 'Actividades posteriores',
      'orden': 4, 'actualizado_en': at(0), 'eliminado_en': at(0)});
  r.rows('tipo_proyecto').add({'id': 'tp-nuevo', 'nombre': 'Inspección termográfica', 'orden': 5,
      'actualizado_en': at(0), 'eliminado_en': null});
  final tpl = electricTemplate();
  r.rows('plantilla').add({'id': tpl.id, 'nombre': tpl.name, 'tipo': tpl.type,
      'version_mayor': 2, 'version_menor': 3, 'activa': true, 'definicion': {'sections': tpl.toJson()['sections']},
      'actualizado_en': at(1), 'eliminado_en': null});
  r.rows('proyecto').add({'id': projectId, 'id_sitio': siteId, 'id_tipo_proyecto': 'tp-nuevo', 'id_supervisor': sup,
      'id_plantilla': tpl.id, 'codigo': 'MTY0142', 'nombre': 'TRUPER Monterrey', 'descripcion': null,
      'fecha_programada': null, 'estado': 'en_captura', 'creado_en': at(1), 'actualizado_en': at(1),
      'eliminado_en': null});
  r.rows('proyecto_tecnico').add({'id_proyecto': projectId, 'id_tecnico': me, 'creado_en': at(1),
      'actualizado_en': at(1), 'eliminado_en': null});
  r.rows('visita').add({'id': visitId, 'id_proyecto': projectId, 'id_tecnico': me, 'id_supervisor': sup,
      'id_motivo': null, 'id_plantilla': tpl.id, 'numero': 1, 'fecha_programada': null, 'fecha_inicio': at(2),
      'fecha_fin': null, 'lat_inicio': 25.78, 'lng_inicio': -100.18, 'lat_fin': null, 'lng_fin': null,
      'estado': 'en_captura', 'notas': null, 'fecha_ultima_apertura': null, 'plantilla_usada': tpl.toJson(),
      'repeticiones': {'g_tablero': 2}, 'justificaciones': {}, 'creado_en': at(1), 'actualizado_en': at(2),
      'eliminado_en': null});
  r.rows('respuesta').add({'id': 'r1', 'id_visita': visitId, 'clave_grupo': 'g_datos', 'numero_repeticion': 0,
      'clave_pregunta': 'nave', 'valor': 'DSV', 'actualizado_en': at(3), 'eliminado_en': null});
}

void main() {
  late SurveyStore store;
  late FakeRemote server;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    store = await initTestStore(withTemplate: false);
    server = FakeRemote();
    fillServer(server);
    SyncService.instance.remote = server;
    SyncService.instance.filesAllowed = () async => true;
    AppState.instance.signIn(Profile(
        id: me, email: 'tec@solaris.mx', name: 'Juan Pérez', role: 'tecnico', active: true, startsOn: DateTime(2026)));
  });

  tearDown(() => AppState.instance.setRole(UserRole.tecnico));

  test('la primera bajada trae todo y nada queda pendiente de subir', () async {
    await SyncService.instance.pull();
    expect(SyncService.instance.error, isNull);

    final p = store.project(projectId)!;
    expect(p.name, 'TRUPER Monterrey');
    expect(p.client, 'TRUPER');
    expect(p.coords!.lng, -100.1889, reason: 'numeric puede llegar como texto');
    expect(p.technicianIds, [me]);
    expect(p.status, ProjectStatus.enCaptura);
    expect(p.type, 'Inspección termográfica');
    expect(store.projectsFor(UserRole.tecnico, me), [p]);

    final v = store.visit(visitId)!;
    expect(v.started, isTrue);
    expect(v.startPoint!.lat, 25.78);
    expect(v.motive, 'Levantamiento inicial');
    expect(v.instances['g_tablero'], 2);
    expect(v.template!.sections, isNotEmpty);
    expect(store.answersOf(visitId)['g_datos#0/nave'], 'DSV');

    final tpl = store.templates.single;
    expect(tpl.id, electricTemplate().id, reason: 'la única plantilla es la del servidor');
    expect(tpl.version, 'v2.3');
    expect(tpl.sections, isNotEmpty);
    final motives = store.catalog(CatalogKind.visitMotives).map((m) => m.name);
    expect(motives, isNot(contains('Actividades posteriores')), reason: 'borrado en el servidor');

    for (final t in [Tables.templates, Tables.clients, Tables.sites, Tables.projects, Tables.visits, Tables.answers]) {
      expect(await store.db.pending(t), isEmpty, reason: '$t vino del servidor');
    }
  });

  test('después sólo pide lo nuevo y actualiza los objetos abiertos', () async {
    await SyncService.instance.pull();
    final p = store.project(projectId)!;
    expect(server.asked['proyecto'], isNull, reason: 'la primera vez pide todo');

    server.rows('proyecto').single
      ..['nombre'] = 'TRUPER MTY'
      ..['actualizado_en'] = at(30);
    await SyncService.instance.pull();
    expect(server.asked['proyecto'], DateTime.parse(at(1)).subtract(SyncService.overlap),
        reason: 'desde la última, con margen');
    expect(identical(store.project(projectId), p), isTrue);
    expect(p.name, 'TRUPER MTY');
  });

  test('un cambio local sin subir no se pisa', () async {
    await SyncService.instance.pull();
    final p = store.project(projectId)!..name = 'Nombre local';
    await store.updateProject(p);

    server.rows('proyecto').single
      ..['nombre'] = 'Nombre del servidor'
      ..['actualizado_en'] = at(40);
    await SyncService.instance.pull();
    expect(p.name, 'Nombre local');
  });

  test('si le quitan el proyecto se borra del teléfono, salvo lo que no ha subido', () async {
    await SyncService.instance.pull();
    final mine = await seedProject(store); // creado en el teléfono, pendiente
    server.visible['proyecto'] = {};
    server.visible['visita'] = {};
    server.visible['proyecto_tecnico'] = {};

    await SyncService.instance.pull();
    expect(store.project(projectId), isNull);
    expect(store.visit(visitId), isNull);
    expect(store.answersOf(visitId), isEmpty);
    expect(store.project(mine.id), isNotNull, reason: 'falta subirlo');
  });

  test('un proyecto asignado después llega aunque no haya cambiado', () async {
    server.visible['proyecto'] = {};
    server.visible['visita'] = {};
    server.visible['proyecto_tecnico'] = {};
    await SyncService.instance.pull();
    expect(store.projects, isEmpty);

    // Lo asignan: proyecto y visita siguen con su hora vieja.
    server.visible.clear();
    server.rows('proyecto_tecnico').single['actualizado_en'] = at(50);
    await SyncService.instance.pull();
    expect(store.project(projectId)!.technicianIds, [me]);
    expect(store.visit(visitId), isNotNull);
    expect(store.answersOf(visitId)['g_datos#0/nave'], 'DSV', reason: 'con todas sus respuestas');
  });

  test('técnicos y respuestas borrados en el servidor se quitan', () async {
    await SyncService.instance.pull();
    server.rows('proyecto_tecnico').add({'id_proyecto': projectId, 'id_tecnico': 'otro', 'creado_en': at(5),
        'actualizado_en': at(5), 'eliminado_en': null});
    server.rows('respuesta').single
      ..['eliminado_en'] = at(5)
      ..['actualizado_en'] = at(5);
    await SyncService.instance.pull();
    expect(store.project(projectId)!.technicianIds, [me, 'otro']);
    expect(store.answersOf(visitId), isEmpty);

    server.rows('proyecto_tecnico').last
      ..['eliminado_en'] = at(6)
      ..['actualizado_en'] = at(6);
    await SyncService.instance.pull();
    expect(store.project(projectId)!.technicianIds, [me]);
  });

  test('en el modo demo no se baja nada', () async {
    AppState.instance.setRole(UserRole.tecnico);
    await SyncService.instance.pull();
    expect(store.projects, isEmpty);
    expect(server.asked, isEmpty);
  });

  test('el técnico sólo sube lo que cambió al terminar su visita', () async {
    await SyncService.instance.pull();
    final v = store.visit(visitId)!;
    await store.finishVisit(v, const GeoPoint(25.7801, -100.1802));
    await SyncService.instance.sync();
    expect(SyncService.instance.error, isNull);

    // Primero el cierre; como no tiene archivos pendientes, luego pasa a revisión.
    expect(server.updated['proyecto'], [
      {'estado'},
      {'estado'}
    ]);
    expect(server.updated['visita'], [
      {'fecha_fin', 'lat_fin', 'lng_fin', 'estado'},
      {'estado'}
    ], reason: 'nada de la asignación, que el técnico no puede cambiar');
    expect(server.rows('visita').single['estado'], 'en_revision');
    expect(server.rows('proyecto').single['nombre'], 'TRUPER Monterrey');
  });

  test('en otro teléfono baja la fila de la evidencia y luego su archivo', () async {
    server.rows('evidencia').add({'id': 'e1', 'id_visita': visitId, 'id_usuario': me, 'clave_grupo': 'g_datos',
        'numero_repeticion': 0, 'clave_pregunta': 'croquis', 'tipo': 'foto', 'ruta_archivo': '$projectId/$visitId/e1.jpg',
        'mime_type': 'image/jpeg', 'tamano': 3, 'nombre_original': 'croquis.jpg', 'fecha_captura': at(4),
        'latitud': 25.78, 'longitud': -100.18, 'comentario': null, 'importada': false, 'subido_en': at(4),
        'actualizado_en': at(4), 'eliminado_en': null});
    server.files['evidencias/$projectId/$visitId/e1.jpg'] = [1, 2, 3];

    SyncService.instance.filesAllowed = () async => false;
    await SyncService.instance.pull();
    final e = store.evidenceOf(visitId, const AnswerKey('g_datos', 0, 'croquis')).single;
    expect(e.kind, EvidenceKind.photo);
    expect(store.files.exists(e.path), isFalse, reason: 'sin Wi-Fi el archivo no se baja');

    SyncService.instance.filesAllowed = () async => true;
    await SyncService.instance.pull();
    expect(store.files.file(e.path).readAsBytesSync(), [1, 2, 3]);
    expect(await store.db.pending(Tables.evidences), isEmpty);
  });

  test('los estados se escriben como en la base', () {
    expect(RemoteRows.statusToDb(ProjectStatus.conCorrecciones), 'con_correcciones');
    for (final s in ProjectStatus.values) {
      expect(RemoteRows.statusFromDb(RemoteRows.statusToDb(s)), s);
    }
  });

  group('Subida', () {
    setUp(() async {
      store = await initTestStore();
      server = FakeRemote();
      SyncService.instance.remote = server;
      AppState.instance.signIn(Profile(
          id: me, email: 'admin@solaris.mx', name: 'Ana Admin', role: 'admin', active: true, startsOn: DateTime(2026)));
    });

    Future<SurveyProject> newProject({String supervisor = sup}) async {
      final client = await store.addClient('TRUPER', rfc: 'TRU850214QW3');
      return store.createProject(
        code: 'MTY0142',
        name: 'TRUPER Monterrey',
        clientId: client.id,
        site: 'CEDIS Monterrey',
        address: 'Apodaca',
        coords: const GeoPoint(25.78345678, -100.1889),
        scheduledAt: DateTime(2026, 11, 3, 9),
        supervisorId: supervisor,
        technicianIds: [me],
        template: store.templates.first,
        typeId: store.catalog(CatalogKind.projectTypes).first.id,
      );
    }

    Future<void> sync() async {
      await SyncService.instance.sync();
      expect(SyncService.instance.error, isNull);
    }

    Future<List<String>> pendingTables() async => [
          for (final t in Tables.all)
            if ((await store.db.pending(t)).isNotEmpty) t,
        ];

    const nave = AnswerKey('g_datos', 0, 'nave');

    test('lo creado en el teléfono sube en orden y deja de estar pendiente', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.setAnswer(v, nave, 'DSV');
      await sync();

      final c = server.rows('cliente').single;
      expect(c['razon_social'], 'TRUPER');
      final site = server.rows('sitio').single;
      expect(site['id_cliente'], c['id']);
      expect(site['latitud'], 25.783457, reason: 'numeric(9, 6)');
      final row = server.rows('proyecto').single;
      expect(row['id'], p.id);
      expect(row['estado'], 'asignado');
      expect(row['id_supervisor'], sup);
      expect(DateTime.parse(row['fecha_programada'] as String).toLocal(), DateTime(2026, 11, 3, 9), reason: 'en UTC');
      expect(server.rows('proyecto_tecnico').single, containsPair('id_tecnico', me));
      expect(server.rows('visita').single, containsPair('numero', 1));
      expect(server.rows('respuesta').single,
          allOf(containsPair('clave_grupo', 'g_datos'), containsPair('clave_pregunta', 'nave'), containsPair('valor', 'DSV')));

      final order = ['cliente', 'sitio', 'proyecto', 'proyecto_tecnico', 'visita', 'respuesta']
          .map((t) => server.writes.indexWhere((w) => w.startsWith('$t:')))
          .toList();
      expect(order, [...order]..sort(), reason: 'cada tabla después de la que la referencia');
      expect(await pendingTables(), isEmpty);
    });

    test('lo que sólo se tocó en el teléfono no se vuelve a escribir', () async {
      final p = await newProject();
      await sync();
      server.writes.clear();
      await store.updateProject(p); // sólo cambia la hora local
      await sync();
      expect(server.writes, isEmpty);
      expect(await store.db.pending(Tables.projects), isEmpty);
    });

    test('lo que otro cambió en otras columnas no se pisa', () async {
      final p = await newProject();
      await sync();
      server.rows('proyecto').single
        ..['nombre'] = 'TRUPER MTY'
        ..['actualizado_en'] = DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
      p.description = 'Acceso por la puerta 3';
      await store.updateProject(p);
      await sync();

      final row = server.rows('proyecto').single;
      expect(row['nombre'], 'TRUPER MTY');
      expect(row['descripcion'], 'Acceso por la puerta 3');
      expect(p.name, 'TRUPER MTY', reason: 'bajó lo del servidor');
      expect(p.description, 'Acceso por la puerta 3');
    });

    test('si los dos cambian la misma columna gana el cambio más reciente', () async {
      final p = await newProject();
      await sync();
      final row = server.rows('proyecto').single;

      // Primero el servidor, después el teléfono: gana el teléfono.
      row
        ..['nombre'] = 'Servidor'
        ..['actualizado_en'] = FakeRemote.now();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      p.name = 'Teléfono';
      await store.updateProject(p);
      await sync();
      expect(row['nombre'], 'Teléfono');

      // Primero el teléfono, después el servidor: gana el servidor.
      p.name = 'Teléfono otra vez';
      await store.updateProject(p);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      row
        ..['nombre'] = 'Servidor otra vez'
        ..['actualizado_en'] = FakeRemote.now();
      await sync();
      expect(row['nombre'], 'Servidor otra vez');
      expect(p.name, 'Servidor otra vez');
      expect(await store.db.pending(Tables.projects), isEmpty);
    });

    test('borrar en el teléfono marca eliminado_en en el servidor', () async {
      final p = await newProject();
      await store.setAnswer(store.latestVisit(p.id)!, nave, 'DSV');
      await sync();
      await store.deleteProject(p);
      await sync();
      for (final t in ['proyecto', 'visita', 'respuesta']) {
        expect(server.rows(t).single['eliminado_en'], isNotNull, reason: t);
      }
      expect(store.projects, isEmpty);
      expect(await pendingTables(), isEmpty);
    });

    test('se suben las altas y bajas de técnicos sin quitar a quien asignó otro', () async {
      final p = await newProject();
      await sync();
      p.technicianIds
        ..remove(me)
        ..add('tec2');
      await store.updateProject(p);
      await sync();
      String? removed(String tech) => server.rows('proyecto_tecnico').firstWhere((r) => r['id_tecnico'] == tech)['eliminado_en'] as String?;
      expect(removed(me), isNotNull);
      expect(removed('tec2'), isNull);

      // Otro asigna a tec3; el teléfono, sin saberlo, sólo toca el proyecto.
      server.rows('proyecto_tecnico').add({'id_proyecto': p.id, 'id_tecnico': 'tec3', 'creado_en': FakeRemote.now(),
          'actualizado_en': FakeRemote.now(), 'eliminado_en': null});
      await store.updateProject(p);
      await sync();
      expect(removed('tec3'), isNull);
      expect(p.technicianIds, ['tec2', 'tec3']);
    });

    test('un cambio hecho mientras se sube queda pendiente para la siguiente vez', () async {
      final p = await newProject();
      await sync();
      p.name = 'Primero';
      await store.updateProject(p);
      server.onWrite = (table, op) {
        if (table != 'proyecto') return;
        server.onWrite = null;
        p.name = 'Durante';
        store.updateProject(p);
      };
      await sync();
      expect(server.rows('proyecto').single['nombre'], 'Primero');
      expect(p.name, 'Durante', reason: 'la bajada no pisa lo pendiente');
      expect(await store.db.pending(Tables.projects), hasLength(1));

      await sync();
      expect(server.rows('proyecto').single['nombre'], 'Durante');
    });

    test('lo del modo demo no se sube', () async {
      final p = await newProject(supervisor: 'demo-lmendez');
      await sync();
      expect(server.rows('cliente'), hasLength(1), reason: 'no tiene ids de personas');
      expect(server.rows('proyecto'), isEmpty);
      expect(server.rows('visita'), isEmpty, reason: 'su proyecto no está arriba');
      expect(store.project(p.id), isNotNull);
      expect(await pendingTables(), containsAll([Tables.projects, Tables.visits]));
    });

    test('si el servidor rechaza un cambio, sigue pendiente y lo demás sí sube', () async {
      final p = await newProject();
      await sync();
      server.readOnly.add('proyecto');
      p.name = 'Sin permiso';
      await store.updateProject(p);
      await store.setAnswer(store.latestVisit(p.id)!, nave, 'DSV');
      await SyncService.instance.sync();

      expect(SyncService.instance.error, 'Un cambio no se pudo subir: No tienes permiso para cambiar este registro.');
      expect(server.rows('proyecto').single['nombre'], 'TRUPER Monterrey');
      expect(await store.db.pending(Tables.projects), hasLength(1));
      expect(server.rows('respuesta').single['valor'], 'DSV');
      expect(await store.db.pending(Tables.answers), isEmpty);
    });

    test('una respuesta borrada se marca y al escribirla otra vez revive', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.setAnswer(v, nave, 'DSV');
      await sync();
      final row = server.rows('respuesta').single;

      await store.setAnswer(v, nave, null);
      await sync();
      expect(row['eliminado_en'], isNotNull);
      expect(store.answersOf(v.id), isEmpty);
      expect(await store.db.pending(Tables.answers), isEmpty);

      await store.setAnswer(v, nave, 'Nave 2');
      await sync();
      expect(server.rows('respuesta').single, same(row), reason: 'misma fila, por su llave única');
      expect(row['eliminado_en'], isNull);
      expect(row['valor'], 'Nave 2');
    });

    File tempFile(String name, List<int> bytes) {
      final dir = Directory.systemTemp.createTempSync('solaris_up_');
      addTearDown(() => dir.deleteSync(recursive: true));
      return File('${dir.path}/$name')..writeAsBytesSync(bytes);
    }

    const croquis = AnswerKey('g_datos', 0, 'croquis');

    test('la evidencia sube su archivo antes que su fila y la visita terminada pasa a revisión', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.startVisit(v, const GeoPoint(25.78, -100.18));
      final e = await store.addEvidence(
          visit: v, key: croquis, kind: EvidenceKind.photo, file: tempFile('croquis.jpg', [1, 2, 3, 4]));
      await store.finishVisit(v, null);
      await sync();

      final path = '${p.id}/${v.id}/${e.id}.jpg';
      expect(server.files['evidencias/$path'], [1, 2, 3, 4]);
      final row = server.rows('evidencia').single;
      expect(row, allOf(containsPair('ruta_archivo', path), containsPair('tipo', 'foto'), containsPair('tamano', 4)));
      expect(row['subido_en'], isNotNull);
      expect(row['clave_pregunta'], 'croquis');
      expect(server.writes.indexOf('evidencias:upload'), lessThan(server.writes.indexOf('evidencia:insert')));

      expect(v.status, ProjectStatus.enRevision);
      expect(p.status, ProjectStatus.enRevision);
      expect(server.rows('visita').single['estado'], 'en_revision');
      expect(server.rows('proyecto').single['estado'], 'en_revision');
      expect(await pendingTables(), isEmpty);
    });

    test('sin Wi-Fi los archivos esperan y la visita sigue por sincronizar', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.startVisit(v, null);
      await store.addEvidence(visit: v, key: croquis, kind: EvidenceKind.photo, file: tempFile('a.jpg', [1]));
      await store.finishVisit(v, null);

      SyncService.instance.filesAllowed = () async => false;
      await sync();
      expect(SyncService.instance.waitingForWifi, 1);
      expect(server.rows('evidencia'), isEmpty);
      expect(server.files, isEmpty);
      expect(server.rows('visita').single['estado'], 'pendiente_sync', reason: 'los datos sí suben');
      expect(v.status, ProjectStatus.pendienteSync);

      SyncService.instance.filesAllowed = () async => true;
      await sync();
      expect(SyncService.instance.waitingForWifi, 0);
      expect(server.rows('evidencia'), hasLength(1));
      expect(server.rows('visita').single['estado'], 'en_revision');
    });

    test('el documento del proyecto sube a su carpeta del bucket documentos', () async {
      final p = await newProject();
      final d = await store.addDocument(p.id, 'recibo_cfe', tempFile('recibo.pdf', [7, 7]), 'recibo.pdf');
      await sync();
      expect(server.files['documentos/${p.id}/${d.id}.pdf'], [7, 7]);
      final row = server.rows('documento').single;
      expect(row, allOf(containsPair('categoria', 'recibo_cfe'), containsPair('id_usuario', me),
          containsPair('mime_type', 'application/pdf'), containsPair('tamano', 2)));
    });

    test('reemplazar la foto sube la nueva y borra la anterior de Storage', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      final e = await store.addEvidence(visit: v, key: croquis, kind: EvidenceKind.photo, file: tempFile('a.jpg', [1]));
      await sync();
      final before = server.rows('evidencia').single['ruta_archivo'];
      await store.replaceEvidenceFile(e, tempFile('b.jpg', [2, 2]));
      await sync();
      final after = server.rows('evidencia').single['ruta_archivo'];
      expect(after, isNot(before));
      expect(server.files.keys, ['evidencias/$after']);
      expect(server.files['evidencias/$after'], [2, 2]);
    });

    test('lo que edita el admin en catálogos y plantillas sube', () async {
      const types = CatalogKind.projectTypes;
      final item = store.catalog(types).first;
      server.rows('tipo_proyecto').add({'id': item.id, 'nombre': item.name, 'orden': item.order,
          'actualizado_en': at(0), 'eliminado_en': null});
      await store.renameCatalogItem(types, item, 'Viabilidad fotovoltaica');
      final t = store.templates.first.copy()..name = 'Levantamiento eléctrico FV (Truper)';
      await store.saveTemplate(t);
      await sync();

      expect(server.rows('tipo_proyecto').single['nombre'], 'Viabilidad fotovoltaica');
      expect(server.writes, contains('tipo_proyecto:update'), reason: 'ya existía arriba');
      final tpl = server.rows('plantilla').single;
      expect(tpl['nombre'], 'Levantamiento eléctrico FV (Truper)');
      expect(tpl['version_menor'], 1);
      expect((tpl['definicion'] as Map)['sections'], isNotEmpty);
      expect(await pendingTables(), isEmpty);
    });
  });
}
