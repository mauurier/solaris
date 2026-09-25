import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';
import 'question_field.dart';

/// Visita adicional de un proyecto (información incompleta, mediciones
/// adicionales, correcciones o actividades posteriores).
class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key, required this.project});
  final SurveyProject project;

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen> {
  static const motives = [
    'Información incompleta',
    'Mediciones adicionales',
    'Corrección de información',
    'Actividades posteriores',
  ];

  late String _tech = widget.project.technicians.firstOrNull ??
      Mock.users.firstWhere((u) => u.role == UserRole.tecnico).name;
  String _motive = motives.first;
  DateTime? _date;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await SurveyStore.instance.createVisit(widget.project, technician: _tech, motive: _motive, scheduledAt: _date);
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(context, 'Visita creada y asignada a $_tech', icon: Icons.check_circle_rounded, color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final techs = Mock.users.where((u) => u.role == UserRole.tecnico && u.active).toList();
    return DetailScaffold(
      title: 'Nueva visita',
      subtitle: widget.project.name,
      bottomBar: AppButton(_saving ? 'Guardando…' : 'Crear visita',
          icon: Icons.check_rounded, expand: true, onPressed: _saving ? null : _save),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Motivo de la visita', required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in motives)
                ChoicePill(label: m, selected: _motive == m, onTap: () => setState(() => _motive = m)),
            ],
          ),
          const SizedBox(height: 20),
          const FieldLabel('Técnico asignado', required: true),
          ...techs.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  color: AppColors.surfaceAlt,
                  padding: const EdgeInsets.all(11),
                  borderColor: _tech == u.name ? AppColors.accent.withValues(alpha: 0.45) : null,
                  onTap: () => setState(() => _tech = u.name),
                  child: Row(
                    children: [
                      InitialsAvatar(u.initials, size: 34, color: _tech == u.name ? AppColors.accent : AppColors.blue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(u.name, style: T.h3.copyWith(fontSize: 14))),
                      Icon(_tech == u.name ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          size: 19, color: _tech == u.name ? AppColors.accent : AppColors.textMuted),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          const FieldLabel('Fecha programada'),
          GlassCard(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(12),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
                initialDate: _date ?? now,
              );
              if (d != null) setState(() => _date = d);
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(_date == null ? 'Sin fecha' : fmtDate(_date!), style: T.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
