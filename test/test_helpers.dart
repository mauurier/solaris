import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/theme/app_theme.dart';
import 'package:proyecto_app/data/storage/file_store.dart';
import 'package:proyecto_app/data/storage/persistence.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/data/survey_store.dart';

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

/// Store en memoria con archivos en una carpeta temporal: las pruebas no
/// tocan SQLite ni la carpeta real de la app.
Future<SurveyStore> initTestStore() async {
  SurveyStore.reset();
  final dir = Directory.systemTemp.createTempSync('solaris_test_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return SurveyStore.init(MemoryPersistence(), FileStore(dir));
}

/// Proyecto de ejemplo con su primera visita asignada a Juan Pérez.
Future<SurveyProject> seedProject(SurveyStore store, {bool start = false}) async {
  final p = await store.createProject(
    code: 'REY01202',
    name: 'PROLOGIS Reynosa DSV',
    client: 'TRUPER',
    site: 'Nave DSV',
    address: 'Parque Colonial, Reynosa',
    coords: const GeoPoint(26.073459, -98.381511),
    scheduledAt: DateTime(2026, 9, 25),
    supervisor: 'Laura Méndez',
    technicians: ['Juan Pérez'],
    template: store.templates.first,
    type: 'Viabilidad FV',
  );
  if (start) await store.startVisit(store.latestVisit(p.id)!, const GeoPoint(26.07, -98.38));
  return p;
}

/// Monta [page] empujándola sobre una ruta base, para que `Navigator.pop`
/// de la página funcione como en la app.
Future<void> pumpPushed(WidgetTester tester, Widget page) async {
  await pumpOnPhone(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}
