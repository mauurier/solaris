import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/core/services/video_compression.dart';
import 'package:proyecto_app/features/capture/evidence_actions.dart';

import 'test_helpers.dart';

/// Compresor que espera a que la prueba diga cómo termina.
class FakeCompressor implements VideoCompressor {
  final done = Completer<File?>();
  void Function(double)? progress;

  @override
  Future<File?> compress(File input, {void Function(double progress)? onProgress}) {
    progress = onProgress;
    return done.future;
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('solaris_video_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<Future<File>> start(WidgetTester tester, FakeCompressor fake) async {
    videoCompressor = fake;
    late Future<File> result;
    await pumpOnPhone(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => result = EvidenceActions.compressVideo(context, File('${dir.path}/original.mp4')),
            child: const Text('grabar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('grabar'));
    await tester.pump();
    return result;
  }

  testWidgets('muestra el avance y guarda el video comprimido', (tester) async {
    final fake = FakeCompressor();
    final result = await start(tester, fake);
    expect(find.text('Comprimiendo video'), findsOneWidget);

    fake.progress!(0.42);
    await tester.pump();
    expect(find.text('42 %'), findsOneWidget);

    final compressed = File('${dir.path}/compressed.mp4');
    fake.done.complete(compressed);
    await tester.pumpAndSettle();
    expect((await result).path, compressed.path);
    expect(find.text('Comprimiendo video'), findsNothing);
  });

  testWidgets('si no se puede comprimir guarda el original', (tester) async {
    final fake = FakeCompressor();
    final result = await start(tester, fake);
    fake.done.complete(null);
    await tester.pumpAndSettle();
    expect((await result).path, endsWith('original.mp4'));
    expect(find.text('Comprimiendo video'), findsNothing);
  });
}
