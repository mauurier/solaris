import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../export/zip_export_screen.dart';
import '../shell/home_shell.dart';
import '../shell/quick_capture_sheet.dart';
import 'section_screen.dart';
import 'validation_screen.dart';

/// Levantamiento de una visita: inicio con hora y GPS, avance por sección,
/// validación y cierre.
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key, required this.visit});
  final FieldVisit visit;

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  final _store = SurveyStore.instance;
  bool _starting = false;

  FieldVisit get v => widget.visit;

  bool get _canEdit => v.started && !v.finished && AppState.instance.role != UserRole.revisor;

  Future<void> _start() async {
    setState(() => _starting = true);
    final fix = await LocationService.current();
    await _store.startVisit(v, fix.point);
    if (!mounted) return;
    setState(() => _starting = false);
    showAppSnack(
      context,
      fix.point == null
          ? 'Visita iniciada · ${fix.problem.toLowerCase()}'
          : 'Visita iniciada · ${fmtTime(v.startedAt!)} · ${fix.point!.label}',
      icon: fix.point == null ? Icons.location_off_rounded : Icons.check_circle_rounded,
      color: fix.point == null ? AppColors.warning : AppColors.success,
    );
  }

  Future<void> _reopen() async {
    await _store.reopenVisit(v);
    if (mounted) showAppSnack(context, 'Visita reabierta para correcciones', icon: Icons.lock_open_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final project = _store.project(v.projectId);
        if (project == null) return const Scaffold(body: SizedBox());
        final role = AppState.instance.role;
        final canReopen = v.finished && (role == UserRole.supervisor || role == UserRole.admin);

        return DetailScaffold(
          title: project.name,
          subtitle: '${v.label} · ${v.motive}',
          showGlow: true,
          actions: [
            if (_canEdit)
              HeaderIconButton(Icons.add_a_photo_rounded,
                  color: AppColors.accent, onTap: () => showQuickCapture(context, visit: v)),
          ],
          bottomBar: !v.started
              ? AppButton(
                  _starting ? 'Obteniendo ubicación…' : 'Iniciar visita',
                  icon: Icons.play_circle_fill_rounded,
                  expand: true,
                  onPressed: _starting || role == UserRole.revisor ? null : _start,
                )
              : v.finished
                  ? Row(
                      children: [
                        Expanded(
                          child: AppButton('Exportar ZIP',
                              icon: Icons.folder_zip_rounded,
                              expand: true,
                              onPressed: () => push(context, ZipExportScreen(project: project))),
                        ),
                        if (canReopen) ...[
                          const SizedBox(width: 10),
                          AppButton('Reabrir', kind: AppButtonKind.secondary, onPressed: _reopen),
                        ],
                      ],
                    )
                  : AppButton(
                      'Validar y finalizar',
                      icon: Icons.fact_check_rounded,
                      expand: true,
                      onPressed: role == UserRole.revisor ? null : () => push(context, ValidationScreen(visit: v)),
                    ),
          child: v.started ? _inProgress(project) : _notStarted(project),
        );
      },
    );
  }

  // -------------------------------------------------------------- no iniciada
  Widget _notStarted(SurveyProject project) {
    final t = _store.templateFor(v);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.event_rounded, color: AppColors.blue, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.scheduledAt == null ? 'Visita asignada' : 'Visita programada', style: T.h2),
                        const SizedBox(height: 4),
                        Text(
                          '${v.scheduledAt == null ? 'Sin fecha' : fmtDate(v.scheduledAt!)} · ${project.site}',
                          style: T.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              KeyValue('Técnico', v.technician),
              KeyValue('Supervisor', v.supervisor),
              KeyValue('Motivo', v.motive),
              KeyValue('Plantilla', '${t.name} ${t.version}'),
              KeyValue('Preguntas', '${t.questionCount} en ${t.sections.length} secciones'),
              if (project.coords != null)
                KeyValue('Sitio', project.coords!.label, icon: Icons.place_rounded, valueColor: AppColors.blue),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const GlassCard(
          color: AppColors.surfaceAlt,
          child: Row(
            children: [
              IconBadge(Icons.offline_pin_rounded, color: AppColors.success, size: 38),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listo para trabajar sin conexión', style: T.h3),
                    SizedBox(height: 3),
                    Text('Plantilla, documentos y evidencia se guardan en este teléfono.', style: T.tiny),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Qué se registra al iniciar'),
        GlassCard(
          child: Column(
            children: [
              _bullet(Icons.schedule_rounded, 'Fecha y hora de inicio'),
              _bullet(Icons.gps_fixed_rounded, 'Ubicación GPS (si hay señal)'),
              _bullet(Icons.lock_clock_rounded, 'La versión de la plantilla que usarás en esta visita'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: T.small)),
          ],
        ),
      );

  // ----------------------------------------------------------------- en curso
  Widget _inProgress(SurveyProject project) {
    final engine = _store.engineFor(v);
    final template = _store.templateFor(v);
    final overall = engine.overall;
    final ev = _store.evidenceOf(v.id);
    final done = template.sections.where((s) => engine.sectionProgress(s).complete).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
      children: [
        _progressCard(overall, engine, ev),
        const SizedBox(height: 20),
        SectionLabel('Secciones del levantamiento',
            trailing: Text('$done/${template.sections.length} completas', style: T.tiny)),
        for (var i = 0; i < template.sections.length; i++) _sectionCard(template, i, engine),
        if (_canEdit) ...[
          const SizedBox(height: 8),
          GlassCard(
            color: AppColors.surfaceAlt,
            onTap: () => showQuickCapture(context, visit: v),
            child: const Row(
              children: [
                IconBadge(Icons.bolt_rounded, color: AppColors.accent, size: 38),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Captura fuera de orden', style: T.h3),
                      SizedBox(height: 3),
                      Text('Toma la foto que tengas enfrente; la app la clasifica y recuerda lo que falta.',
                          style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _progressCard(SectionProgress overall, VisitEngine engine, List<Evidence> ev) {
    final blocking = engine.blockingCount;
    final photos = ev.where((e) => e.kind == EvidenceKind.photo).length;
    final videos = ev.where((e) => e.kind == EvidenceKind.video).length;
    final docs = ev.where((e) => e.kind == EvidenceKind.document).length;
    final elapsed = (v.endedAt ?? DateTime.now()).difference(v.startedAt!);

    return GlassCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF171C26), Color(0xFF12161E)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(value: overall.value, size: 78, stroke: 7, color: v.status.color),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVANTAMIENTO', style: T.overline.copyWith(color: AppColors.accent)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        StatusPill(v.finished ? 'Finalizada' : v.status.label, color: v.status.color, dense: true),
                        if (blocking > 0)
                          StatusPill('$blocking obligatorios',
                              color: AppColors.danger, dense: true, icon: Icons.error_outline_rounded),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('${fmtTime(v.startedAt!)} · ${fmtDuration(elapsed)}', style: T.tiny),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(v.startPoint == null ? Icons.location_off_rounded : Icons.gps_fixed_rounded,
                            size: 12, color: v.startPoint == null ? AppColors.warning : AppColors.success),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(v.startPoint?.label ?? 'Inicio sin señal GPS',
                              style: T.tiny, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              _chip(Icons.photo_camera_rounded, '$photos', 'fotos', AppColors.accent),
              _chip(Icons.videocam_rounded, '$videos', 'videos', AppColors.teal),
              _chip(Icons.description_rounded, '$docs', 'archivos', AppColors.violet),
              _chip(Icons.task_alt_rounded, '${overall.answered}/${overall.total}', 'respuestas', AppColors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData i, String n, String l, Color c) => Expanded(
        child: Column(
          children: [
            Icon(i, size: 16, color: c),
            const SizedBox(height: 6),
            Text(n, style: T.h3),
            const SizedBox(height: 2),
            Text(l, style: T.tiny),
          ],
        ),
      );

  Widget _sectionCard(TemplateDef t, int i, VisitEngine engine) {
    final s = t.sections[i];
    final p = engine.sectionProgress(s);
    final color = p.complete ? AppColors.success : AppColors.accent;
    final groups = s.groups.map((g) {
      if (!g.repeatable) return g.title;
      final n = engine.instanceCount(g);
      final label = (g.instanceLabel.isEmpty ? g.title : g.instanceLabel).toLowerCase();
      return '$n ${n == 1 ? label : _plural(label)}';
    }).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () => push(context, SectionScreen(visit: v, sectionIndex: i, editable: _canEdit)),
        borderColor: p.requiredPending > 0 ? AppColors.danger.withValues(alpha: 0.25) : null,
        child: Row(
          children: [
            ProgressRing(
              value: p.value,
              size: 46,
              stroke: 4,
              color: color,
              center: p.complete
                  ? const Icon(Icons.check_rounded, size: 19, color: AppColors.success)
                  : Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: T.h3),
                  const SizedBox(height: 3),
                  Text(groups, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text('${p.answered}/${p.total}',
                          style: T.tiny.copyWith(
                              color: p.complete ? AppColors.success : AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      if (p.requiredPending > 0) ...[
                        const SizedBox(width: 8),
                        StatusPill('${p.requiredPending} obligatoria${p.requiredPending > 1 ? 's' : ''}',
                            color: AppColors.danger, dense: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(s.iconData, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Plural simple en español: tablero → tableros, transformador → transformadores.
String _plural(String word) {
  if (word.isEmpty || word.endsWith('s')) return word;
  return RegExp(r'[aeiouáéíóú]$').hasMatch(word) ? '${word}s' : '${word}es';
}

/// Tarjeta compacta de visita para listas (detalle de proyecto).
class VisitTile extends StatelessWidget {
  const VisitTile({super.key, required this.visit});
  final FieldVisit visit;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final v = visit;
    final progress = v.started ? store.engineFor(v).overall.value : 0.0;
    final when = v.startedAt != null
        ? '${fmtDate(v.startedAt!)} · ${fmtTime(v.startedAt!)}${v.endedAt != null ? '–${fmtTime(v.endedAt!)}' : ''}'
        : v.scheduledAt != null
            ? 'Programada ${fmtDate(v.scheduledAt!)}'
            : 'Sin iniciar';
    return GlassCard(
      onTap: () => push(context, VisitScreen(visit: v)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(Icons.event_note_rounded, color: v.status.color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${v.label} · ${v.motive}', style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${v.technician} · $when', style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(v.finished ? 'Finalizada' : v.status.label, color: v.status.color, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          LinearMeter(label: 'Avance', value: progress, color: v.status.color),
        ],
      ),
    );
  }
}
