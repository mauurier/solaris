import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Comprime los videos a 720p antes de guardarlos: un recorrido de varios
/// minutos baja de cientos de MB a unas decenas, sube más rápido y ocupa
/// menos en el teléfono y en Storage.
abstract class VideoCompressor {
  /// El video comprimido, o nulo si no se pudo o no valía la pena (entonces
  /// se guarda el original). [onProgress] va de 0 a 1.
  Future<File?> compress(File input, {void Function(double progress)? onProgress});
}

class NativeVideoCompressor implements VideoCompressor {
  @override
  Future<File?> compress(File input, {void Function(double progress)? onProgress}) async {
    final sub = VideoCompress.compressProgress$.subscribe((p) => onProgress?.call((p / 100).clamp(0.0, 1.0)));
    try {
      final info = await VideoCompress.compressVideo(
        input.path,
        quality: VideoQuality.Res1280x720Quality,
        includeAudio: true,
      );
      final path = info?.path;
      if (path == null) return null;
      final out = File(path);
      // Uno que ya venía ligero puede salir más pesado al recomprimirlo.
      return out.lengthSync() < input.lengthSync() ? out : null;
    } catch (_) {
      return null;
    } finally {
      sub.unsubscribe();
    }
  }
}

/// Se cambia en las pruebas.
VideoCompressor videoCompressor = NativeVideoCompressor();
