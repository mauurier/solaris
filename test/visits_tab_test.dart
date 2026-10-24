import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/visits/new_visit_screen.dart';

import 'test_helpers.dart';

void main() {
  setUp(() => AppState.instance.setRole(UserRole.admin));

  testWidgets('El admin filtra y busca visitas', (tester) async {
    final store = await initTestStore();
    final running = await seedProject(store, start: true); // en curso, Juan Pérez
    final waiting = await seedProject(store);
    waiting
      ..client = 'SPRINGS'
      ..name = 'Springs Window Fashions';
    await store.createVisit(waiting, technician: 'Diego Salas', motive: 'Mediciones adicionales');

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    expect(find.text('Nueva visita'), findsOneWidget, reason: 'botón destacado');

    await tester.tap(find.text('Por iniciar').last);
    await tester.pumpAndSettle();
    expect(find.text(running.name), findsNothing);
    expect(find.text(waiting.name), findsWidgets);

    await tester.tap(find.text('En curso').last);
    await tester.pumpAndSettle();
    expect(find.text(running.name), findsOneWidget);
    expect(find.text(waiting.name), findsNothing);

    await tester.tap(find.text('Todas'));
    await tester.enterText(find.byType(TextField), 'diego');
    await tester.pumpAndSettle();
    expect(find.text(waiting.name), findsOneWidget, reason: 'busca por técnico');
    expect(find.text(running.name), findsNothing);

    await tester.enterText(find.byType(TextField), 'nada que coincida');
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);
  });

  testWidgets('El botón Nueva visita pide el proyecto y abre su alta', (tester) async {
    final store = await initTestStore();
    final proj = await seedProject(store);

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva visita'));
    await tester.pumpAndSettle();
    expect(find.text('Elige el proyecto al que pertenece la visita'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing, reason: 'no hay menú al que regresar');

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(proj.name)));
    await tester.pumpAndSettle();
    expect(find.byType(NewVisitScreen), findsOneWidget);
  });

  testWidgets('La visita nueva puede usar otra plantilla y el admin crea motivos', (tester) async {
    final store = await initTestStore();
    final proj = await seedProject(store);
    final other = await store.duplicateTemplate(store.templates.first);

    await pumpPushed(tester, NewVisitScreen(project: proj));
    expect(find.text('+ Nuevo motivo'), findsOneWidget);
    expect(find.textContaining('la del proyecto'), findsOneWidget);

    await tester.scrollUntilVisible(find.text(other.name), 150, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(other.name));
    await tester.pump();
    await tester.tap(find.text('Crear visita'));
    await tester.pumpAndSettle();
    expect(store.visitsOf(proj.id).where((v) => v.templateId == other.id), hasLength(1));
  });

  testWidgets('Supervisor y técnico no tienen buscador ni botón en Visitas', (tester) async {
    await initTestStore();
    AppState.instance.setRole(UserRole.supervisor);
    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    expect(find.text('Nueva visita'), findsNothing);
    expect(find.text('Con pendientes'), findsNothing);
  });
}
