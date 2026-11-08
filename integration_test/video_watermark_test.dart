import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proyecto_app/core/services/video_processing.dart';
import 'package:proyecto_app/core/services/watermark.dart';
import 'package:proyecto_app/data/survey/entities.dart';

import 'fixtures/rotated_video.dart';

/// Corre el procesamiento nativo de video (canal `solaris/video`) en un
/// simulador o emulador:
///
///   `flutter test integration_test/video_watermark_test.dart -d DISPOSITIVO`
///
/// Deja el resultado en la carpeta de la app e imprime su ruta para revisarlo
/// con ffprobe (debe salir 720×1280, derecho y con la marca abajo a la
/// izquierda).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el video vertical sale derecho, a 720p y con la marca', (tester) async {
    final dir = Platform.isAndroid ? (await getExternalStorageDirectory())! : await getApplicationDocumentsDirectory();
    final input = File('${dir.path}/entrada.mp4')..writeAsBytesSync(base64Decode(rotatedVideo));
    const point = GeoPoint(25.68661, -100.31611);
    final progress = <double>[];

    final out = await NativeVideoProcessor().process(
      input,
      lines: watermarkLines(DateTime(2026, 11, 7, 14, 32, 5), point),
      point: point,
      onProgress: progress.add,
    );

    expect(out, isNotNull, reason: 'el sistema debe poder procesar el video');
    final kept = out!.copySync('${dir.path}/salida.mp4');
    // ignore: avoid_print
    print('SALIDA ${kept.path} ${kept.lengthSync()} bytes · avisos de avance: ${progress.length}');
  });
}
