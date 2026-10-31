import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../capture/evidence_actions.dart';
import '../visits/visit_screen.dart';

/// Fotos y videos de la plantilla que aún no se capturan en la visita.
List<ResolvedQuestion> _pendingCaptures(SurveyStore store, FieldVisit v) {
  final engine = store.engineFor(v);
  return engine
      .questions()
      .where((rq) =>
          (rq.question.type == QType.photo || rq.question.type == QType.video) && !engine.isAnswered(rq))
      .toList()
    ..sort((a, b) => (b.question.required ? 1 : 0) - (a.question.required ? 1 : 0));
}

/// Captura fuera de orden: muestra las fotos y videos que faltan en la visita
/// en curso y abre la cámara directo en la pregunta elegida. Si el técnico
/// tiene varias visitas en curso, primero elige en cuál capturar.
void showQuickCapture(BuildContext context, {FieldVisit? visit}) {
  final store = SurveyStore.instance;
  final user = AppState.instance.userId;
  if (visit == null) {
    final running = store.activeVisitsFor(user);
    if (running.length > 1) {
      _pickVisit(context, running);
      return;
    }
  }
  final v = visit ?? store.activeVisitFor(user);

  if (v == null) {
    showAppSheet(
      context,
      title: 'Captura rápida',
      subtitle: 'No tienes una visita en curso',
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: EmptyState(
          icon: Icons.play_circle_outline_rounded,
          title: 'Inicia una visita',
          message: 'Abre un proyecto asignado y toca "Iniciar visita" para empezar a capturar evidencia.',
        ),
      ),
    );
    return;
  }

  final project = store.project(v.projectId);
  final pending = _pendingCaptures(store, v);

  showAppSheet(
    context,
    title: 'Captura rápida',
    subtitle: '${project?.name ?? ''} · ${v.label} · ${pending.length} evidencias por capturar',
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: EmptyState(
                icon: Icons.verified_rounded,
                title: 'Sin fotos pendientes',
                message: 'Todas las fotografías y videos de la plantilla están capturados.',
              ),
            ),
          for (final rq in pending) _PendingRow(rq: rq, visit: v, hostContext: context),
          const SizedBox(height: 8),
          AppButton(
            'Ver levantamiento completo',
            icon: Icons.checklist_rounded,
            kind: AppButtonKind.secondary,
            expand: true,
            onPressed: () {
              Navigator.pop(context);
              push(context, VisitScreen(visit: v));
            },
          ),
        ],
      ),
    ),
  );
}

/// Paso previo con dos o más visitas en curso: elegir la visita.
void _pickVisit(BuildContext context, List<FieldVisit> running) {
  final store = SurveyStore.instance;
  showAppSheet(
    context,
    title: 'Captura rápida',
    subtitle: 'Tienes ${running.length} visitas en curso: elige en cuál capturar',
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: running.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final v = running[i];
          final missing = _pendingCaptures(store, v);
          final required = missing.where((rq) => rq.question.required).length;
          return GlassCard(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(12),
            onTap: () {
              Navigator.pop(context);
              // Elegirla cuenta como abrirla: queda como su visita en curso.
              store.markVisitOpened(v, AppState.instance.userId);
              showQuickCapture(context, visit: v);
            },
            child: Row(
              children: [
                const IconBadge(Icons.pending_actions_rounded, color: AppColors.accent, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.project(v.projectId)?.name ?? '',
                        style: T.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text('${v.label} · ${v.motive}', style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        missing.isEmpty ? 'Sin fotos ni videos pendientes' : '${missing.length} por capturar',
                        style: T.tiny,
                      ),
                    ],
                  ),
                ),
                if (required > 0)
                  StatusPill('$required obligatoria${required == 1 ? '' : 's'}', color: AppColors.danger, dense: true),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.rq, required this.visit, required this.hostContext});
  final ResolvedQuestion rq;
  final FieldVisit visit;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final isVideo = rq.question.type == QType.video;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        color: AppColors.surfaceAlt,
        padding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.pop(context);
          isVideo
              ? EvidenceActions.recordVideo(hostContext, visit, rq)
              : EvidenceActions.takePhoto(hostContext, visit, rq);
        },
        child: Row(
          children: [
            IconBadge(isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                color: rq.question.required ? AppColors.accent : AppColors.textMuted, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rq.question.label, style: T.small.copyWith(color: AppColors.textPrimary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${rq.code} · ${rq.group.repeatable ? rq.instanceName : rq.section.title}', style: T.tiny),
                ],
              ),
            ),
            if (rq.question.required)
              const StatusPill('Obligatoria', color: AppColors.danger, dense: true),
          ],
        ),
      ),
    );
  }
}
