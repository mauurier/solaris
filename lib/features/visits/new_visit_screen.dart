import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/catalog.dart';
import '../../data/auth/user_directory.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey_store.dart';
import '../admin/catalog_screen.dart';
import '../shell/home_shell.dart';
import 'question_field.dart';

/// Visita adicional de un proyecto. El motivo sale del catálogo que edita el
/// admin, y la plantilla puede ser distinta a la del proyecto.
class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key, required this.project});
  final SurveyProject project;

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen> {
  /// Ids de técnico y motivo.
  late String _tech = widget.project.technicianIds.firstOrNull ??
      UserDirectory.instance.assignable(UserRole.tecnico).firstOrNull?.id ??
      '';
  final _store = SurveyStore.instance;
  late String _motive = _store.catalog(CatalogKind.visitMotives).firstOrNull?.id ?? '';

  /// La del proyecto si sigue activa; si no, la primera activa.
  late TemplateDef? _template = _store.activeTemplates.where((t) => t.id == widget.project.templateId).firstOrNull ??
      _store.activeTemplates.firstOrNull;
  DateTime? _date;
  bool _saving = false;

  Future<void> _addMotive() async {
    final m = await showCatalogItemSheet(context, CatalogKind.visitMotives);
    if (m != null && mounted) setState(() => _motive = m.id);
  }

  Future<void> _save() async {
    if (_motive.isEmpty || _template == null || _tech.isEmpty) {
      showAppSnack(
          context,
          _motive.isEmpty
              ? 'Elige el motivo de la visita'
              : _template == null
                  ? 'Elige una plantilla'
                  : 'Elige el técnico',
          icon: Icons.error_outline_rounded, color: AppColors.danger);
      return;
    }
    setState(() => _saving = true);
    await _store.createVisit(widget.project,
        technicianId: _tech, motiveId: _motive, scheduledAt: _date, templateId: _template!.id);
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(context, 'Visita creada y asignada a ${UserDirectory.instance.nameOf(_tech)}', icon: Icons.check_circle_rounded, color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final techs = UserDirectory.instance.assignable(UserRole.tecnico);
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
              for (final m in _store.catalog(CatalogKind.visitMotives))
                ChoicePill(label: m.name, selected: _motive == m.id, onTap: () => setState(() => _motive = m.id)),
              // El admin puede crear el motivo que falte sin salir de la pantalla.
              if (AppState.instance.role == UserRole.admin)
                ChoicePill(label: '+ Nuevo motivo', selected: false, onTap: _addMotive),
            ],
          ),
          const SizedBox(height: 20),
          const FieldLabel('Plantilla de levantamiento', required: true),
          for (final t in _store.activeTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.all(11),
                borderColor: _template?.id == t.id ? AppColors.accent.withValues(alpha: 0.45) : null,
                onTap: () => setState(() => _template = t),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: T.h3.copyWith(fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            t.id == widget.project.templateId ? '${t.version} · la del proyecto' : t.version,
                            style: T.tiny,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                        _template?.id == t.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 19,
                        color: _template?.id == t.id ? AppColors.accent : AppColors.textMuted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const FieldLabel('Técnico asignado', required: true),
          ...techs.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  color: AppColors.surfaceAlt,
                  padding: const EdgeInsets.all(11),
                  borderColor: _tech == u.id ? AppColors.accent.withValues(alpha: 0.45) : null,
                  onTap: () => setState(() => _tech = u.id),
                  child: Row(
                    children: [
                      InitialsAvatar(u.initials, size: 34, color: _tech == u.id ? AppColors.accent : AppColors.blue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(u.name, style: T.h3.copyWith(fontSize: 14))),
                      Icon(_tech == u.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          size: 19, color: _tech == u.id ? AppColors.accent : AppColors.textMuted),
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
