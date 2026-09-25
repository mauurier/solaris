import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:proyecto_app/core/services/export_service.dart';
import 'package:proyecto_app/core/services/watermark.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/storage/file_store.dart';
import 'package:proyecto_app/data/storage/persistence.dart';
import 'package:proyecto_app/data/storage/sqlite_persistence.dart';
import 'package:proyecto_app/data/survey/default_template.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/data/survey/template.dart';
import 'package:proyecto_app/data/survey/visit_engine.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

/// Genera un JPEG de prueba con un color uniforme.
File _jpeg(Directory dir, String name, {int w = 800, int h = 600}) {
  final image = img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 180, 60));
  return File(p.join(dir.path, name))..writeAsBytesSync(img.encodeJpg(image));
}

void main() {
  setUp(() => AppState.instance.setRole(UserRole.tecnico));

  group('Plantilla', () {
    test('sobrevive a un viaje por JSON sin perder nada', () {
      final t = defaultElectricTemplate();
      final again = TemplateDef.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, Object?>);
      expect(jsonEncode(again.toJson()), jsonEncode(t.toJson()));
    });

    test('la plantilla eléctrica es coherente', () {
      final t = defaultElectricTemplate();
      expect(t.sections.map((s) => s.title), [
        'Información principal',
        'Subestación',
        'Medición',
        'Cubierta',
        'Fotos, videos y documentos',
        'Cierre',
      ]);
      final groupIds = <String>{};
      for (final s in t.sections) {
        for (final g in s.groups) {
          expect(groupIds.add(g.id), isTrue, reason: 'bloque duplicado ${g.id}');
          final ids = g.questions.map((q) => q.id).toList();
          expect(ids.toSet().length, ids.length, reason: 'id repetido en ${g.id}');
          for (final q in g.questions) {
            if (q.showIf != null) {
              expect(ids, contains(q.showIf!.questionId), reason: '${q.id} depende de algo fuera del bloque');
            }
            if (q.type.isEvidence) {
              final folder = q.folder.replaceAll('/{INSTANCIA}', '');
              expect(Folders.all, contains(folder), reason: '${q.id} apunta a $folder');
            }
          }
        }
      }
    });

    test('nombra instancias como en las instrucciones', () {
      final t = defaultElectricTemplate();
      final tableros = t.sections[1].groups[1];
      final trafos = t.sections[1].groups[0];
      expect([0, 1, 2].map(tableros.instanceName), ['Tablero Principal', 'Tablero 01', 'Tablero 02']);
      expect([0, 1].map(trafos.instanceName), ['Transformador 1', 'Transformador 2']);
      expect(TemplateDef.code(1, 0, 2), '2.1.3');
    });
  });

  group('Motor de visita', () {
    VisitEngine engine({Map<String, String> answers = const {}, Map<String, int> instances = const {},
            List<Evidence> evidences = const [], Set<String> docs = const {}, Map<String, String> just = const {}}) =>
        VisitEngine(
          template: defaultElectricTemplate(),
          instances: instances,
          answers: answers,
          evidences: evidences,
          projectDocCategories: docs,
          justifications: just,
        );

    Iterable<String> visibleIds(VisitEngine e, String groupId) =>
        e.questions().where((rq) => rq.group.id == groupId).map((rq) => rq.question.id);

    test('los campos condicionales aparecen según la respuesta', () {
      expect(visibleIds(engine(), 'g_cuarto'), isNot(contains('unifilar_doc')));
      final si = engine(answers: {'g_cuarto#0/unifilar': 'Sí'});
      expect(visibleIds(si, 'g_cuarto'), contains('unifilar_doc'));
      expect(visibleIds(si, 'g_cuarto'), isNot(contains('unifilar_mano')));
      final no = engine(answers: {'g_cuarto#0/unifilar': 'No'});
      expect(visibleIds(no, 'g_cuarto'), contains('unifilar_mano'));
    });

    test('el sistema FV existente sólo pide datos si existe', () {
      expect(visibleIds(engine(), 'g_sfv'), ['existe']);
      final e = engine(answers: {'g_sfv#0/existe': 'Sí'});
      expect(visibleIds(e, 'g_sfv'), containsAll(['modulos', 'fabricante', 'potencia', 'inversores']));
    });

    test('cada instancia de un bloque repetible suma sus preguntas', () {
      final one = engine().questions().where((rq) => rq.group.id == 'g_transformador').length;
      final two = engine(instances: {'g_transformador': 2}).questions().where((rq) => rq.group.id == 'g_transformador');
      expect(two.length, one * 2);
      expect(two.last.instanceName, 'Transformador 2');
    });

    test('un documento del proyecto responde la pregunta equivalente', () {
      bool recibo(VisitEngine e) => e.isAnswered(e.questions().firstWhere((rq) => rq.question.id == 'recibo'));
      expect(recibo(engine()), isFalse);
      expect(recibo(engine(docs: {'recibo_cfe'})), isTrue);
    });

    test('las fotos cuentan hasta llegar al mínimo', () {
      Evidence ev(String id) => Evidence(
            id: id,
            visitId: 'v',
            projectId: 'p',
            key: 'g_transformador#0/generales',
            kind: EvidenceKind.photo,
            path: 'x.jpg',
            capturedAt: DateTime(2026),
            user: 'Juan Pérez',
          );
      bool done(VisitEngine e) => e.isAnswered(e.questions().firstWhere((rq) => rq.question.id == 'generales'));
      expect(done(engine(evidences: [ev('a')])), isFalse); // pide 2
      expect(done(engine(evidences: [ev('a'), ev('b')])), isTrue);
    });

    test('distingue pendientes obligatorios, opcionales y justificados', () {
      final e = engine();
      final kinds = e.pendings().map((x) => x.kind).toSet();
      expect(kinds, containsAll([PendingKind.blocking, PendingKind.optional]));
      expect(e.canClose, isFalse);

      final key = e.pendings().firstWhere((x) => x.kind == PendingKind.blocking).question.key.toString();
      final j = engine(just: {key: 'Sin acceso'});
      expect(j.blockingCount, e.blockingCount - 1);
      expect(j.pendings().where((x) => x.kind == PendingKind.justified), hasLength(1));
    });

    test('AnswerKey se lee de vuelta', () {
      const k = AnswerKey('g_tablero', 3, 'foto_itm');
      expect(AnswerKey.parse(k.toString()), k);
    });
  });

  group('Store', () {
    test('crear un proyecto genera la primera visita asignada', () async {
      final store = await initTestStore();
      final proj = await seedProject(store);
      final v = store.latestVisit(proj.id)!;
      expect(v.technician, 'Juan Pérez');
      expect(v.label, 'VIS-001');
      expect(proj.status, ProjectStatus.asignado);
      expect(store.projectsFor(UserRole.tecnico, 'Juan Pérez'), [proj]);
      expect(store.projectsFor(UserRole.tecnico, 'Diego Salas'), isEmpty);
    });

    test('la visita conserva su versión de plantilla aunque se edite', () async {
      final store = await initTestStore();
      final proj = await seedProject(store, start: true);
      final v1 = store.latestVisit(proj.id)!;
      final before = store.templateFor(v1).questionCount;

      final edited = store.templates.first.copy();
      edited.sections.first.groups.first.questions
          .add(QuestionDef(id: 'nueva', label: 'Pregunta nueva', type: QType.text));
      await store.saveTemplate(edited);
      expect(store.templates.first.version, 'v1.1');

      expect(store.templateFor(v1).questionCount, before);
      final v2 = await store.createVisit(proj, technician: 'Juan Pérez', motive: 'Mediciones adicionales');
      await store.startVisit(v2, null);
      expect(store.templateFor(v2).questionCount, before + 1);
      expect(v2.label, 'VIS-002');
    });

    test('quitar la última instancia borra sus respuestas y archivos', () async {
      final store = await initTestStore();
      final proj = await seedProject(store, start: true);
      final v = store.latestVisit(proj.id)!;
      final g = store.templateFor(v).sections[1].groups[0];
      await store.addInstance(v, g);
      await store.setAnswer(v, AnswerKey(g.id, 1, 'kva'), '750');
      final photo = _jpeg(store.files.root, 'tmp.jpg');
      final e = await store.addEvidence(
          visit: v, key: AnswerKey(g.id, 1, 'placa'), kind: EvidenceKind.photo, file: photo);
      expect(store.files.exists(e.path), isTrue);

      await store.removeLastInstance(v, g);
      expect(v.instanceCount(g), 1);
      expect(store.answersOf(v.id), isEmpty);
      expect(store.evidenceOf(v.id), isEmpty);
      expect(store.files.exists(e.path), isFalse);
    });

    test('finalizar deja el proyecto pendiente de sincronizar', () async {
      final store = await initTestStore();
      final proj = await seedProject(store, start: true);
      final v = store.latestVisit(proj.id)!;
      await store.finishVisit(v, const GeoPoint(26, -98));
      expect(v.finished, isTrue);
      expect(proj.status, ProjectStatus.pendienteSync);
      AppState.instance.setRole(UserRole.supervisor);
      await store.reopenVisit(v);
      expect(v.finished, isFalse);
      expect(proj.status, ProjectStatus.conCorrecciones);
    });

    test('borrar el proyecto elimina visitas, respuestas y archivos', () async {
      final store = await initTestStore();
      final proj = await seedProject(store, start: true);
      final v = store.latestVisit(proj.id)!;
      final doc = File(p.join(store.files.root.path, 'recibo.pdf'))..writeAsStringSync('%PDF');
      await store.addDocument(proj.id, 'recibo_cfe', doc, 'recibo.pdf');
      await store.setAnswer(v, const AnswerKey('g_datos', 0, 'nave'), 'DSV');
      await store.deleteProject(proj);
      expect(store.projects, isEmpty);
      expect(store.visits, isEmpty);
      expect(store.documents, isEmpty);
      expect(store.answersOf(v.id), isEmpty);
      expect(Directory(p.join(store.files.root.path, 'media', proj.id)).existsSync(), isFalse);
    });
  });

  group('SQLite', () {
    setUpAll(sqfliteFfiInit);

    test('los datos sobreviven a reabrir la base', () async {
      final dir = Directory.systemTemp.createTempSync('solaris_db_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = p.join(dir.path, 'solaris.db');

      final db1 = await SqlitePersistence.open(path, factory: databaseFactoryFfi);
      SurveyStore.reset();
      final store1 = await SurveyStore.init(db1, FileStore(dir));
      final proj = await seedProject(store1, start: true);
      final v = store1.latestVisit(proj.id)!;
      await store1.setAnswer(v, const AnswerKey('g_datos', 0, 'nave'), 'DSV');
      await db1.close();

      final db2 = await SqlitePersistence.open(path, factory: databaseFactoryFfi);
      SurveyStore.reset();
      final store2 = await SurveyStore.init(db2, FileStore(dir));
      expect(store2.projects.single.code, 'REY01202');
      final v2 = store2.latestVisit(proj.id)!;
      expect(v2.started, isTrue);
      expect(v2.template, isNotNull, reason: 'la copia de la plantilla se guarda con la visita');
      expect(store2.answersOf(v2.id)['g_datos#0/nave'], 'DSV');
      expect(store2.templates, hasLength(1), reason: 'la plantilla inicial no se duplica');

      await db2.removeByParent(Tables.answers, v2.id);
      expect(await db2.load(Tables.answers), isEmpty);
      await db2.close();
    });
  });

  group('Marca de agua', () {
    test('imprime fecha y GPS sin cambiar el tamaño de la foto', () {
      final original = img.Image(width: 1200, height: 900)..clear(img.ColorRgb8(240, 240, 240));
      final stamped = img.decodeJpg(
        stampBytes(img.encodeJpg(original), watermarkText(DateTime(2026, 9, 24, 10, 42, 15), const GeoPoint(26.07346, -98.38151))),
      )!;
      expect(stamped.width, 1200);
      expect(stamped.height, 900);
      // La franja oscura queda en la esquina inferior izquierda; arriba sigue igual.
      final corner = stamped.getPixel(40, 880);
      final top = stamped.getPixel(40, 20);
      expect(corner.r, lessThan(top.r - 40));
      expect(top.r, greaterThan(220));
    });

    test('usa sólo caracteres que la fuente puede dibujar', () {
      final text = watermarkText(DateTime(2026, 9, 24, 8, 5, 3), null);
      expect(text, '24/09/2026 08:05:03  |  SIN GPS');
      for (final c in text.codeUnits) {
        expect(img.arial48.characters.containsKey(c), isTrue, reason: String.fromCharCode(c));
      }
    });
  });

  group('Exportación', () {
    test('slug quita acentos y caracteres especiales', () {
      expect(slug('Acometida, Medidor y Transformador'), 'ACOMETIDA_MEDIDOR_Y_TRANSFORMADOR');
      expect(slug('Tablero Principal'), 'TABLERO_PRINCIPAL');
      expect(slug('Nave Ñuñoa – Δ'), 'NAVE_NUNOA_D');
    });

    test('arma carpetas y nombres según las instrucciones y genera el ZIP', () async {
      final store = await initTestStore();
      final proj = await seedProject(store, start: true);
      final v = store.latestVisit(proj.id)!;
      final root = store.files.root;

      final recibo = File(p.join(root.path, 'mi recibo.pdf'))..writeAsStringSync('%PDF-1.4');
      await store.addDocument(proj.id, 'recibo_cfe', recibo, 'mi recibo.pdf');
      await store.addEvidence(
          visit: v, key: const AnswerKey('g_tablero', 0, 'cerrado'), kind: EvidenceKind.photo, file: _jpeg(root, 'a.jpg'));
      await store.addEvidence(
          visit: v, key: const AnswerKey('g_tablero', 0, 'cerrado'), kind: EvidenceKind.photo, file: _jpeg(root, 'b.jpg'));
      await store.addEvidence(
          visit: v, key: const AnswerKey('g_transformador', 0, 'placa'), kind: EvidenceKind.photo, file: _jpeg(root, 'c.jpg'));
      await store.setAnswer(v, const AnswerKey('g_tablero', 0, 'v_ff'), '480');

      final service = ExportService(store);
      final plan = service.plan(proj, now: DateTime(2026, 9, 24));
      final paths = plan.entries.map((e) => e.path).toList();

      expect(plan.zipName, 'TRUPER_NAVE_DSV_LEVANTAMIENTO_2026-09-24.zip');
      expect(plan.root, 'REY01202_NAVE_DSV');
      expect(paths, contains('01 Información del Sitio/RECIBO_CFE_NAVE_DSV.pdf'));
      expect(paths, contains('03 Fotografías/3.4 Tableros y Canalizaciones/Tablero Principal/TABLERO_PRINCIPAL_CERRADO_001.jpg'));
      expect(paths, contains('03 Fotografías/3.4 Tableros y Canalizaciones/Tablero Principal/TABLERO_PRINCIPAL_CERRADO_002.jpg'));
      expect(paths, contains('03 Fotografías/3.3 Acometida, Medidor y Transformador/TRANSFORMADOR_1_PLACA_001.jpg'));
      expect(paths, contains('05 Reporte de Levantamiento/MEDICIONES_REY01202.csv'));
      expect(paths, contains('05 Reporte de Levantamiento/EVIDENCIAS_REY01202.csv'));
      expect(paths.toSet().length, paths.length, reason: 'sin nombres duplicados');

      final out = Directory(p.join(root.path, 'out'));
      final zip = await service.writeZip(plan, out);
      final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
      final names = archive.files.map((f) => f.name).toList();
      expect(names, contains('REY01202_NAVE_DSV/06 CAD y Modelos 3D/'), reason: 'las carpetas vacías también van');
      expect(names, contains('REY01202_NAVE_DSV/01 Información del Sitio/RECIBO_CFE_NAVE_DSV.pdf'));
      final csv = archive.files.firstWhere((f) => f.name.endsWith('MEDICIONES_REY01202.csv'));
      expect(utf8.decode(csv.content), contains('Tablero Principal,Tensión fase-fase,480,V'));
    });
  });
}
