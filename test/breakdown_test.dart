import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:proyecto_app/data/mock_data.dart';
import 'package:proyecto_app/data/models.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/dashboard/breakdown_screen.dart';

import 'test_helpers.dart';

void main() {
  setUp(() => AppState.instance.setRole(UserRole.admin));

  testWidgets('Evidencias por proyecto muestra la gráfica del proyecto elegido', (tester) async {
    final store = await initTestStore();
    final withPhotos = await seedProject(store, start: true);
    final empty = await seedProject(store, start: true);
    empty.name = 'Proyecto sin fotos';

    final v = store.latestVisit(withPhotos.id)!;
    final section = store.templateFor(v).sections.firstWhere((s) => s.groups.any((g) => g.id == 'g_tablero'));
    final dir = Directory.systemTemp.createTempSync('solaris_breakdown_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.runAsync(() async {
      for (final name in ['a.jpg', 'b.jpg']) {
        final file = File(p.join(dir.path, name))
          ..writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 30)));
        await store.addEvidence(
            visit: v, key: const AnswerKey('g_tablero', 0, 'cerrado'), kind: EvidenceKind.photo, file: file);
      }
    });

    await pumpPushed(
      tester,
      ProjectBreakdownScreen(kind: BreakdownKind.evidences, projects: [withPhotos, empty]),
    );
    expect(find.text('2 evidencias'), findsOneWidget);
    expect(find.text(section.title), findsOneWidget, reason: 'desglose por sección de la plantilla');
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('POR PROYECTO'), 200, scrollable: list);
    expect(find.text('POR PROYECTO'), findsOneWidget);

    await tester.tap(find.text('Proyecto sin fotos').first);
    await tester.pumpAndSettle();
    expect(find.text('0 evidencias'), findsOneWidget);
    expect(find.text('Sin registros'), findsOneWidget);
    expect(find.text('Abrir proyecto'), findsOneWidget);
    expect(find.text('POR PROYECTO', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('2 evidencias'), findsOneWidget);
  });
}
