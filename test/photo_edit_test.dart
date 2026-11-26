import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:proyecto_app/core/services/watermark.dart';
import 'package:proyecto_app/core/theme/app_theme.dart';
import 'package:proyecto_app/data/survey/entities.dart';
import 'package:proyecto_app/features/capture/photo_text_editor.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('solaris_edit_'));
  tearDown(() => dir.deleteSync(recursive: true));

  const point = GeoPoint(25.68661, -100.31611);

  testWidgets('el texto se dibuja en la foto a su tamaño real y conserva el GPS', (tester) async {
    final gray = img.Image(width: 800, height: 600)..clear(img.ColorRgb8(128, 128, 128));
    final source = File('${dir.path}/foto.jpg')
      ..writeAsBytesSync(stampBytes(img.encodeJpg(gray), watermarkLines(DateTime(2026, 11, 7), point), gps: point));

    late File out;
    await tester.runAsync(() async {
      out = await renderPhotoTexts(source, [
        PhotoText(text: 'ITM sin etiqueta', center: const Offset(0.5, 0.3), size: 0.08, color: Colors.white),
      ], into: dir);
    });

    final result = img.decodeJpg(out.readAsBytesSync())!;
    expect(result.width, 800);
    expect(result.height, 600);
    // El recuadro oscuro del texto queda a 30 % de alto, al centro; arriba a
    // la izquierda la foto sigue igual.
    expect(result.getPixel(400, 180).r, lessThan(100));
    expect(result.getPixel(20, 20).r, closeTo(128, 12));
    final gps = readExifGps(result.exif)!;
    expect(gps.lat, closeTo(point.lat, 1e-5));
    expect(gps.lng, closeTo(point.lng, 1e-5));
  });

  testWidgets('la medida se dibuja con flecha en los dos extremos', (tester) async {
    final gray = img.Image(width: 800, height: 600)..clear(img.ColorRgb8(128, 128, 128));
    final source = File('${dir.path}/foto.jpg')..writeAsBytesSync(img.encodeJpg(gray));

    late File out;
    await tester.runAsync(() async {
      out = await renderPhotoTexts(source, const [], lines: [
        PhotoLine(start: const Offset(0.2, 0.5), end: const Offset(0.8, 0.5), color: const Color(0xFFFFC24B)),
      ], into: dir);
    });

    final result = img.decodeJpg(out.readAsBytesSync())!;
    bool yellow(int x, int y) {
      final px = result.getPixel(x, y);
      return px.r > 200 && px.g > 150 && px.b < 120;
    }

    expect(yellow(400, 300), isTrue, reason: 'la línea al centro');
    // Las flechas son más anchas que la línea: a 5 px del eje sólo hay flecha.
    expect(yellow(178, 305), isTrue, reason: 'flecha del extremo izquierdo');
    expect(yellow(622, 305), isTrue, reason: 'flecha del extremo derecho');
    expect(yellow(400, 305), isFalse, reason: 'a media línea no hay flecha');
    expect(result.getPixel(400, 200).r, closeTo(128, 12), reason: 'fuera de la línea la foto sigue igual');
  });

  group('editor', () {
    late File source;

    /// Abre el editor con una foto de 800 × 600 y espera a que la lea.
    Future<PhotoTextEditorState> openEditor(WidgetTester tester) async {
      final gray = img.Image(width: 800, height: 600)..clear(img.ColorRgb8(128, 128, 128));
      source = File('${dir.path}/foto.jpg')..writeAsBytesSync(img.encodeJpg(gray));
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: PhotoTextEditor(source: source)));
        for (var i = 0; i < 50 && find.byKey(const ValueKey('editor-canvas')).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      expect(find.byKey(const ValueKey('editor-canvas')), findsOneWidget, reason: 'leyó el tamaño de la foto');
      return tester.state<PhotoTextEditorState>(find.byType(PhotoTextEditor));
    }

    Future<void> pinch(WidgetTester tester, Offset center, double from, double to) async {
      final a = await tester.startGesture(center - Offset(from / 2, 0));
      final b = await tester.startGesture(center + Offset(from / 2, 0));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        final step = (to - from) / 20;
        await a.moveBy(Offset(-step, 0));
        await b.moveBy(Offset(step, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    testWidgets('pellizcar con los dedos fuera del texto cambia su tamaño', (tester) async {
      final editor = await openEditor(tester);
      await tester.tap(find.text('Texto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ITM');
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      final text = editor.texts.single;
      expect(editor.selected, same(text));
      final before = text.size;

      // El texto está al centro; los dedos van arriba, lejos de él.
      final canvas = tester.getRect(find.byKey(const ValueKey('editor-canvas')));
      await pinch(tester, Offset(canvas.center.dx, canvas.top + 30), 80, 240);
      final bigger = text.size;
      expect(bigger, greaterThan(before * 1.5), reason: 'se agrandó');

      await pinch(tester, Offset(canvas.center.dx, canvas.bottom - 30), 240, 80);
      expect(text.size, lessThan(bigger / 1.5), reason: 'se achicó');
    });

    testWidgets('la medida se agrega y sus extremos se arrastran', (tester) async {
      final editor = await openEditor(tester);
      await tester.tap(find.text('Medida'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1.20 m');
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      final line = editor.lines.single;
      expect(line.label, '1.20 m');
      final end = line.end;

      final canvas = tester.getRect(find.byKey(const ValueKey('editor-canvas')));
      final startOnScreen = canvas.topLeft + Offset(line.start.dx * canvas.width, line.start.dy * canvas.height);
      await tester.dragFrom(startOnScreen, const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(line.start.dy, greaterThan(0.5), reason: 'el extremo bajó');
      expect(line.end, end, reason: 'el otro extremo no se movió');

      // Tocar la línea la edita; Borrar la quita.
      final mid = canvas.topLeft + Offset((line.start.dx + line.end.dx) / 2 * canvas.width,
          (line.start.dy + line.end.dy) / 2 * canvas.height);
      await tester.tapAt(mid);
      await tester.pumpAndSettle();
      expect(find.text('Editar medida'), findsOneWidget);
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      expect(editor.lines, isEmpty);
    });
  });

  test('una foto grande de la galería se reduce y lleva la marca', () async {
    final big = img.Image(width: 6000, height: 4000)..clear(img.ColorRgb8(240, 240, 240));
    final input = File('${dir.path}/galeria.jpg')..writeAsBytesSync(img.encodeJpg(big, quality: 60));
    final output = File('${dir.path}/marcada.jpg');

    await stampPhoto(
      inputPath: input.path,
      outputPath: output.path,
      lines: watermarkLines(DateTime(2026, 11, 7, 9), point),
      gps: point,
      maxSide: importMaxSide,
    );

    final result = img.decodeJpg(output.readAsBytesSync())!;
    expect(result.width, importMaxSide);
    expect(result.height, (4000 * importMaxSide / 6000).round());
    expect(result.getPixel(200, result.height - 150).r, lessThan(200), reason: 'franja de la marca abajo a la izquierda');
    expect(readExifGps(result.exif), isNotNull);
  });

  test('un archivo que no es imagen avisa en lugar de guardarse marcado', () async {
    final input = File('${dir.path}/no.jpg')..writeAsStringSync('no soy una foto');
    expect(
      () => stampPhoto(inputPath: input.path, outputPath: '${dir.path}/x.jpg', lines: const ['x']),
      throwsA(isA<FormatException>()),
    );
  });
}
