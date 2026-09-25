import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Marca de la aplicación: sol minimalista oscuro sobre fondo ámbar.
/// Es el mismo dibujo del ícono de la app (ver `tool/generate_app_icon.dart`).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.radiusFactor = 0.3});
  final double size;
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.solarGradient,
        borderRadius: BorderRadius.circular(size * radiusFactor),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.32),
            blurRadius: size * 0.55,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: const CustomPaint(painter: SunMarkPainter()),
    );
  }
}

/// Sol de la marca: disco con 8 rayos redondeados, centrado en el lienzo.
class SunMarkPainter extends CustomPainter {
  const SunMarkPainter({this.color = const Color(0xFF1B1200)});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final r = s * 0.16;
    final ray = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final a = math.pi * 2 / 8 * i;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r * 1.6), c + d * (r * 2.15), ray);
    }
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant SunMarkPainter oldDelegate) => oldDelegate.color != color;
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 22, this.showTagline = true});
  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SOLARIS',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.2,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'LEVANTAMIENTOS TÉCNICOS',
            style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: AppColors.accent.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}
