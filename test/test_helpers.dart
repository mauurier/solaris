import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/theme/app_theme.dart';

/// Carga la tipografía real del sistema para que las medidas de texto
/// correspondan con las del dispositivo. El font de pruebas de Flutter dibuja
/// cada carácter como un cuadro del tamaño completo de la fuente y falsea
/// cualquier desbordamiento horizontal.
Future<void> loadRealFont() async {
  const path = '/System/Library/Fonts/SFNS.ttf';
  if (!File(path).existsSync()) return;
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  for (final family in ['Roboto', '.SF UI Text', '.SF UI Display']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// Monta [child] en un iPhone virtual de 390 × 844 pt con la fuente real.
Future<void> pumpOnPhone(WidgetTester tester, Widget child) async {
  await loadRealFont();
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: child,
      builder: (context, inner) => MediaQuery.withNoTextScaling(child: inner!),
    ),
  );
  await tester.pumpAndSettle();
}

/// Falla si la última interacción produjo un error de renderizado.
void expectNoRenderErrors(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
