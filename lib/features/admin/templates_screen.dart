import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/template.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'template_editor_screen.dart';

/// Plantillas de levantamiento configurables por el administrador.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DetailScaffold(
        title: 'Plantillas',
        subtitle: '${store.templates.length} configuradas · ${store.activeTemplates.length} activas',
        bottomBar: AppButton(
          'Nueva plantilla',
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () async {
            final t = TemplateDef(
              id: 'tpl-${DateTime.now().microsecondsSinceEpoch}',
              name: 'Nueva plantilla',
              type: 'Levantamiento',
              sections: [
                SectionDef(id: 's_${DateTime.now().millisecondsSinceEpoch}', title: 'Información general', groups: [
                  GroupDef(id: 'g_${DateTime.now().millisecondsSinceEpoch}', title: 'Datos generales'),
                ]),
              ],
            );
            push(context, TemplateEditorScreen(template: t, isNew: true));
          },
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            const GlassCard(
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  IconBadge(Icons.account_tree_rounded, color: AppColors.accent, size: 40),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plantilla › Secciones › Bloques › Preguntas', style: T.h3),
                        SizedBox(height: 5),
                        Text(
                          'Cada cambio guardado crea una versión nueva. Las visitas que ya empezaron conservan '
                          'la versión con la que iniciaron.',
                          style: T.tiny,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final t in store.templates) ...[_TemplateCard(template: t), const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final TemplateDef template;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final t = template;
    final uses = store.projects.where((p) => p.templateId == t.id).length;
    final evidences = t.sections.fold<int>(
        0, (a, s) => a + s.groups.fold<int>(0, (b, g) => b + g.questions.where((q) => q.type.isEvidence).length));

    return GlassCard(
      onTap: () => push(context, TemplateEditorScreen(template: t)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(Icons.dashboard_customize_rounded,
                  color: t.active ? AppColors.accent : AppColors.textMuted, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: T.h3),
                    const SizedBox(height: 3),
                    Text('${t.version} · ${t.type} · actualizada ${fmtDate(t.updatedAt)}', style: T.tiny),
                  ],
                ),
              ),
              Switch(value: t.active, onChanged: (v) => store.setTemplateActive(t, v)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill('${t.sections.length} secciones', color: AppColors.blue, dense: true),
              StatusPill('${t.questionCount} preguntas', color: AppColors.violet, dense: true),
              StatusPill('$evidences evidencias', color: AppColors.accent, dense: true),
              StatusPill(uses == 0 ? 'Sin proyectos' : 'En $uses proyecto${uses == 1 ? '' : 's'}',
                  color: uses == 0 ? AppColors.textMuted : AppColors.success, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppButton('Editar', icon: Icons.edit_rounded, compact: true, kind: AppButtonKind.secondary,
                  onPressed: () => push(context, TemplateEditorScreen(template: t))),
              const SizedBox(width: 8),
              AppButton('Duplicar', icon: Icons.copy_rounded, compact: true, kind: AppButtonKind.ghost,
                  onPressed: () async {
                    final copy = await store.duplicateTemplate(t);
                    if (context.mounted) {
                      showAppSnack(context, 'Se creó "${copy.name}"', icon: Icons.copy_rounded);
                    }
                  }),
              const Spacer(),
              if (uses == 0)
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: () => _delete(context, t),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, TemplateDef t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar plantilla?'),
        content: Text('"${t.name}" no está asignada a ningún proyecto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await SurveyStore.instance.deleteTemplate(t);
  }
}
