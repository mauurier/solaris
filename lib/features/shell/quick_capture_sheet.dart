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

/// Captura fuera de orden: muestra las fotos y videos que faltan en la visita
/// en curso y abre la cámara directo en la pregunta elegida.
void showQuickCapture(BuildContext context, {FieldVisit? visit}) {
  final store = SurveyStore.instance;
  final v = visit ?? store.activeVisitFor(AppState.instance.userName);

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
  final engine = store.engineFor(v);
  final pending = engine
      .questions()
      .where((rq) =>
          (rq.question.type == QType.photo || rq.question.type == QType.video) && !engine.isAnswered(rq))
      .toList()
    ..sort((a, b) => (b.question.required ? 1 : 0) - (a.question.required ? 1 : 0));

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
