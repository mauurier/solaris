import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/auth/profile.dart';
import 'package:proyecto_app/data/catalog.dart';
import 'package:proyecto_app/data/app_state.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/storage/persistence.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:proyecto_app/data/sync/remote_rows.dart';
import 'package:proyecto_app/data/sync/sync_queue.dart';
import 'package:proyecto_app/data/sync/sync_service.dart';
import 'package:proyecto_app/features/sync/sync_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_remote.dart';
import 'fixtures/electric_template.dart';
import 'test_helpers.dart';

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

  tearDown(() => signInAs(UserRole.tecnico));

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

  test('sin sesión no se baja nada', () async {
    AppState.instance.signOut();
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

  test('baja el hallazgo con su estado', () async {
    server.rows('hallazgo').add({'id': 'h1', 'id_visita': visitId, 'id_usuario': sup, 'codigo': 'HZ-001',
        'categoria': 'seguridad', 'descripcion': 'Sin señalización', 'severidad': 'alta', 'ubicacion': null,
        'recomendacion': 'Colocar letreros', 'estado': 'en_revision', 'latitud': 25.78, 'longitud': -100.18,
        'creado_en': at(6), 'actualizado_en': at(6), 'eliminado_en': null});
    await SyncService.instance.pull();
    final f = store.findingsOf(visitId).single;
    expect(f.category, FindingCategory.seguridad);
    expect(f.status, FindingStatus.enRevision);
    expect(f.recommendation, 'Colocar letreros');
    expect(f.point!.lat, 25.78);
  });

  test('baja la revisión con sus correcciones', () async {
    server.rows('revision').add({'id': 'rv1', 'id_visita': visitId, 'id_supervisor': sup,
        'decision': 'con_correcciones', 'observaciones': 'Casi', 'creado_en': at(6)});
    server.rows('correccion').add({'id': 'c1', 'id_revision': 'rv1', 'descripcion': 'Medir L3',
        'estado': 'pendiente', 'atendida_en': null, 'creado_en': at(6), 'actualizado_en': at(6), 'eliminado_en': null});
    await SyncService.instance.pull();

    final review = store.reviewsOf(visitId).single;
    expect(review.decision, ReviewDecision.corrections);
    expect(review.notes, 'Casi');
    expect(store.pendingCorrections(visitId).single.description, 'Medir L3');

    server.rows('correccion').single
      ..['estado'] = 'atendida'
      ..['atendida_en'] = at(7)
      ..['actualizado_en'] = at(7);
    await SyncService.instance.pull();
    expect(store.pendingCorrections(visitId), isEmpty);
  });

  test('los estados se escriben como en la base', () {
    expect(RemoteRows.statusToDb(ProjectStatus.conCorrecciones), 'con_correcciones');
    for (final s in ProjectStatus.values) {
      expect(RemoteRows.statusFromDb(RemoteRows.statusToDb(s)), s);
    }
  });

  test('no manda a revisión una visita que cerró otro teléfono', () async {
    // El técnico la cerró en su teléfono y todavía sube sus fotos: aquí llega
    // "por sincronizar" sin nada que este teléfono deba subir.
    server.rows('visita').single
      ..['estado'] = 'pendiente_sync'
      ..['fecha_fin'] = at(5)
      ..['actualizado_en'] = at(5);
    await SyncService.instance.sync();
    await SyncService.instance.sync();
    expect(SyncService.instance.error, isNull);

    final v = store.visit(visitId)!;
    expect(v.finished, isTrue);
    expect(v.status, ProjectStatus.pendienteSync, reason: 'la pasa a revisión el teléfono que la cerró');
    expect(server.rows('visita').single['estado'], 'pendiente_sync');
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

    test('si la sincronización se corta tras subir el cierre, la siguiente manda la visita a revisión', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.startVisit(v, null);
      await store.addEvidence(visit: v, key: croquis, kind: EvidenceKind.photo, file: tempFile('croquis.jpg', [1]));
      await sync();
      expect(v.status, ProjectStatus.enCaptura);

      // Se cierra la visita (sus fotos ya subieron) y hay un documento del
      // proyecto por subir. Se pierde la señal justo en ese documento: el
      // cierre de la visita ya quedó arriba, pero el paso a revisión no llegó.
      await store.finishVisit(v, null);
      await store.addDocument(p.id, 'recibo_cfe', tempFile('recibo.pdf', [7, 7]), 'recibo.pdf');
      server.onWrite = (table, op) {
        if (table == 'documentos' && op == 'upload') throw const SocketException('Sin señal');
      };
      await SyncService.instance.sync();
      expect(SyncService.instance.error, isNotNull);
      expect(server.rows('visita').single['estado'], 'pendiente_sync');
      expect(await store.db.pending(Tables.visits), isEmpty, reason: 'el cierre sí subió');
      expect(v.status, ProjectStatus.pendienteSync);

      // Vuelve la señal: la visita ya no tiene nada pendiente, pero el
      // teléfono recuerda que le falta pasar a revisión.
      server.onWrite = null;
      await sync();
      expect(v.status, ProjectStatus.enRevision);
      expect(server.rows('visita').single['estado'], 'en_revision');
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

    test('la cola muestra lo pendiente y junta las respuestas de cada visita', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.setAnswer(v, nave, 'DSV');
      await store.setAnswer(v, const AnswerKey('g_datos', 0, 'techo'), 'TPO');
      await store.addEvidence(visit: v, key: croquis, kind: EvidenceKind.photo, file: tempFile('croquis.jpg', [1, 2]));

      final queue = await loadSyncQueue(store);
      expect(queue.map((q) => q.kind), ['Cliente', 'Sitio', 'Proyecto', 'Visita', 'Respuestas', 'Foto']);
      expect(queue[4].detail, '2 respuestas');
      expect(queue[4].keys, hasLength(2));
      expect(queue.last, isA<SyncQueueItem>().having((q) => q.file, 'file', isTrue).having((q) => q.bytes, 'bytes', 2));
      expect(await store.pendingCount(), 7);

      await sync();
      expect(await loadSyncQueue(store), isEmpty);
    });

    testWidgets('la pantalla marca lo que el servidor rechazó', (tester) async {
      await tester.runAsync(() async {
        final p = await newProject();
        await sync();
        server.readOnly.add('proyecto');
        p.name = 'Sin permiso';
        await store.updateProject(p);
        await SyncService.instance.sync();
      });
      await pumpOnPhone(tester, const SyncScreen());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('Con errores'), findsOneWidget);
      expect(find.text('MTY0142 · Sin permiso'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('No tienes permiso para cambiar este registro.'), findsOneWidget);
      expectNoRenderErrors(tester);
    });

    test('los ajustes de sincronización se guardan en el teléfono', () async {
      final app = AppState.instance;
      await app.setSyncOnWifiOnly(false);
      await app.setAutoSync(false);
      app
        ..syncOnWifiOnly = true
        ..autoSync = true;
      await app.loadSettings();
      expect(app.syncOnWifiOnly, isFalse);
      expect(app.autoSync, isFalse);
      await app.setSyncOnWifiOnly(true);
      await app.setAutoSync(true);
    });

    test('la revisión y sus correcciones suben, y lo atendido también', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.startVisit(v, null);
      await store.finishVisit(v, null);
      await store.requestCorrections(v, items: ['Medir L3'], notes: 'Casi');
      await sync();

      final review = server.rows('revision').single;
      expect(review, allOf(containsPair('decision', 'con_correcciones'), containsPair('id_supervisor', me),
          containsPair('observaciones', 'Casi'), containsPair('id_visita', v.id)));
      final correction = server.rows('correccion').single;
      expect(correction, allOf(containsPair('estado', 'pendiente'), containsPair('id_revision', review['id'])));
      expect(server.rows('visita').single['estado'], 'con_correcciones');
      expect(server.writes.indexWhere((w) => w.startsWith('revision:')),
          lessThan(server.writes.indexWhere((w) => w.startsWith('correccion:'))));

      await store.setCorrectionAttended(store.pendingCorrections(v.id).single, true);
      await sync();
      expect(correction['estado'], 'atendida');
      expect(correction['atendida_en'], isNotNull);
      expect(server.updated['correccion'], [
        {'estado', 'atendida_en'}
      ]);
      expect(await pendingTables(), isEmpty);
    });

    test('el hallazgo sube antes que su foto, que queda ligada a él', () async {
      final p = await newProject();
      final v = store.latestVisit(p.id)!;
      await store.startVisit(v, null);
      final f = await store.addFinding(v,
          category: FindingCategory.termografico, severity: Severity.critica, description: 'Punto caliente');
      await store.addEvidence(visit: v, findingId: f.id, kind: EvidenceKind.photo, file: tempFile('h.jpg', [9]));
      f.status = FindingStatus.enRevision;
      await store.updateFinding(f);
      await sync();

      final row = server.rows('hallazgo').single;
      expect(row, allOf(containsPair('codigo', 'HZ-001'), containsPair('categoria', 'termografico'),
          containsPair('severidad', 'critica'), containsPair('estado', 'en_revision'), containsPair('id_usuario', me)));
      final photo = server.rows('evidencia').single;
      expect(photo['id_hallazgo'], f.id);
      expect(photo['clave_pregunta'], isNull);
      expect(server.writes.indexOf('hallazgo:insert'), lessThan(server.writes.indexOf('evidencia:insert')));
      expect(await pendingTables(), isEmpty);
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
