import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/shell/home_shell.dart';

import 'test_helpers.dart';

void main() {
  /// Botón central de la barra con el ícono indicado.
  Finder centerButton(IconData icon) =>
      find.byWidgetPredicate((w) => w is Icon && w.icon == icon && w.size == 25);

  /// Contador sobre el botón central.
  Finder badge(String text) => find.descendant(
      of: find.ancestor(of: centerButton(Icons.check_rounded), matching: find.byType(Stack)).first,
      matching: find.text(text));

  setUp(() => AppState.instance.setRole(UserRole.supervisor));

  testWidgets('La palomita del supervisor abre lo que tiene por aprobar', (tester) async {
    final store = await initTestStore();
    final first = await seedProject(store, start: true);
    final firstVisit = store.latestVisit(first.id)!;
    await store.finishVisit(firstVisit, const GeoPoint(26, -98));
    final second = await seedProject(store, start: true);
    await moveToClient(store, second, 'SPRINGS');
    second.name = 'Springs Window Fashions';
    await store.finishVisit(store.latestVisit(second.id)!, const GeoPoint(26, -98));
    await seedProject(store, start: true); // en curso: no cuenta

    await pumpOnPhone(tester, const HomeShell());
    expect(centerButton(Icons.add_rounded), findsNothing);
    expect(centerButton(Icons.check_rounded), findsOneWidget);
    expect(badge('2'), findsOneWidget, reason: 'contador de visitas por aprobar');

    await tester.tap(centerButton(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Por aprobar'), findsOneWidget);
    expect(find.text('2 visitas en 2 proyectos, la que más espera primero'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    final order = tester
        .widgetList<Text>(find.descendant(of: sheet, matching: find.byType(Text)))
        .map((t) => t.data)
        .where((d) => d == first.name || d == second.name)
        .toList();
    expect(order, [first.name, second.name], reason: 'la que más espera primero');
    expect(find.descendant(of: sheet, matching: find.text('Finalizada')), findsNWidgets(2));

    await store.approveVisit(firstVisit);
    await tester.pumpAndSettle();
    expect(find.text('1 visita en 1 proyecto, la que más espera primero'), findsOneWidget,
        reason: 'la lista se actualiza al aprobar');
    expect(find.descendant(of: sheet, matching: find.text(first.name)), findsNothing);
    expect(badge('1'), findsOneWidget, reason: 'el contador baja');
  });

  testWidgets('Sin visitas finalizadas no hay contador y la hoja lo indica', (tester) async {
    final store = await initTestStore();
    await seedProject(store, start: true);

    await pumpOnPhone(tester, const HomeShell());
    expect(badge('0'), findsNothing);
    await tester.tap(centerButton(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Nada por aprobar'), findsOneWidget);
  });
}
