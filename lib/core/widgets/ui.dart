import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Fondo global con degradado y halo solar.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.showGlow = true});
  final Widget child;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1017), AppColors.bg],
          stops: [0.0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          if (showGlow)
            Positioned(
              top: -170,
              right: -110,
              child: IgnorePointer(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        AppColors.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showGlow)
            Positioned(
              top: 120,
              left: -160,
              child: IgnorePointer(
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.blue.withValues(alpha: 0.10),
                        AppColors.blue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Tarjeta base del sistema.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppTheme.radiusLg,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: gradient == null ? (color ?? AppColors.surface) : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.accent.withValues(alpha: 0.05),
        highlightColor: AppColors.accent.withValues(alpha: 0.03),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Etiqueta de sección tipo "overline".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: T.overline)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Píldora de estado.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color, this.icon, this.dense = false});
  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3.5 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 12.5, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenedor de icono con fondo tintado.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = AppColors.accent, this.size = 40, this.iconSize});
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.48),
    );
  }
}

enum AppButtonKind { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    late Color fg;
    late Color bg;
    Border? border;
    Gradient? grad;

    switch (kind) {
      case AppButtonKind.primary:
        fg = const Color(0xFF1E1400);
        bg = AppColors.accent;
        grad = AppColors.solarGradient;
        break;
      case AppButtonKind.secondary:
        fg = AppColors.textPrimary;
        bg = AppColors.surfaceHigh;
        border = Border.all(color: AppColors.border);
        break;
      case AppButtonKind.ghost:
        fg = AppColors.textSecondary;
        bg = Colors.transparent;
        border = Border.all(color: AppColors.border);
        break;
      case AppButtonKind.danger:
        fg = AppColors.danger;
        bg = AppColors.danger.withValues(alpha: 0.12);
        border = Border.all(color: AppColors.danger.withValues(alpha: 0.3));
        break;
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: compact ? 15 : 17, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: grad == null ? bg : null,
              gradient: grad,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: kind == AppButtonKind.primary && enabled
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20,
                vertical: compact ? 10 : 14.5,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso etiquetada.
class LinearMeter extends StatelessWidget {
  const LinearMeter({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.accent,
    this.showPct = true,
    this.height = 6,
    this.trailingText,
  });

  final String label;
  final double value; // 0..1
  final Color color;
  final bool showPct;
  final double height;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: T.small.copyWith(color: AppColors.textSecondary))),
            if (showPct)
              Text(
                trailingText ?? '${(value * 100).round()} %',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
              ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: height, color: AppColors.surfaceHigh),
              LayoutBuilder(
                builder: (_, c) => Container(
                  height: height,
                  width: c.maxWidth * value.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Anillo de progreso.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.color = AppColors.accent,
    this.center,
    this.trackColor = AppColors.surfaceHigh,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0), color, stroke, trackColor),
        child: Center(
          child: center ??
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.stroke, this.trackColor);
  final double value;
  final Color color;
  final double stroke;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

/// Campo de búsqueda.
class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, this.hint = 'Buscar…', this.onChanged, this.trailing});
  final String hint;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: T.body,
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        ],
      ),
    );
  }
}

/// Fila de chips de filtro.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final o = options[i];
          final sel = o == selected;
          return GestureDetector(
            onTap: () => onSelected(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: sel ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border,
                ),
              ),
              child: Text(
                o,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fila navegable estándar.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = AppColors.accent,
    this.trailing,
    this.onTap,
    this.leading,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 13),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              IconBadge(icon!, color: iconColor, size: dense ? 34 : 38),
            if (leading != null || icon != null) const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h3),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: T.tiny),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Par etiqueta / valor.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.valueColor, this.icon});
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: T.small.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: valueColor ?? AppColors.textSecondary),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: T.small.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            Text(title, style: T.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 7),
              Text(message!, style: T.small, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Avatar con iniciales.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, {super.key, this.size = 38, this.color = AppColors.blue});
  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.12)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Placeholder de fotografía (simula imagen capturada).
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.seed,
    this.captured = true,
    this.radius = 12,
    this.icon = Icons.photo_camera_rounded,
  });

  final int seed;
  final bool captured;
  final double radius;
  final IconData icon;

  static const _palettes = [
    [Color(0xFF2A3341), Color(0xFF161B23)],
    [Color(0xFF33302A), Color(0xFF1B1915)],
    [Color(0xFF243036), Color(0xFF141A1E)],
    [Color(0xFF2E2A35), Color(0xFF17151B)],
    [Color(0xFF2C3730), Color(0xFF161B18)],
  ];

  @override
  Widget build(BuildContext context) {
    if (!captured) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 20),
      );
    }
    final p = _palettes[seed % _palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _NoisePainter(seed)),
          Center(child: Icon(icon, color: Colors.white.withValues(alpha: 0.18), size: 26)),
        ],
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    for (var i = 0; i < 7; i++) {
      final r = Rect.fromLTWH(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
        rnd.nextDouble() * size.width * 0.5,
        rnd.nextDouble() * 6 + 2,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter old) => false;
}

/// Barra inferior fija con desenfoque.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE60A0D12),
            border: Border(top: BorderSide(color: AppColors.borderSoft)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, 14 + MediaQuery.of(context).padding.bottom * 0.5),
          child: child,
        ),
      ),
    );
  }
}

/// Utilidades de feedback.
void showAppSnack(BuildContext context, String message, {IconData icon = Icons.info_outline_rounded, Color color = AppColors.accent}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1900),
        content: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: T.small.copyWith(color: AppColors.textPrimary))),
          ],
        ),
      ),
    );
}

Future<R?> showAppSheet<R>(BuildContext context, {required String title, required Widget child, String? subtitle}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgElevated,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h2),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: T.small),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: child),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Etiqueta de campo de formulario.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false, this.hint});
  final String text;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(text, style: T.small.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          if (required) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Obligatorio',
                  style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          ],
          if (hint != null) ...[
            const Spacer(),
            Text(hint!, style: T.tiny),
          ],
        ],
      ),
    );
  }
}

/// Selector segmentado.
class SegmentedPicker extends StatelessWidget {
  const SegmentedPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.activeColor = AppColors.accent,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: options.map((o) {
          final sel = o == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(o),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: sel ? activeColor.withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel ? activeColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
