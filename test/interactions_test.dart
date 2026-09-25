import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/data/survey_store.dart';
import 'package:proyecto_app/features/admin/template_editor_screen.dart';
import 'package:proyecto_app/features/measurements/measurement_form_screen.dart';
import 'package:proyecto_app/features/projects/new_project_screen.dart';
import 'package:proyecto_app/features/projects/project_detail_screen.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/stats/stats_screen.dart';
import 'package:proyecto_app/features/visits/section_screen.dart';
import 'package:proyecto_app/features/visits/validation_screen.dart';
import 'package:proyecto_app/features/visits/visit_screen.dart';

import 'test_helpers.dart';

void main() {
  late SurveyStore store;

  setUp(() async {
    AppState.instance.setRole(UserRole.tecnico);
    store = await initTestStore();
  });

  testWidgets('El panel se adapta a cada rol', (tester) async {
    await seedProject(store, start: true);
    for (final role in UserRole.values) {
      AppState.instance.setRole(role);
      await pumpOnPhone(tester, const HomeShell());
      expectNoRenderErrors(tester);
      expect(find.textContaining('Hola,'), findsOneWidget);
    }
    AppState.instance.setRole(UserRole.tecnico);
    await pumpOnPhone(tester, const HomeShell());
    expect(find.text('VISITA EN CURSO'), findsOneWidget);
  });

  testWidgets('El alta de proyecto valida cada paso y crea la visita', (tester) async {
    AppState.instance.setRole(UserRole.supervisor);
    await pumpPushed(tester, const NewProjectScreen());

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Escribe la clave del proyecto'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'rey00607');
    await tester.enterText(find.byType(TextField).at(1), 'Springs Window Fashions');
    await tester.tap(find.text('TRUPER'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Nave Springs');
    await tester.enterText(find.byType(TextField).at(2), 'no son coordenadas');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle(); // el aviso anterior sale y entra el nuevo
    expect(find.textContaining('Coordenadas inválidas'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), '26.0734, -98.3815');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Asigna al menos un técnico'), findsOneWidget);
    await tester.tap(find.text('Juan Pérez'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Levantamiento eléctrico FV'), findsOneWidget);
    expect(find.text('Recibo de luz CFE'), findsOneWidget);
    await tester.tap(find.text('Crear proyecto'));
    await tester.pumpAndSettle();

    final p = store.projects.single;
    expect(p.code, 'REY00607');
    expect(p.coords!.lat, closeTo(26.0734, 1e-6));
    expect(store.latestVisit(p.id)!.technician, 'Juan Pérez');
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('Iniciar la visita registra la hora aunque no haya GPS', (tester) async {
    final p = await seedProject(store);
    final v = store.latestVisit(p.id)!;
    await pumpOnPhone(tester, VisitScreen(visit: v));

    await tester.tap(find.text('Iniciar visita'));
    await tester.pump(const Duration(seconds: 40)); // tope del GPS en pruebas
    await tester.pumpAndSettle();

    expect(v.started, isTrue);
    expect(v.template, isNotNull);
    expect(find.text('LEVANTAMIENTO'), findsOneWidget);
    expect(find.text('Subestación'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('Los bloques repetibles agregan instancias y los condicionales aparecen', (tester) async {
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    await pumpOnPhone(tester, SectionScreen(visit: v, sectionIndex: 1, editable: true));

    expect(find.text('Transformador 1'), findsOneWidget);
    await tester.tap(find.text('Agregar transformador'));
    await tester.pumpAndSettle();
    expect(find.text('Transformador 2'), findsOneWidget);
    expect(v.instances['g_transformador'], 2);

    expect(find.text('Diagrama unifilar actual'), findsNothing);
    final card = find.byKey(ValueKey('${v.id}-g_cuarto#0/unifilar'));
    await tester.scrollUntilVisible(card, 400, scrollable: find.byType(Scrollable).first);
    final siButton = find.descendant(of: card, matching: find.text('Sí'));
    await tester.ensureVisible(siButton); // queda arriba, lejos de la barra inferior
    await tester.pumpAndSettle();
    await tester.tap(siButton);
    await tester.pumpAndSettle();
    expect(store.answersOf(v.id)['g_cuarto#0/unifilar'], 'Sí');
    expect(find.text('Diagrama unifilar actual'), findsOneWidget);
    expectNoRenderErrors(tester);
  });

  testWidgets('Las respuestas de texto se guardan solas', (tester) async {
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    await pumpOnPhone(tester, SectionScreen(visit: v, sectionIndex: 0, editable: true));

    await tester.enterText(find.byType(TextField).first, 'DSV');
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.answersOf(v.id)['g_datos#0/nave'], 'DSV');
  });

  testWidgets('La validación bloquea el cierre y el supervisor justifica', (tester) async {
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    final blocking = store.engineFor(v).blockingCount;

    await pumpOnPhone(tester, ValidationScreen(visit: v));
    expect(find.text('Aún no se puede cerrar'), findsOneWidget);
    expect(find.text('Justificar'), findsNothing, reason: 'el técnico no justifica');

    AppState.instance.setRole(UserRole.supervisor);
    await pumpOnPhone(tester, ValidationScreen(visit: v));
    await tester.tap(find.text('Justificar').first);
    await tester.pumpAndSettle();
    expect(find.text('Justificar pendiente'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Sin acceso al área');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Justificar'));
    await tester.pumpAndSettle();

    expect(store.engineFor(v).blockingCount, blocking - 1);
    expect(v.justifications.values.single, contains('Sin acceso al área'));
    expectNoRenderErrors(tester);
  });

  testWidgets('Un levantamiento sin pendientes se puede finalizar', (tester) async {
    final p = await seedProject(store, start: true);
    final v = store.latestVisit(p.id)!;
    for (final pend in store.engineFor(v).pendings().where((x) => x.question.question.required)) {
      await store.justify(v, pend.question.key, 'Prueba');
    }
    await pumpPushed(tester, ValidationScreen(visit: v));
    await tester.tap(find.text('Finalizar visita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();

    expect(v.finished, isTrue);
    expect(p.status, ProjectStatus.pendienteSync);
  });

  testWidgets('El editor guarda la plantilla como versión nueva', (tester) async {
    AppState.instance.setRole(UserRole.admin);
    await pumpPushed(tester, TemplateEditorScreen(template: store.templates.first));

    expect(find.text('Guardar como v1.1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Levantamiento eléctrico FV (Truper)');
    await tester.pump();
    await tester.tap(find.text('Guardar como v1.1'));
    await tester.pumpAndSettle();

    expect(store.templates.first.name, 'Levantamiento eléctrico FV (Truper)');
    expect(store.templates.first.version, 'v1.1');
    expectNoRenderErrors(tester);
  });

  testWidgets('Las pestañas del proyecto se dibujan sin errores', (tester) async {
    final p = await seedProject(store, start: true);
    await store.setAnswer(store.latestVisit(p.id)!, const AnswerKey('g_datos', 0, 'nave'), 'DSV');
    await pumpOnPhone(tester, ProjectDetailScreen(project: p));
    for (final tab in ['Visitas', 'Documentos', 'Evidencia', 'Resumen']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });

  testWidgets('Las pestañas de estadísticas (vista previa) se dibujan', (tester) async {
    await pumpOnPhone(tester, const StatsScreen());
    for (final scope in ['Técnico', 'Proyecto', 'Empresa']) {
      await tester.tap(find.text(scope));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });

  testWidgets('El formulario de mediciones (vista previa) cambia de parámetro', (tester) async {
    await pumpOnPhone(tester, const MeasurementFormScreen());
    for (final family in ['Corriente', 'Otros', 'Tensión']) {
      await tester.tap(find.text(family));
      await tester.pumpAndSettle();
      expectNoRenderErrors(tester);
    }
  });
}
