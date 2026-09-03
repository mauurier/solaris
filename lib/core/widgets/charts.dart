import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Gráfico de barras simple.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppColors.accent,
    this.height = 150,
    this.highlightLast = true,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final active = highlightLast && i == values.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i].toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: active ? color : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (values[i] / maxV) * (height - 46)),
                    duration: Duration(milliseconds: 500 + i * 60),
                    curve: Curves.easeOutCubic,
                    builder: (_, h, _) => Container(
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: active
                              ? [color.withValues(alpha: 0.55), color]
                              : [
                                  AppColors.surfaceHigh,
                                  AppColors.surfaceHigh.withValues(alpha: 0.75)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(labels[i], style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Dona de distribución.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 132,
    this.stroke = 18,
    this.centerLabel,
    this.centerValue,
  });

  final List<(String, double, Color)> segments;
  final double size;
  final double stroke;
  final String? centerLabel;
  final String? centerValue;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (a, s) => a + s.$2);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, t, _) => CustomPaint(
              painter: _DonutPainter(segments, total, stroke, t),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerValue ?? total.toStringAsFixed(0), style: T.h1),
                    if (centerLabel != null)
                      Text(centerLabel!, style: T.tiny),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: segments.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(s.$1, style: T.small)),
                    Text(
                      s.$2.toStringAsFixed(0),
                      style: T.small.copyWith(fontWeight: FontWeight.w700, color: s.$3),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.total, this.stroke, this.t);
  final List<(String, double, Color)> segments;
  final double total;
  final double stroke;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    var start = -math.pi / 2;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.surfaceHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    for (final s in segments) {
      final sweep = (s.$2 / total) * math.pi * 2 * t;
      canvas.drawArc(
        rect,
        start,
        sweep - 0.05,
        false,
        Paint()
          ..color = s.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.t != t;
}
