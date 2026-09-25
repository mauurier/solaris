import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../data/survey/entities.dart';
import 'formatting.dart';

/// Texto que se imprime en la foto: fecha y hora, y coordenadas o "SIN GPS"
/// cuando no hubo ubicación. Sólo ASCII: la fuente de mapa de bits del
/// paquete `image` no trae acentos ni ñ.
String watermarkText(DateTime at, GeoPoint? point) =>
    '${fmtStamp(at)}  |  ${point == null ? 'SIN GPS' : point.label}';

/// Imprime la marca de agua en la esquina inferior izquierda de una foto JPEG
/// y la guarda en [outputPath]. Corre en un isolate para no congelar la UI:
/// decodificar una foto de 8–12 MP en Dart tarda un par de segundos.
Future<void> stampPhoto({
  required String inputPath,
  required String outputPath,
  required String text,
}) {
  return Isolate.run(() {
    final bytes = File(inputPath).readAsBytesSync();
    final out = stampBytes(bytes, text);
    File(outputPath).writeAsBytesSync(out, flush: true);
  });
}

/// Versión síncrona (también usada por las pruebas).
Uint8List stampBytes(Uint8List jpeg, String text) {
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) throw const FormatException('No se pudo leer la fotografía');
  // La cámara guarda la rotación en EXIF; se aplica antes de dibujar para que
  // la marca quede abajo en la foto tal como se ve.
  final photo = img.bakeOrientation(decoded);

  // El texto se dibuja con la fuente de 48 px en una franja pequeña y luego se
  // escala para que ocupe ~45 % del ancho, sin importar la resolución.
  final font = img.arial48;
  final textWidth = _measure(font, text);
  const pad = 18;
  final strip = img.Image(width: textWidth + pad * 2, height: font.lineHeight + pad, numChannels: 4)
    ..clear(img.ColorRgba8(0, 0, 0, 150));
  img.drawString(strip, text, font: font, x: pad, y: pad ~/ 2, color: img.ColorRgba8(255, 255, 255, 255));

  final targetWidth = (photo.width * 0.45).round().clamp(240, photo.width - 8);
  final scaled = img.copyResize(strip, width: targetWidth, interpolation: img.Interpolation.average);
  final margin = (photo.width * 0.015).round();
  img.compositeImage(photo, scaled, dstX: margin, dstY: photo.height - scaled.height - margin);

  return img.encodeJpg(photo, quality: 90);
}

int _measure(img.BitmapFont font, String text) {
  var w = 0;
  for (final c in text.codeUnits) {
    final ch = font.characters[c];
    w += ch?.xAdvance ?? font.base ~/ 2;
  }
  return w;
}
