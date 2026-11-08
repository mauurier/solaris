package com.example.proyecto_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Canal `solaris/video` (ver lib/core/services/video_processing.dart): imprime
 * la marca de agua (fecha, hora, coordenadas y enlace de Maps) y baja el video
 * a 720p en una sola pasada con Media3 Transformer. Reemplaza al plugin
 * video_compress.
 *
 * `process` recibe id, input, output, lines y maxShortSide; contesta la ruta
 * del video o un error. Mientras trabaja manda `progress` con id y value (0–1).
 * Todo corre en el hilo principal, como pide Transformer y el canal.
 */
@OptIn(UnstableApi::class)
class VideoWatermark(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "solaris/video")
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "process") {
            result.notImplemented()
            return
        }
        try {
            start(call, result)
        } catch (e: Throwable) {
            Log.e(TAG, "No se pudo procesar el video", e)
            result.error("video", e.message ?: e.toString(), null)
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: throw IllegalArgumentException("Falta id")
        val input = call.argument<String>("input") ?: throw IllegalArgumentException("Falta input")
        val output = call.argument<String>("output") ?: throw IllegalArgumentException("Falta output")
        val lines = call.argument<List<String>>("lines") ?: emptyList()
        val maxShortSide = call.argument<Int>("maxShortSide") ?: 720

        // Tamaño tal como se ve: un video vertical viene acostado con rotación.
        val (width, height) = uprightSize(input)
        val shortSide = min(width, height)
        val scale = if (shortSide > maxShortSide) maxShortSide.toFloat() / shortSide else 1f
        val outWidth = even(width * scale)
        val outHeight = even(height * scale)

        val effects = mutableListOf<Effect>(
            Presentation.createForWidthAndHeight(outWidth, outHeight, Presentation.LAYOUT_SCALE_TO_FIT),
        )
        overlay(lines, outWidth, outHeight)?.let { effects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(it))) }

        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(ImmutableList.of(), ImmutableList.copyOf(effects)))
            .build()

        File(output).delete()
        val progress = ProgressHolder()
        var finished = false
        lateinit var transformer: Transformer
        val poll = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(progress) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", mapOf("id" to id, "value" to progress.progress / 100.0))
                }
                main.postDelayed(this, 300)
            }
        }

        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(bitrateFor(outWidth, outHeight)).build(),
                    )
                    .build(),
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    main.removeCallbacks(poll)
                    result.success(output)
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    finished = true
                    main.removeCallbacks(poll)
                    Log.e(TAG, "Falló la exportación", exportException)
                    File(output).delete()
                    result.error("video", exportException.message ?: "No se pudo exportar el video", null)
                }
            })
            .build()
        transformer.start(item, output)
        main.postDelayed(poll, 300)
    }

    private fun uprightSize(path: String): Pair<Int, Int> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (w == null || h == null || w <= 0 || h <= 0) throw IllegalStateException("El archivo no tiene pista de video")
            return if (rotation % 180 != 0) Pair(h, w) else Pair(w, h)
        } finally {
            retriever.release()
        }
    }

    /**
     * Franja semitransparente con los renglones, del mismo estilo que la de las
     * fotos (`drawWatermark` en watermark.dart): ~50 % del ancho (75 % en
     * vertical), abajo a la izquierda, enlace en azul claro.
     */
    private fun overlay(lines: List<String>, frameWidth: Int, frameHeight: Int): BitmapOverlay? {
        if (lines.isEmpty()) return null
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.SANS_SERIF }

        // Ancho del texto a 40 px para sacar el tamaño que ocupa la parte deseada.
        val base = 40f
        paint.textSize = base
        val widest = lines.maxOf { paint.measureText(it) }
        val portrait = frameHeight > frameWidth
        val share = if (lines.size > 1) (if (portrait) 0.75f else 0.5f) else (if (portrait) 0.6f else 0.45f)
        val target = min(frameWidth * share, frameWidth - 8f)
        val size = max(8f, target / (widest / base + 0.75f))
        val pad = size * 0.375f
        val lineHeight = size * 1.2f
        val width = ceil(widest * size / base + pad * 2).toInt()
        val height = ceil(lineHeight * lines.size + pad).toInt()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.argb(150, 0, 0, 0))
        paint.textSize = size
        val metrics = paint.fontMetrics
        val ascent = -metrics.ascent
        val descent = metrics.descent
        lines.forEachIndexed { i, text ->
            paint.color = if (i == 0) Color.WHITE else Color.rgb(150, 200, 255)
            val baseline = pad / 2 + i * lineHeight + (lineHeight - ascent - descent) / 2 + ascent
            canvas.drawText(text, pad, baseline, paint)
        }

        // Anclas en coordenadas normalizadas (-1 a 1): la esquina inferior
        // izquierda de la franja va a un margen de la esquina inferior izquierda
        // del cuadro.
        val margin = (frameWidth * 0.015f).roundToInt().toFloat()
        val settings = StaticOverlaySettings.Builder()
            .setOverlayFrameAnchor(-1f, -1f)
            .setBackgroundFrameAnchor(-1f + 2 * margin / frameWidth, -1f + 2 * margin / frameHeight)
            .build()
        return BitmapOverlay.createStaticBitmapOverlay(bitmap, settings)
    }

    /** ~4 Mbps a 720p, proporcional para otros tamaños. */
    private fun bitrateFor(width: Int, height: Int): Int =
        max(1_000_000, (4_000_000L * width * height / (1280L * 720L)).toInt())

    private fun even(v: Float): Int = max(2, (v / 2).roundToInt() * 2)

    companion object {
        private const val TAG = "SolarisVideo"
    }
}
