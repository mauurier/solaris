import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/visits/new_visit_screen.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('El admin ve los proyectos por cliente y el resumen de visitas', (tester) async {
    final store = await initTestStore();
    final truper = await seedProject(store, start: true); // TRUPER, visita en captura
    final springs = await seedProject(store);
    springs
      ..client = 'SPRINGS'
      ..name = 'Springs Window Fashions';
    await store.createVisit(springs, technician: 'Diego Salas', motive: 'Mediciones adicionales');
    await store.finishVisit(store.latestVisit(truper.id)!, const GeoPoint(26, -98));
    AppState.instance.setRole(UserRole.admin);

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openProjects();
    await tester.pumpAndSettle();

    expect(find.text('Nuevo proyecto'), findsOneWidget, reason: 'botón destacado para crear');
    expect(find.text('SPRINGS'), findsOneWidget);
    expect(find.text('1 proyecto · 2 visitas'), findsOneWidget);
    expect(find.text('TRUPER'), findsOneWidget);
    expect(find.text('1 proyecto · 1 visita'), findsOneWidget);

    await tester.tap(find.text('Springs Window Fashions'));
    await tester.pumpAndSettle();
    expect(find.text('SPRINGS · 2 visitas'), findsOneWidget);
    expect(find.text('Por iniciar · 2'), findsOneWidget, reason: 'cantidad por estado');
    expect(find.text('Abrir proyecto'), findsOneWidget);
  });

  testWidgets('El filtro por estado sigue funcionando agrupado por cliente', (tester) async {
    final store = await initTestStore();
    final done = await seedProject(store, start: true);
    await store.finishVisit(store.latestVisit(done.id)!, const GeoPoint(26, -98));
    final other = await seedProject(store, start: true);
    other.client = 'SPRINGS';
    AppState.instance.setRole(UserRole.admin);

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openProjects(filter: 'Por sincronizar');
    await tester.pumpAndSettle();
    expect(find.text('TRUPER'), findsOneWidget);
    expect(find.text('SPRINGS'), findsNothing, reason: 'su proyecto sigue en captura');
  });

  /// El + central de la barra de navegación.
  final navPlus = find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.add_rounded && w.size == 25);

  testWidgets('El + del admin crea una visita para un proyecto existente', (tester) async {
    final store = await initTestStore();
    final proj = await seedProject(store);
    AppState.instance.setRole(UserRole.admin);

    await pumpOnPhone(tester, const HomeShell());
    await tester.tap(navPlus);
    await tester.pumpAndSettle();
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Nuevo proyecto'), findsOneWidget);

    await tester.tap(find.text('Nueva visita'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'reynosa');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(proj.name)));
    await tester.pumpAndSettle();
    expect(find.byType(NewVisitScreen), findsOneWidget);
    expect(find.text('Crear'), findsNothing, reason: 'la hoja se cierra');
  });

  testWidgets('El + del técnico sigue abriendo la captura rápida', (tester) async {
    await initTestStore();
    AppState.instance.setRole(UserRole.tecnico);
    await pumpOnPhone(tester, const HomeShell());
    await tester.tap(navPlus);
    await tester.pumpAndSettle();
    expect(find.text('Captura rápida'), findsOneWidget);
    expect(find.text('Crear'), findsNothing);
  });

  testWidgets('El técnico ve sus proyectos por cliente y sólo sus visitas', (tester) async {
    final store = await initTestStore();
    final shared = await seedProject(store, start: true); // TRUPER, visita de Juan en captura
    await store.createVisit(shared, technician: 'Diego Salas', motive: 'Mediciones adicionales');
    final notMine = await seedProject(store);
    notMine
      ..client = 'SPRINGS'
      ..technicians.clear();
    AppState.instance.setRole(UserRole.tecnico); // Juan Pérez

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openProjects();
    await tester.pumpAndSettle();
    expect(find.text('TRUPER'), findsOneWidget);
    expect(find.text('1 proyecto · 1 visita'), findsOneWidget, reason: 'no cuenta la visita de Diego');
    expect(find.text('SPRINGS'), findsNothing, reason: 'no está asignado a Juan');
    expect(find.text('Nuevo proyecto'), findsNothing, reason: 'el técnico no crea proyectos');

    await tester.tap(find.text(shared.name).first);
    await tester.pumpAndSettle();
    expect(find.text('TRUPER · 1 visita asignada a ti'), findsOneWidget);
    expect(find.text('En curso · 1'), findsOneWidget);
    expect(find.text('Abrir proyecto'), findsOneWidget);
  });

  testWidgets('El técnico filtra sus proyectos por estado', (tester) async {
    final store = await initTestStore();
    await seedProject(store, start: true); // en captura
    final waiting = await seedProject(store); // asignado
    waiting.client = 'SPRINGS';
    AppState.instance.setRole(UserRole.tecnico);

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openProjects(filter: 'Asignados');
    await tester.pumpAndSettle();
    expect(find.text('SPRINGS'), findsOneWidget);
    expect(find.text('TRUPER'), findsNothing);
  });
}

