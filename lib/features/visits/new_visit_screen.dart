import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../projects/new_project_screen.dart';
import '../shell/home_shell.dart';

class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key, required this.project});
  final Project project;

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen> {
  String _motive = 'Levantamiento inicial';
  String _type = 'Levantamiento eléctrico FV';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Nueva visita',
      subtitle: widget.project.name,
      bottomBar: AppButton(
        'Programar visita',
        icon: Icons.event_available_rounded,
        expand: true,
        onPressed: () {
          Navigator.pop(context);
          showAppSnack(context, 'Visita programada (prototipo)',
              icon: Icons.check_circle_rounded, color: AppColors.success);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Motivo de la visita', required: true),
          Column(
            children: [
              'Levantamiento inicial',
              'Información incompleta',
              'Mediciones adicionales',
              'Corrección solicitada',
              'Actividad posterior',
            ].map((m) {
              final sel = m == _motive;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  color: AppColors.surfaceAlt,
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  borderColor: sel ? AppColors.accent.withValues(alpha: 0.45) : null,
                  onTap: () => setState(() => _motive = m),
                  child: Row(
                    children: [
                      Icon(
                        sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 19,
                        color: sel ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Text(m, style: T.body.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Tipo de levantamiento', required: true),
          SegmentedPicker(
            options: const ['Levantamiento eléctrico FV', 'Reconocimiento'],
            selected: _type,
            onSelected: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Fecha y hora', required: true),
          Row(
            children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '03 Sep 2026',
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '08:00',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const FieldLabel('Técnico asignado', required: true),
          GlassCard(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const InitialsAvatar('JP', size: 36, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Juan Pérez', style: T.h3),
                      Text('Disponible · 3 proyectos activos', style: T.tiny),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Ubicación del sitio'),
          MapPlaceholder(label: widget.project.coords),
          const SizedBox(height: 18),
          const FieldLabel('Observaciones'),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Indicaciones para el técnico…'),
          ),
        ],
      ),
    );
  }
}
