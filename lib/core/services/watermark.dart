import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../../data/survey/entities.dart';
import 'formatting.dart';

/// Renglones que se imprimen en la foto o el video: fecha y hora con las
/// coordenadas (o "SIN GPS"), y debajo el enlace de Google Maps de esas
/// mismas coordenadas. Sólo ASCII: la fuente de mapa de bits del paquete
/// `image` no trae acentos ni ñ.
List<String> watermarkLines(DateTime at, GeoPoint? point) => [
      '${fmtStamp(at)}  |  ${point == null ? 'SIN GPS' : point.label}',
      if (point != null) point.mapsText,
    ];

/// La marca en un solo texto, como se muestra en la app.
String watermarkText(DateTime at, GeoPoint? point) => watermarkLines(at, point).join('\n');

/// Lado mayor con el que se guardan las fotos importadas: una de 24–48 MP de
/// la galería no cabe en memoria al decodificarla y no hace falta tanta.
const importMaxSide = 4096;

/// Imprime la marca de agua en la esquina inferior izquierda de una foto y la
/// guarda como JPEG en [outputPath], con las coordenadas también en el EXIF
/// para que la galería o Google Fotos la ubiquen en el mapa.
///
/// Corre en un isolate para no congelar la UI: decodificar una foto de
/// 8–12 MP en Dart tarda un par de segundos. Si el paquete `image` no puede
/// leerla (HEIC de iPhone), la decodifica el motor de Flutter. Lanza
/// [FormatException] si nadie puede leerla.
Future<void> stampPhoto({
  required String inputPath,
  required String outputPath,
  required List<String> lines,
  GeoPoint? gps,
  int? maxSide,
}) async {
  final ok = await _stampInIsolate(inputPath, outputPath, lines, gps, maxSide);
  if (ok) return;
  final decoded = await decodeWithEngine(File(inputPath), maxSide: maxSide);
  if (decoded == null) throw const FormatException('No se pudo leer la fotografía');
  await _stampDecodedInIsolate(decoded, outputPath, lines, gps);
}

// Funciones sueltas a propósito: el cierre que viaja al isolate sólo lleva
// sus argumentos (ver `_shrinkFile` en report_service.dart).
Future<bool> _stampInIsolate(String input, String output, List<String> lines, GeoPoint? gps, int? maxSide) =>
    Isolate.run(() {
      final decoded = img.decodeImage(File(input).readAsBytesSync());
      if (decoded == null) return false;
      var photo = img.bakeOrientation(decoded);
      if (maxSide != null) photo = _fit(photo, maxSide);
      File(output).writeAsBytesSync(_stampAndEncode(photo, lines, gps), flush: true);
      return true;
    });

Future<void> _stampDecodedInIsolate(img.Image photo, String output, List<String> lines, GeoPoint? gps) =>
    Isolate.run(() => File(output).writeAsBytesSync(_stampAndEncode(photo, lines, gps), flush: true));

/// Versión síncrona (también usada por las pruebas).
Uint8List stampBytes(Uint8List jpeg, List<String> lines, {GeoPoint? gps}) {
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) throw const FormatException('No se pudo leer la fotografía');
  // La cámara guarda la rotación en EXIF; se aplica antes de dibujar para que
  // la marca quede abajo en la foto tal como se ve.
  return _stampAndEncode(img.bakeOrientation(decoded), lines, gps);
}

Uint8List _stampAndEncode(img.Image photo, List<String> lines, GeoPoint? gps) {
  drawWatermark(photo, lines);
  if (gps != null) setExifGps(photo.exif, gps);
  return img.encodeJpg(photo, quality: 90);
}

img.Image _fit(img.Image photo, int maxSide) {
  if (photo.width <= maxSide && photo.height <= maxSide) return photo;
  return photo.width >= photo.height
      ? img.copyResize(photo, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(photo, height: maxSide, interpolation: img.Interpolation.average);
}

/// Dibuja la franja con [lines] sobre [photo], que ya debe estar derecha.
void drawWatermark(img.Image photo, List<String> lines) {
  // El texto se dibuja con la fuente de 48 px en una franja pequeña y luego se
  // escala a una parte fija del ancho, sin importar la resolución. El video
  // usa la misma proporción (ios/Runner/VideoWatermark.swift, VideoWatermark.kt).
  final font = img.arial48;
  final textWidth = lines.map((l) => _measure(font, l)).fold(0, (a, b) => a > b ? a : b);
  const pad = 18;
  final strip = img.Image(
    width: textWidth + pad * 2,
    height: font.lineHeight * lines.length + pad,
    numChannels: 4,
  )..clear(img.ColorRgba8(0, 0, 0, 150));
  for (var i = 0; i < lines.length; i++) {
    // El enlace va en azul claro para que se lea como tal.
    final color = i == 0 ? img.ColorRgba8(255, 255, 255, 255) : img.ColorRgba8(150, 200, 255, 255);
    img.drawString(strip, lines[i], font: font, x: pad, y: pad ~/ 2 + font.lineHeight * i, color: color);
  }

  // En vertical la franja ocupa más del ancho para que el enlace se lea.
  final portrait = photo.height > photo.width;
  final share = lines.length > 1 ? (portrait ? 0.75 : 0.5) : (portrait ? 0.6 : 0.45);
  final targetWidth = (photo.width * share).round().clamp(240, photo.width - 8);
  final scaled = img.copyResize(strip, width: targetWidth, interpolation: img.Interpolation.average);
  final margin = (photo.width * 0.015).round();
  img.compositeImage(photo, scaled, dstX: margin, dstY: photo.height - scaled.height - margin);
}

/// Coordenadas en el EXIF como grados, minutos y segundos (lo que leen
/// Fotos, Google Fotos y los visores de mapas).
void setExifGps(img.ExifData exif, GeoPoint p) {
  // El paquete no exporta `Rational`; se arma la lista a partir de valores
  // de un solo elemento.
  img.IfdValueRational dms(double value) {
    final v = value.abs();
    final deg = v.floor();
    final minutes = (v - deg) * 60;
    final min = minutes.floor();
    final sec = ((minutes - min) * 60 * 10000).round();
    return img.IfdValueRational(deg, 1)
      ..value.add(img.IfdValueRational(min, 1).value.first)
      ..value.add(img.IfdValueRational(sec, 10000).value.first);
  }

  final gps = exif.gpsIfd;
  gps.data[0x0000] = img.IfdByteValue.list(Uint8List.fromList([2, 3, 0, 0]));
  gps.data[0x0001] = img.IfdValueAscii(p.lat < 0 ? 'S' : 'N');
  gps.data[0x0002] = dms(p.lat);
  gps.data[0x0003] = img.IfdValueAscii(p.lng < 0 ? 'W' : 'E');
  gps.data[0x0004] = dms(p.lng);
}

/// Lee las coordenadas del EXIF (para las pruebas y las fotos importadas).
GeoPoint? readExifGps(img.ExifData exif) {
  final gps = exif.gpsIfd;
  double? read(int tag, int refTag, String negative) {
    final v = gps.data[tag];
    if (v == null || v.length < 3) return null;
    final value = v.toDouble(0) + v.toDouble(1) / 60 + v.toDouble(2) / 3600;
    return gps.data[refTag]?.toString().trim() == negative ? -value : value;
  }

  final lat = read(0x0002, 0x0001, 'S');
  final lng = read(0x0004, 0x0003, 'W');
  return lat == null || lng == null ? null : GeoPoint(lat, lng);
}

/// Decodifica con el motor de Flutter (HEIC en iPhone, HEIF en Android) y
/// la reduce a [maxSide] sin cargarla completa. La orientación EXIF ya viene
/// aplicada. Nula si tampoco el motor la puede leer.
Future<img.Image?> decodeWithEngine(File file, {int? maxSide}) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
    final codec = await ui.instantiateImageCodecWithSize(buffer, getTargetSize: (w, h) {
      if (maxSide == null || (w <= maxSide && h <= maxSide)) return ui.TargetImageSize(width: w, height: h);
      return w >= h ? ui.TargetImageSize(width: maxSide) : ui.TargetImageSize(height: maxSide);
    });
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    codec.dispose();
    if (data == null) return null;
    return img.Image.fromBytes(
      width: w,
      height: h,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } catch (_) {
    return null;
  }
}

int _measure(img.BitmapFont font, String text) {
  var w = 0;
  for (final c in text.codeUnits) {
    final ch = font.characters[c];
    w += ch?.xAdvance ?? font.base ~/ 2;
  }
  return w;
}
