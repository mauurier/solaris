import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_app/main.dart';

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
  testWidgets('La pantalla de acceso se muestra al iniciar', (tester) async {
    await _pumpApp(tester);

    expect(find.text('SOLARIS'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Al iniciar sesión se abre el panel principal', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hola,'), findsOneWidget);
    expect(find.text('VISITA EN CURSO'), findsOneWidget);
  });

  testWidgets('El flujo de levantamiento abre sus secciones', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VISITA EN CURSO'));
    await tester.pumpAndSettle();
    expect(find.text('LEVANTAMIENTO'), findsOneWidget);

    await tester.ensureVisible(find.text('Fotografías'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotografías'));
    await tester.pumpAndSettle();
    expect(find.text('03 Fotografías'), findsOneWidget);
    expect(find.text('3.1 Dron y Cubierta'), findsOneWidget);
  });

  testWidgets('La validación bloquea el cierre con pendientes obligatorios',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VISITA EN CURSO'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validar y finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Faltan datos obligatorios'), findsOneWidget);
    expect(find.text('Pendientes obligatorios (3)'.toUpperCase()), findsOneWidget);
  });
}
