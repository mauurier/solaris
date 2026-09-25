import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/formatting.dart';
import '../../core/services/location_service.dart';
import '../../core/services/watermark.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/survey/entities.dart';
import 'video_view.dart';

enum CaptureMode { photo, video }

/// Resultado de la cámara: archivo temporal listo para guardarse como evidencia.
class CaptureResult {
  const CaptureResult({
    required this.file,
    required this.capturedAt,
    required this.point,
    required this.isVideo,
    this.comment = '',
  });
  final File file;
  final DateTime capturedAt;
  final GeoPoint? point;
  final bool isVideo;
  final String comment;
}

/// Cámara del levantamiento. Cada foto sale con fecha, hora y coordenadas
/// impresas; el técnico ve el resultado antes de aceptarla o repetirla.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.mode = CaptureMode.photo,
    this.hint = '',
  });

  final String title;
  final String subtitle;
  final CaptureMode mode;
  final String hint;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _busy = false;
  bool _grid = true;
  FlashMode _flash = FlashMode.off;

  GpsFix? _fix;
  bool _locating = true;

  // Resultado pendiente de confirmar.
  File? _result;
  DateTime? _resultAt;
  GeoPoint? _resultPoint;

  bool _recording = false;
  DateTime? _recordStart;
  Timer? _ticker;

  final _comment = TextEditingController();

  bool get _video => widget.mode == CaptureMode.video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _refreshGps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller?.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      // Con tope de tiempo: si el sistema no responde se muestra el error
      // en lugar de un indicador de carga eterno.
      final cams = await availableCameras().timeout(const Duration(seconds: 10));
      if (cams.isEmpty) {
        setState(() => _error = 'Este dispositivo no tiene cámara disponible.');
        return;
      }
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(
        back,
        // 4K en fotos: suficiente para leer placas y directorios sin que la
        // marca de agua tarde demasiado en procesarse.
        _video ? ResolutionPreset.veryHigh : ResolutionPreset.ultraHigh,
        enableAudio: _video,
      );
      await c.initialize().timeout(const Duration(seconds: 15));
      await c.setFlashMode(_flash);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _error = null;
      });
    } on CameraException catch (e) {
      setState(() => _error = switch (e.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
              'Solaris no tiene permiso para usar la cámara. Actívalo en Ajustes › Solaris.',
            'AudioAccessDenied' || 'AudioAccessDeniedWithoutPrompt' || 'AudioAccessRestricted' =>
              'El video narrado necesita el micrófono. Actívalo en Ajustes › Solaris.',
            _ => 'No se pudo abrir la cámara (${e.code}).',
          });
    } catch (e) {
      setState(() => _error = 'No se pudo abrir la cámara.');
    }
  }

  Future<void> _refreshGps() async {
    setState(() => _locating = true);
    final fix = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _locating = false;
    });
    if (fix.point == null) {
      showAppSnack(context, '${fix.problem}: la foto se marcará "SIN GPS"',
          icon: Icons.location_off_rounded, color: AppColors.warning);
    }
  }

  Future<File> _tempFile(String ext) async {
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, 'solaris_${DateTime.now().microsecondsSinceEpoch}$ext'));
  }

  Future<void> _takePhoto() async {
    final c = _controller;
    if (c == null || _busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      final at = DateTime.now();
      final point = _fix?.point;
      final out = await _tempFile('.jpg');
      await stampPhoto(inputPath: shot.path, outputPath: out.path, text: watermarkText(at, point));
      unawaited(File(shot.path).delete().catchError((_) => File(shot.path)));
      if (!mounted) return;
      setState(() {
        _result = out;
        _resultAt = at;
        _resultPoint = point;
      });
    } catch (e) {
      if (mounted) showAppSnack(context, 'No se pudo tomar la foto', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Se actualiza la ubicación para la siguiente toma.
    unawaited(_refreshGps());
  }

  Future<void> _toggleRecording() async {
    final c = _controller;
    if (c == null || _busy) return;
    HapticFeedback.mediumImpact();
    if (!_recording) {
      await c.startVideoRecording();
      setState(() {
        _recording = true;
        _recordStart = DateTime.now();
        _resultPoint = _fix?.point;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
      return;
    }
    setState(() => _busy = true);
    try {
      _ticker?.cancel();
      final file = await c.stopVideoRecording();
      final out = await _tempFile(p.extension(file.path).isEmpty ? '.mp4' : p.extension(file.path));
      await File(file.path).rename(out.path).catchError((_) => File(file.path).copy(out.path));
      if (!mounted) return;
      setState(() {
        _recording = false;
        _result = out;
        _resultAt = _recordStart;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retake() {
    final f = _result;
    if (f != null) unawaited(f.delete().catchError((_) => f));
    setState(() {
      _result = null;
      _comment.clear();
    });
  }

  void _accept() {
    Navigator.pop(
      context,
      CaptureResult(
        file: _result!,
        capturedAt: _resultAt ?? DateTime.now(),
        point: _resultPoint,
        isVideo: _video,
        comment: _comment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewport(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                if (_result == null) ...[
                  if (widget.hint.isNotEmpty && !_recording) _hintCard(),
                  const SizedBox(height: 14),
                  _controls(),
                ] else
                  _reviewPanel(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewport() {
    if (_result != null) {
      return _video
          ? Center(child: VideoView(file: _result!, autoplay: true))
          : InteractiveViewer(child: Center(child: Image.file(_result!, fit: BoxFit.contain)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: EmptyState(icon: Icons.no_photography_rounded, title: 'Cámara no disponible', message: _error),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(c)),
        if (_grid) const IgnorePointer(child: CustomPaint(painter: _GridOverlay())),
        if (_busy)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(_video ? 'Guardando video…' : 'Aplicando marca de agua…',
                    style: T.small.copyWith(color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _topBar() {
    final fix = _fix;
    final gpsOk = fix?.point != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              _round(Icons.close_rounded, () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: T.h3.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(widget.subtitle,
                        style: T.tiny.copyWith(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (_result == null && !_video) ...[
                _round(
                  _flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded,
                  () async {
                    _flash = _flash == FlashMode.off ? FlashMode.always : FlashMode.off;
                    await _controller?.setFlashMode(_flash);
                    setState(() {});
                  },
                  active: _flash != FlashMode.off,
                ),
                const SizedBox(width: 8),
                _round(Icons.grid_3x3_rounded, () => setState(() => _grid = !_grid), active: _grid),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(
                _locating
                    ? Icons.gps_not_fixed_rounded
                    : gpsOk
                        ? Icons.gps_fixed_rounded
                        : Icons.location_off_rounded,
                _locating
                    ? 'Buscando GPS…'
                    : gpsOk
                        ? fix!.point!.label
                        : 'SIN GPS',
                _locating
                    ? Colors.white70
                    : gpsOk
                        ? AppColors.success
                        : AppColors.warning,
                onTap: _locating ? null : _refreshGps,
              ),
              const SizedBox(width: 8),
              if (_recording)
                _pill(Icons.fiber_manual_record_rounded,
                    fmtDurationClock(DateTime.now().difference(_recordStart!)), AppColors.danger)
              else
                _pill(Icons.schedule_rounded, fmtTime(DateTime.now()), Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hintCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.tips_and_updates_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.hint, style: T.tiny.copyWith(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final ready = _controller?.value.isInitialized ?? false;
    return Center(
      child: GestureDetector(
        onTap: !ready
            ? null
            : _video
                ? _toggleRecording
                : _takePhoto,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _video ? AppColors.danger : Colors.white.withValues(alpha: ready ? 1 : 0.3),
              shape: _recording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: _recording ? BorderRadius.circular(10) : null,
            ),
            margin: _recording ? const EdgeInsets.all(14) : EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _reviewPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_resultPoint == null ? Icons.location_off_rounded : Icons.verified_rounded,
                    size: 16, color: _resultPoint == null ? AppColors.warning : AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _video
                        ? 'Video · ${fmtDateTime(_resultAt ?? DateTime.now())}'
                        : 'Marca: ${watermarkText(_resultAt ?? DateTime.now(), _resultPoint)}',
                    style: T.tiny.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            if (AppState.instance.commentPerPhoto) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _comment,
                decoration: const InputDecoration(hintText: 'Comentario (opcional)', isDense: true),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton('Repetir', icon: Icons.replay_rounded, kind: AppButtonKind.secondary,
                      expand: true, onPressed: _retake),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(_video ? 'Usar video' : 'Usar foto',
                      icon: Icons.check_rounded, expand: true, onPressed: _accept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: active ? AppColors.accent : Colors.white24),
        ),
        child: Icon(icon, size: 19, color: active ? AppColors.accent : Colors.white),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GridOverlay extends CustomPainter {
  const _GridOverlay();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
