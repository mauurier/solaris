import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/services/video_processing.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/capture/evidence_actions.dart';

import 'test_helpers.dart';

/// Procesador que espera a que la prueba diga cómo termina y guarda lo que
/// le pidieron imprimir.
class FakeProcessor implements VideoProcessor {
  final done = Completer<File?>();
  void Function(double)? progress;
  List<String>? lines;
  GeoPoint? point;

  @override
  Future<File?> process(File input,
      {required List<String> lines, GeoPoint? point, void Function(double progress)? onProgress}) {
    this.lines = lines;
    this.point = point;
    progress = onProgress;
    return done.future;
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('solaris_video_'));
  tearDown(() => dir.deleteSync(recursive: true));

  const point = GeoPoint(25.68661, -100.31611);

  Future<Future<File>> start(WidgetTester tester, FakeProcessor fake) async {
    videoProcessor = fake;
    late Future<File> result;
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => result = EvidenceActions.processVideo(context, File('${dir.path}/original.mp4'),
                at: DateTime(2026, 11, 7, 14, 32, 5), point: point),
            child: const Text('grabar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('grabar'));
    await tester.pump();
    return result;
  }

  testWidgets('muestra el avance y guarda el video con la marca de agua', (tester) async {
    final fake = FakeProcessor();
    final result = await start(tester, fake);
    expect(find.text('Preparando video'), findsOneWidget);
    expect(fake.lines, ['07/11/2026 14:32:05  |  25.68661, -100.31611', 'maps.google.com/?q=25.68661,-100.31611'],
        reason: 'la misma marca que las fotos, con el enlace de Maps');
    expect(fake.point, point);

    fake.progress!(0.42);
    await tester.pump();
    expect(find.text('42 %'), findsOneWidget);

    final processed = File('${dir.path}/processed.mp4');
    fake.done.complete(processed);
    await tester.pumpAndSettle();
    expect((await result).path, processed.path);
    expect(find.text('Preparando video'), findsNothing);
  });

  testWidgets('si no se puede procesar guarda el original', (tester) async {
    final fake = FakeProcessor();
    final result = await start(tester, fake);
    fake.done.complete(null);
    await tester.pumpAndSettle();
    expect((await result).path, endsWith('original.mp4'));
    expect(find.text('Preparando video'), findsNothing);
  });
}
