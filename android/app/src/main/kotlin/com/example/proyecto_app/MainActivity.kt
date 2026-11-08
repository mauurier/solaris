package com.example.proyecto_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Marca de agua y 720p para los videos (lib/core/services/video_processing.dart).
        VideoWatermark(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
