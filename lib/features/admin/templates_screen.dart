import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Plantillas',
      subtitle: '${Mock.templates.length} plantillas configuradas',
      bottomBar: AppButton(
        'Nueva plantilla',
        icon: Icons.add_rounded,
        expand: true,
        onPressed: () => showAppSnack(context, 'Editor de plantillas (prototipo)'),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Row(
              children: [
                const IconBadge(Icons.account_tree_rounded, color: AppColors.accent, size: 40),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estructura de una plantilla', style: T.h3),
                      const SizedBox(height: 5),
                      Text('Plantilla › Secciones › Subsecciones › Preguntas › Evidencias › Validaciones',
                          style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...Mock.templates.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TemplateCard(template: t),
              )),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({required this.template});
  final SurveyTemplate template;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(Icons.dashboard_customize_rounded,
                  color: t.active ? AppColors.accent : AppColors.textMuted, size: 42),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: T.h3),
                    const SizedBox(height: 4),
                    Text('${t.version} · ${t.type} · actualizada ${t.updated}', style: T.tiny),
                  ],
                ),
              ),
              if (!t.active)
                const StatusPill('Inactiva', color: AppColors.textMuted, dense: true)
              else
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                ...t.sections.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(s.code, style: T.mono.copyWith(color: AppColors.accent)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.title, style: T.small)),
                          if (s.questions > 0) ...[
                            const Icon(Icons.help_outline_rounded, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${s.questions}', style: T.tiny),
                            const SizedBox(width: 10),
                          ],
                          const Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('${s.evidences}', style: T.tiny),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
