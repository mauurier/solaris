import 'dart:io';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:proyecto_app/core/services/watermark.dart';
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
