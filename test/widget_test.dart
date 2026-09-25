import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/main.dart';

import 'test_helpers.dart';

/// El font de pruebas ("Ahem") dibuja cada carácter como un cuadro del tamaño
/// completo de la fuente, por lo que los textos miden 2–3 veces más que en el
/// dispositivo. Los desbordamientos horizontales que provoca no son reales, así
/// que se filtran para que el smoke test detecte errores de verdad.
void _ignoreTestFontOverflows() {
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> _pumpApp(WidgetTester tester) async {
  _ignoreTestFontOverflows();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SolarisApp());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => AppState.instance.setRole(UserRole.tecnico));

  testWidgets('La pantalla de acceso se muestra al iniciar', (tester) async {
    await initTestStore();
    await _pumpApp(tester);

    expect(find.text('SOLARIS'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Sin proyectos, el técnico ve que no tiene visitas', (tester) async {
    await initTestStore();
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hola,'), findsOneWidget);
    expect(find.text('Sin visitas pendientes'), findsOneWidget);
  });

  testWidgets('El flujo de levantamiento abre sus secciones', (tester) async {
    final store = await initTestStore();
    await seedProject(store, start: true);
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VISITA EN CURSO'));
    await tester.pumpAndSettle();
    expect(find.text('LEVANTAMIENTO'), findsOneWidget);

    await tester.tap(find.text('Subestación'));
    await tester.pumpAndSettle();
    expect(find.text('2. Subestación'), findsOneWidget);
    expect(find.text('Transformador 1'), findsOneWidget);
  });

  testWidgets('La validación bloquea el cierre con pendientes obligatorios', (tester) async {
    final store = await initTestStore();
    await seedProject(store, start: true);
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VISITA EN CURSO'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validar y finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no se puede cerrar'), findsOneWidget);
    expect(find.textContaining('PENDIENTES OBLIGATORIOS'), findsOneWidget);
  });
}
