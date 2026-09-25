import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Panel de firma dibujable. [SignaturePadState.toPng] exporta el trazo.
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

  /// Firma en PNG, trazo oscuro sobre fondo blanco para que se lea impresa.
  Future<Uint8List?> toPng({double pixelRatio = 3}) async {
    final size = context.size;
    if (size == null || _strokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes, ink: const Color(0xFF111827), showBaseline: false).paint(canvas, size);
    final image = await recorder
        .endRecording()
        .toImage((size.width * pixelRatio).round(), (size.height * pixelRatio).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

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
        // El trazo gana el gesto de inmediato; si no, dentro de una lista el
        // desplazamiento vertical se roba las firmas hechas de arriba abajo.
        child: RawGestureDetector(
          gestures: {
            _ImmediatePanRecognizer: GestureRecognizerFactoryWithHandlers<_ImmediatePanRecognizer>(
              _ImmediatePanRecognizer.new,
              (r) => r
                ..onStart = (d) {
                  setState(() => _strokes.add([d.localPosition]));
                  widget.onChanged?.call(true);
                }
                ..onUpdate = (d) => setState(() => _strokes.last.add(d.localPosition)),
            ),
          },
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

class _ImmediatePanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, {this.ink = AppColors.textPrimary, this.showBaseline = true});
  final List<List<Offset>> strokes;
  final Color ink;
  final bool showBaseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (showBaseline) {
      final baseline = Paint()
        ..color = AppColors.border
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(24, size.height - 34),
        Offset(size.width - 24, size.height - 34),
        baseline,
      );
    }

    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.6, Paint()..color = ink);
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
