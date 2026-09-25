// Genera los íconos de iOS y Android a partir de [SunMarkPainter].
//
// Uso (desde la raíz del proyecto):
//   flutter test tool/generate_app_icon.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:proyecto_app/core/theme/app_colors.dart';
import 'package:proyecto_app/core/widgets/brand.dart';

const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _android = 'android/app/src/main/res';

const _iosIcons = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const _androidIcons = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// Dibuja el ícono a 1024 px (cuadrado, sin esquinas: el sistema aplica la máscara).
Future<img.Image> _render() async {
  const s = 1024.0;
  final rect = Offset.zero & const Size(s, s);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(rect, Paint()..shader = AppColors.solarGradient.createShader(rect));
  const SunMarkPainter().paint(canvas, rect.size);
  final image = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = img.Image.fromBytes(
    width: s.toInt(),
    height: s.toInt(),
    bytes: bytes!.buffer,
    numChannels: 4,
  );
  // Sin canal alfa: App Store rechaza el ícono de 1024 si lo tiene.
  return rgba.convert(numChannels: 3);
}

void _write(img.Image master, String path, int size) {
  final out = size == master.width
      ? master
      : img.copyResize(master, width: size, height: size, interpolation: img.Interpolation.average);
  File(path).writeAsBytesSync(img.encodePng(out));
}

void main() {
  testWidgets('genera íconos de la app', (tester) async {
    await tester.runAsync(() async {
      final master = await _render();
      _iosIcons.forEach((name, size) => _write(master, '$_ios/$name', size));
      _androidIcons.forEach((dir, size) => _write(master, '$_android/$dir/ic_launcher.png', size));
    });
  });
}
