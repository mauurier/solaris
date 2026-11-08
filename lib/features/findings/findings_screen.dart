import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'finding_form_screen.dart';

/// Hallazgos de un proyecto ([project]) o de todos los que ve el usuario,
/// para darles seguimiento hasta cerrarlos.
class FindingsScreen extends StatefulWidget {
  const FindingsScreen({super.key, this.project});
  final SurveyProject? project;

  @override
  State<FindingsScreen> createState() => _FindingsScreenState();
}

class _FindingsScreenState extends State<FindingsScreen> {
  final _store = SurveyStore.instance;
  String _filter = 'Abiertos';

  static const _filters = ['Abiertos', 'Críticos', 'Cerrados', 'Todos'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final app = AppState.instance;
        final all = _store.findingsFor(app.role, app.userId, projectId: widget.project?.id);
        final shown = all
            .where((f) => switch (_filter) {
                  'Abiertos' => f.open,
                  'Críticos' => f.open && f.severity == Severity.critica,
                  'Cerrados' => !f.open,
                  _ => true,
                })
            .toList();
        final open = all.where((f) => f.open).length;

        return DetailScaffold(
          title: 'Hallazgos',
          subtitle: '${widget.project?.name ?? 'Todos los proyectos'} · $open abierto${open == 1 ? '' : 's'}',
          child: Column(
            children: [
              FilterChips(options: _filters, selected: _filter, onSelected: (v) => setState(() => _filter = v)),
              const SizedBox(height: 14),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        icon: Icons.verified_rounded,
                        title: all.isEmpty ? 'Sin hallazgos' : 'Nada en este filtro',
                        message: 'Se registran desde la visita, con su severidad y fotos.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => FindingTile(finding: shown[i], showProject: widget.project == null),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de un hallazgo; al tocarla abre su detalle.
class FindingTile extends StatelessWidget {
  const FindingTile({super.key, required this.finding, this.showProject = false});
  final VisitFinding finding;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final f = finding;
    final v = store.visit(f.visitId);
    final project = v == null ? null : store.project(v.projectId);
    final photos = store.evidenceOfFinding(f.id).length;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: f.open && f.severity == Severity.critica ? AppColors.danger.withValues(alpha: 0.35) : null,
      onTap: v == null ? null : () => push(context, FindingFormScreen(visit: v, finding: f)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.code, style: T.h3),
              const SizedBox(width: 8),
              StatusPill(f.severity.label, color: f.severity.color, dense: true),
              const Spacer(),
              StatusPill(f.status.label, color: f.status.color, dense: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(f.description, style: T.small.copyWith(color: AppColors.textPrimary), maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(
            [
              f.category.label,
              if (f.location.isNotEmpty) f.location,
              if (showProject && project != null) project.code,
              ?v?.label,
              if (photos > 0) '$photos foto${photos == 1 ? '' : 's'}',
            ].join(' · '),
            style: T.tiny,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
