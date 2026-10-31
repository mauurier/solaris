import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';

import 'test_helpers.dart';

void main() {
  /// El + central de la barra de navegación.
  final navPlus = find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.add_rounded && w.size == 25);

  setUp(() => AppState.instance.setRole(UserRole.tecnico)); // Juan Pérez

  testWidgets('Con dos visitas en curso, el + pide elegir la visita primero', (tester) async {
    final store = await initTestStore();
    final first = await seedProject(store, start: true);
    final second = await seedProject(store, start: true);
    second.name = 'Springs Window Fashions';
    await store.markProjectOpened(first.id, uid('Juan Pérez')); // la última abierta va primero

    await pumpOnPhone(tester, const HomeShell());
    await tester.tap(navPlus);
    await tester.pumpAndSettle();
    expect(find.text('Tienes 2 visitas en curso: elige en cuál capturar'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    final names = tester
        .widgetList<Text>(find.descendant(of: sheet, matching: find.byType(Text)))
        .map((t) => t.data)
        .where((d) => d == first.name || d == second.name)
        .toList();
    expect(names, [first.name, second.name], reason: 'la última abierta primero');

    await tester.tap(find.descendant(of: sheet, matching: find.text(second.name)));
    await tester.pumpAndSettle();
    expect(find.textContaining('${second.name} · VIS-001 ·'), findsOneWidget, reason: 'pendientes de la elegida');
    expect(find.textContaining('elige en cuál capturar'), findsNothing);
    expect(store.activeVisitFor(uid('Juan Pérez'))!.projectId, second.id, reason: 'queda como su visita en curso');
  });

  testWidgets('Con una sola visita en curso, el + va directo a lo pendiente', (tester) async {
    final store = await initTestStore();
    final proj = await seedProject(store, start: true);

    await pumpOnPhone(tester, const HomeShell());
    await tester.tap(navPlus);
    await tester.pumpAndSettle();
    expect(find.textContaining('elige en cuál capturar'), findsNothing);
    expect(find.textContaining('${proj.name} · VIS-001 ·'), findsOneWidget);
  });
}
