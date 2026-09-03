import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'measurement_form_screen.dart';

class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final byPoint = <String, List<Measurement>>{};
    for (final m in Mock.measurements) {
      byPoint.putIfAbsent(m.point, () => []).add(m);
    }

    return DetailScaffold(
      title: '05 Mediciones Eléctricas',
      subtitle: '${Mock.measurements.length} registros · 1 pendiente',
      bottomBar: AppButton(
        'Nueva medición',
        icon: Icons.add_rounded,
        expand: true,
        onPressed: () => push(context, const MeasurementFormScreen(), fullscreenDialog: true),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GlassCard(
            borderColor: AppColors.danger.withValues(alpha: 0.28),
            color: AppColors.danger.withValues(alpha: 0.05),
            onTap: () => push(context, const MeasurementFormScreen(), fullscreenDialog: true),
            child: Row(
              children: [
                const IconBadge(Icons.error_outline_rounded, color: AppColors.danger, size: 38),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medición obligatoria pendiente', style: T.h3),
                      SizedBox(height: 3),
                      Text('Tensión Fase-Tierra · Tablero Principal', style: T.tiny),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...byPoint.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(e.key, trailing: Text('${e.value.length} registros', style: T.tiny)),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                      child: Column(
                        children: [
                          for (var i = 0; i < e.value.length; i++) ...[
                            if (i > 0) const Divider(),
                            _row(e.value[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SectionLabel('Parámetros disponibles'),
          GlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('Tensión', true),
                ('Corriente', true),
                ('Resistencia de tierra', true),
                ('Temperatura', true),
                ('Frecuencia', false),
                ('Factor de potencia', false),
                ('Potencia', false),
                ('Energía', false),
                ('Armónicos', false),
              ].map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: p.$2 ? AppColors.warning.withValues(alpha: 0.10) : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: p.$2 ? AppColors.warning.withValues(alpha: 0.28) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.$2 ? Icons.check_rounded : Icons.schedule_rounded,
                          size: 11, color: p.$2 ? AppColors.warning : AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text(p.$1,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: p.$2 ? AppColors.warning : AppColors.textMuted)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Measurement m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.type, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.straighten_rounded, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(m.instrument, style: T.tiny),
                    const SizedBox(width: 10),
                    const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(m.time, style: T.tiny),
                  ],
                ),
                if (m.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(m.note, style: T.tiny.copyWith(color: AppColors.success)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(m.value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 3),
              Text(m.unit, style: T.tiny.copyWith(color: AppColors.warning)),
            ],
          ),
        ],
      ),
    );
  }
}
