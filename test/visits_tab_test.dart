import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/widgets/ui.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';
import 'package:proyecto_app/features/visits/new_visit_screen.dart';

import 'test_helpers.dart';

/// Chip del filtro de estado (no la pastilla de una visita con el mismo texto).
Finder chip(String label) => find.descendant(of: find.byType(FilterChips), matching: find.text(label));

void main() {
  setUp(() => AppState.instance.setRole(UserRole.admin));

  testWidgets('El admin filtra y busca visitas', (tester) async {
    final store = await initTestStore();
    final running = await seedProject(store, start: true); // en curso, Juan Pérez
    final waiting = await seedProject(store);
    await moveToClient(store, waiting, 'SPRINGS');
    waiting.name = 'Springs Window Fashions';
    await store.createVisit(waiting, technicianId: uid('Diego Salas'), motiveId: motiveId(store, 'Mediciones adicionales'));

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    expect(find.text('Nueva visita'), findsOneWidget, reason: 'botón destacado');

    await tester.tap(chip('Por iniciar'));
    await tester.pumpAndSettle();
    expect(find.text(running.name), findsNothing);
    expect(find.text(waiting.name), findsWidgets);

    await tester.tap(chip('En curso'));
    await tester.pumpAndSettle();
    expect(find.text(running.name), findsOneWidget);
    expect(find.text(waiting.name), findsNothing);

    await tester.tap(chip('Todas'));
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

  testWidgets('El supervisor no tiene botón de nueva visita ni filtro de pendientes', (tester) async {
    await initTestStore();
    AppState.instance.setRole(UserRole.supervisor);
    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    expect(find.text('Nueva visita'), findsNothing);
    expect(find.text('Con pendientes'), findsNothing);
  });

  testWidgets('El técnico ve sus visitas por estado y filtra las aprobadas', (tester) async {
    final store = await initTestStore();
    final approvedProj = await seedProject(store, start: true);
    final approved = store.latestVisit(approvedProj.id)!;
    await store.finishVisit(approved, const GeoPoint(26, -98));
    await store.approveVisit(approved);
    final waiting = await seedProject(store);
    waiting.name = 'Springs Window Fashions';
    final other = await seedProject(store);
    other.name = 'Visita de otro técnico';
    await store.createVisit(other, technicianId: uid('Diego Salas'), motiveId: motiveId(store, 'Mediciones adicionales'));
    store.visitsOf(other.id).firstWhere((v) => v.technician == 'Juan Pérez').technicianId = uid('Ana Torres');
    AppState.instance.setRole(UserRole.tecnico); // Juan Pérez

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    expect(find.text('APROBADAS · 1'), findsOneWidget);
    expect(find.text('POR INICIAR · 1'), findsOneWidget);
    expect(find.text('Visita de otro técnico'), findsNothing, reason: 'sólo sus visitas');
    expect(find.text('Con pendientes'), findsNothing, reason: 'filtros del técnico');
    expect(find.text('Nueva visita'), findsNothing);

    await tester.dragUntilVisible(chip('Aprobadas'), find.byType(FilterChips), const Offset(-150, 0));
    await tester.pumpAndSettle(); // un toque durante el desplazamiento sólo lo detiene
    await tester.tap(chip('Aprobadas'));
    await tester.pumpAndSettle();
    expect(find.text(approvedProj.name), findsOneWidget);
    expect(find.text('Springs Window Fashions'), findsNothing);
    expect(find.text('Aprobada'), findsOneWidget, reason: 'pastilla de estado');
  });

  testWidgets('El supervisor ve todas las visitas y filtra por técnico, fecha y correcciones', (tester) async {
    final store = await initTestStore();
    final today = await seedProject(store, start: true); // Juan, inicia hoy
    today.name = 'Iniciada hoy';
    final scheduled = await seedProject(store); // Juan, programada 25 sep 2026
    scheduled.name = 'Programada antes';
    final diego = await seedProject(store);
    diego.name = 'Proyecto de Diego';
    await store.createVisit(diego, technicianId: uid('Diego Salas'), motiveId: motiveId(store, 'Mediciones adicionales'));
    store.visitsOf(diego.id).firstWhere((v) => v.technician == 'Juan Pérez').technicianId = uid('Diego Salas');
    final reopened = await seedProject(store, start: true);
    reopened.name = 'Reabierta';
    final rv = store.latestVisit(reopened.id)!;
    await store.finishVisit(rv, const GeoPoint(26, -98));
    await store.reopenVisit(rv);
    AppState.instance.setRole(UserRole.supervisor);

    await pumpOnPhone(tester, const HomeShell());
    HomeNav.openVisits();
    await tester.pumpAndSettle();
    final names = ['Iniciada hoy', 'Programada antes', 'Proyecto de Diego', 'Reabierta'];
    Future<List<String>> visible() async {
      final list = find.byType(Scrollable).last;
      await tester.drag(list, const Offset(0, 600)); // regresa arriba
      await tester.pumpAndSettle();
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        seen.addAll(names.where((n) => find.text(n).evaluate().isNotEmpty));
        await tester.drag(list, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      return seen.toList()..sort();
    }

    expect(await visible(), [...names]..sort(), reason: 'todas las visitas de todos los proyectos');
    expect(find.text('Nueva visita'), findsNothing);

    await tester.tap(find.text('Todos los técnicos'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Diego Salas')));
    await tester.pumpAndSettle();
    expect(await visible(), ['Proyecto de Diego']);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cualquier fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(await visible(), ['Iniciada hoy', 'Reabierta']);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    final corrections = chip('Con correcciones');
    await tester.dragUntilVisible(corrections, find.byType(FilterChips), const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(corrections);
    await tester.pumpAndSettle();
    expect(await visible(), ['Reabierta']);

    await tester.dragUntilVisible(chip('Todas'), find.byType(FilterChips), const Offset(150, 0));
    await tester.pumpAndSettle();
    await tester.tap(chip('Todas'));
    await tester.enterText(find.byType(TextField), 'programada');
    await tester.pumpAndSettle();
    expect(await visible(), ['Programada antes'], reason: 'buscador');
  });
}

