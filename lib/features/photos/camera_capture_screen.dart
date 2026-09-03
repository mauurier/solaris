import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';

/// Cámara simulada (prototipo, sin acceso real al hardware).
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.slotTitle,
    required this.groupCode,
    required this.groupTitle,
  });

  final String slotTitle;
  final String groupCode;
  final String groupTitle;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with SingleTickerProviderStateMixin {
  bool _captured = false;
  bool _flash = false;
  bool _grid = true;
  bool _addComment = AppState.instance.commentPerPhoto;
  late final AnimationController _shutter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _shutter.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    HapticFeedback.mediumImpact();
    await _shutter.forward(from: 0);
    setState(() => _captured = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(),
          if (_grid && !_captured) const Positioned.fill(child: CustomPaint(painter: _GridOverlay())),
          if (!_captured) const Positioned.fill(child: CustomPaint(painter: _FocusBrackets())),
          AnimatedBuilder(
            animation: _shutter,
            builder: (_, _) {
              final v = _shutter.value;
              final alpha = v < 0.001 ? 0.0 : (1 - v) * 0.9;
              return IgnorePointer(
                child: Container(color: Colors.white.withValues(alpha: alpha)),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                if (!_captured) _instructionCard() else _previewActions(),
                const SizedBox(height: 14),
                if (!_captured) _shutterRow(),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _captured
              ? const [Color(0xFF2B3340), Color(0xFF10141A)]
              : const [Color(0xFF1C222B), Color(0xFF0B0E13)],
        ),
      ),
      child: CustomPaint(painter: _ScenePainter(captured: _captured)),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _roundButton(Icons.close_rounded, () => Navigator.pop(context, false)),
              const Spacer(),
              _roundButton(
                _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                () => setState(() => _flash = !_flash),
                active: _flash,
              ),
              const SizedBox(width: 10),
              _roundButton(
                Icons.grid_3x3_rounded,
                () => setState(() => _grid = !_grid),
                active: _grid,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.center_focus_strong_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.slotTitle,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('${widget.groupCode} ${widget.groupTitle}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white.withValues(alpha: 0.62))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metaChip(Icons.gps_fixed_rounded, '25.7834, -100.1889', AppColors.success),
              const SizedBox(width: 8),
              _metaChip(Icons.schedule_rounded, '13:04 · 16 Ago', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData i, String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 12, color: c),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(fontSize: 10.5, color: c)),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: active ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _instructionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Encuadra el elemento completo y verifica que los datos sean legibles antes de capturar.',
                style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.78), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shutterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.photo_library_outlined, size: 19, color: Colors.white70),
          ),
          GestureDetector(
            onTap: _take,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.cameraswitch_outlined, size: 19, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _previewActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF20E1117),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.success),
                const SizedBox(width: 8),
                const Expanded(child: Text('Fotografía capturada', style: T.h3)),
                Text('4.1 MB', style: T.tiny),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Se guardará como', style: T.tiny),
                  const SizedBox(height: 4),
                  Text('TRANSFORMADOR_PLACA_004.jpg',
                      style: T.mono.copyWith(color: AppColors.accent, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Text('${widget.groupCode} ${widget.groupTitle} · GPS y hora incrustados',
                      style: T.tiny),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Agregar comentario a esta fotografía', style: T.small),
                ),
                Switch(
                  value: _addComment,
                  onChanged: (v) => setState(() => _addComment = v),
                ),
              ],
            ),
            if (_addComment) ...[
              const SizedBox(height: 6),
              const TextField(
                maxLines: 2,
                decoration: InputDecoration(hintText: 'Comentario opcional…'),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    'Repetir',
                    icon: Icons.refresh_rounded,
                    kind: AppButtonKind.secondary,
                    expand: true,
                    compact: true,
                    onPressed: () => setState(() => _captured = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    'Usar fotografía',
                    icon: Icons.check_rounded,
                    expand: true,
                    compact: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
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
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width / 3 * i, 0), Offset(size.width / 3 * i, size.height), p);
      canvas.drawLine(Offset(0, size.height / 3 * i), Offset(size.width, size.height / 3 * i), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FocusBrackets extends CustomPainter {
  const _FocusBrackets();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final h = w * 0.72;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: w, height: h);
    final p = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(len * dx, 0), p);
      canvas.drawLine(o, o.translate(0, len * dy), p);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.captured});
  final bool captured;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: captured ? 0.06 : 0.04);
    for (var i = 0; i < 14; i++) {
      final r = Rect.fromLTWH(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
        rnd.nextDouble() * 120 + 30,
        rnd.nextDouble() * 90 + 20,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), paint);
    }
    // Silueta de un tablero
    final panel = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.44,
      height: size.height * 0.30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    for (var i = 1; i < 5; i++) {
      final y = panel.top + panel.height / 5 * i;
      canvas.drawLine(Offset(panel.left + 14, y), Offset(panel.right - 14, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.captured != captured;
}
