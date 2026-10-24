import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../projects/project_detail_screen.dart';
import '../visits/visit_screen.dart';

/// Botón ✓ del supervisor: proyectos con visitas finalizadas que esperan su
/// aprobación. Al abrir una visita aparece el botón "Aprobar visita".
void showApprovalsSheet(BuildContext context) {
  final store = SurveyStore.instance;
  showAppSheet(
    context,
    title: 'Por aprobar',
    child: ListenableBuilder(
      // Al volver de aprobar una visita, la lista se actualiza sola.
      listenable: store,
      builder: (context, _) {
        final pending = store.visitsToApprove;
        final projects = <String>[];
        for (final v in pending) {
          if (!projects.contains(v.projectId)) projects.add(v.projectId);
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: EmptyState(
                    icon: Icons.verified_rounded,
                    title: 'Nada por aprobar',
                    message: 'Las visitas que finalicen los técnicos aparecerán aquí.',
                  ),
                )
              else ...[
                Text(
                  '${pending.length} visita${pending.length == 1 ? '' : 's'} en '
                  '${projects.length} proyecto${projects.length == 1 ? '' : 's'}, la que más espera primero',
                  style: T.small,
                ),
                const SizedBox(height: 14),
                for (final id in projects) ..._project(context, store, id, pending),
              ],
            ],
          ),
        );
      },
    ),
  );
}

List<Widget> _project(BuildContext context, SurveyStore store, String projectId, List<FieldVisit> pending) {
  final project = store.project(projectId);
  if (project == null) return const [];
  final visits = pending.where((v) => v.projectId == projectId).toList();
  return [
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => push(context, ProjectDetailScreen(project: project)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${project.client} · ${visits.length} por aprobar',
                    style: T.tiny,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    ),
    for (final v in visits) ...[
      VisitTile(visit: v),
      const SizedBox(height: 10),
    ],
    const SizedBox(height: 8),
  ];
}
