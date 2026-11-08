import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/survey/entities.dart';

/// Prepara los videos antes de guardarlos: imprime la marca de agua (la
/// misma de las fotos) y los baja a 720p en una sola pasada, así ocupan menos
/// en el teléfono y en Storage.
///
/// Lo hace el sistema (AVFoundation en iOS, Media3 Transformer en Android)
/// por el canal `solaris/video`; el código está en `ios/Runner/VideoWatermark.swift`
/// y en `android/app/src/main/kotlin/.../VideoWatermark.kt`. Sustituye al
/// plugin video_compress, el sospechoso de cerrar la app al terminar de grabar.
abstract class VideoProcessor {
  /// El video procesado, o nulo si no se pudo (entonces se guarda el
  /// original). [onProgress] va de 0 a 1.
  Future<File?> process(
    File input, {
    required List<String> lines,
    GeoPoint? point,
    void Function(double progress)? onProgress,
  });
}

class NativeVideoProcessor implements VideoProcessor {
  static const _channel = MethodChannel('solaris/video');
  static final _listeners = <String, void Function(double)>{};
  static var _handlerSet = false;
  static var _next = 0;

  /// Lado corto máximo del video que se guarda.
  static const maxShortSide = 720;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final args = call.arguments as Map;
      final value = (args['value'] as num).toDouble();
      _listeners[args['id'] as String]?.call(value.clamp(0.0, 1.0));
    });
  }

  @override
  Future<File?> process(
    File input, {
    required List<String> lines,
    GeoPoint? point,
    void Function(double progress)? onProgress,
  }) async {
    _ensureHandler();
    final id = 'v${DateTime.now().microsecondsSinceEpoch}_${_next++}';
    final dir = await getTemporaryDirectory();
    final out = File(p.join(dir.path, 'solaris_video_$id.mp4'));
    if (onProgress != null) _listeners[id] = onProgress;
    try {
      final path = await _channel.invokeMethod<String>('process', {
        'id': id,
        'input': input.path,
        'output': out.path,
        'lines': lines,
        'maxShortSide': maxShortSide,
        if (point != null) 'lat': point.lat,
        if (point != null) 'lng': point.lng,
      });
      if (path == null) return null;
      final f = File(path);
      return f.existsSync() && f.lengthSync() > 0 ? f : null;
    } catch (e) {
      debugPrint('Video: no se pudo procesar ${input.path}: $e');
      if (out.existsSync()) unawaited(out.delete().catchError((_) => out));
      return null;
    } finally {
      _listeners.remove(id);
    }
  }
}

/// Se cambia en las pruebas.
VideoProcessor videoProcessor = NativeVideoProcessor();
