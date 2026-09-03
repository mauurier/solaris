import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Marca de la aplicación: sol + rayo.
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
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.20;
    final ink = Paint()
      ..color = const Color(0xFF1B1200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    // Rayos del sol
    for (var i = 0; i < 8; i++) {
      final a = (math.pi * 2 / 8) * i - math.pi / 2;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r * 1.55);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r * 2.05);
      canvas.drawLine(p1, p2, ink);
    }

    // Disco
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1B1200));

    // Rayo
    final bolt = Path()
      ..moveTo(c.dx + r * 0.24, c.dy - r * 0.62)
      ..lineTo(c.dx - r * 0.34, c.dy + r * 0.10)
      ..lineTo(c.dx + r * 0.02, c.dy + r * 0.10)
      ..lineTo(c.dx - r * 0.20, c.dy + r * 0.66)
      ..lineTo(c.dx + r * 0.38, c.dy - r * 0.06)
      ..lineTo(c.dx - r * 0.01, c.dy - r * 0.06)
      ..close();
    canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFD08A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
