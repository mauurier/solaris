import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Panel de firma dibujable (único elemento realmente interactivo del cierre).
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.height = 170, this.onChanged});
  final double height;
  final ValueChanged<bool>? onChanged;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];

  void clear() {
    setState(_strokes.clear);
    widget.onChanged?.call(false);
  }

  bool get hasSignature => _strokes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: GestureDetector(
          onPanStart: (d) {
            setState(() => _strokes.add([d.localPosition]));
            widget.onChanged?.call(true);
          },
          onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
          child: CustomPaint(
            painter: _SignaturePainter(_strokes),
            size: Size.infinite,
            child: _strokes.isEmpty
                ? const Center(
                    child: Text(
                      'Firma aquí',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(24, size.height - 34),
      Offset(size.width - 24, size.height - 34),
      baseline,
    );

    final p = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.6, Paint()..color = AppColors.textPrimary);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
