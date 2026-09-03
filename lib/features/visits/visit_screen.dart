import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../documents/documents_screen.dart';
import '../equipment/equipment_screen.dart';
import '../findings/findings_screen.dart';
import '../forms/dynamic_form_screen.dart';
import '../measurements/measurements_screen.dart';
import '../photos/photo_sections_screen.dart';
import '../projects/new_project_screen.dart';
import '../shell/home_shell.dart';
import '../shell/quick_capture_sheet.dart';
import '../validation/validation_screen.dart';
import '../videos/videos_screen.dart';
import 'observations_screen.dart';

class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key, required this.project, required this.visit});
  final Project project;
  final Visit visit;

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late final List<SurveySection> _sections = Mock.sections();
  late bool _started = widget.visit.status != ProjectStatus.programado;

  double get _progress {
    final done = _sections.fold<int>(0, (a, s) => a + s.done);
    final total = _sections.fold<int>(0, (a, s) => a + s.total);
    return total == 0 ? 0 : done / total;
  }

  int get _blocking => Mock.pendings.where((p) => p.blocking && !p.justified).length;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: widget.project.name,
      subtitle: '${widget.visit.id} · ${widget.visit.type}',
      showGlow: true,
      actions: [
        HeaderIconButton(Icons.add_a_photo_rounded,
            color: AppColors.accent, onTap: () => showQuickCapture(context)),
      ],
      bottomBar: _started
          ? Row(
              children: [
                Expanded(
                  child: AppButton(
                    'Validar y finalizar',
                    icon: Icons.fact_check_rounded,
                    expand: true,
                    onPressed: () => push(
                      context,
                      ValidationScreen(project: widget.project, progress: _progress),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  'Pausar',
                  kind: AppButtonKind.secondary,
                  onPressed: () => showAppSnack(context, 'Visita pausada · información guardada',
                      icon: Icons.pause_circle_rounded),
                ),
              ],
            )
          : AppButton(
              'Iniciar visita',
              icon: Icons.play_circle_fill_rounded,
              expand: true,
              onPressed: () {
                setState(() => _started = true);
                showAppSnack(context, 'Visita iniciada · fecha, hora y GPS registrados',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              },
            ),
      child: _started ? _inProgress() : _notStarted(),
    );
  }

  // -------------------------------------------------------------- no iniciada
  Widget _notStarted() {
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
                        Text('Visita programada', style: T.h2),
                        const SizedBox(height: 4),
                        Text('${widget.visit.date} · ${widget.project.site}', style: T.small),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              KeyValue('Técnico', widget.visit.technician),
              KeyValue('Supervisor', widget.visit.supervisor),
              KeyValue('Motivo', widget.visit.motive),
              KeyValue('Plantilla', 'Levantamiento eléctrico FV v2.3'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Ubicación registrada al iniciar'),
        MapPlaceholder(label: widget.project.coords, height: 170),
        const SizedBox(height: 18),
        GlassCard(
          color: AppColors.surfaceAlt,
          child: Row(
            children: [
              const IconBadge(Icons.cloud_download_rounded, color: AppColors.violet, size: 38),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proyecto descargado para trabajo offline', style: T.h3),
                    SizedBox(height: 3),
                    Text('Plantilla, checklist y documentación · 42 MB', style: T.tiny),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, size: 19, color: AppColors.success),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- en curso
  Widget _inProgress() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
      children: [
        _progressCard(),
        const SizedBox(height: 20),
        SectionLabel(
          'Secciones del levantamiento',
          trailing: Text('${_sections.where((s) => s.complete).length}/${_sections.length} completas',
              style: T.tiny),
        ),
        ..._sections.map(_sectionCard),
        const SizedBox(height: 8),
        GlassCard(
          color: AppColors.surfaceAlt,
          onTap: () => showQuickCapture(context),
          child: Row(
            children: [
              const IconBadge(Icons.bolt_rounded, color: AppColors.accent, size: 38),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Captura fuera de orden', style: T.h3),
                    SizedBox(height: 3),
                    Text('Captura lo que puedas ahora; la app clasifica y recuerda lo pendiente.',
                        style: T.tiny),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressCard() {
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
              ProgressRing(value: _progress, size: 78, stroke: 7),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVANTAMIENTO', style: T.overline.copyWith(color: AppColors.accent)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const StatusPill('En captura', color: AppColors.accent, dense: true),
                        const SizedBox(width: 7),
                        StatusPill('$_blocking obligatorios',
                            color: AppColors.danger, dense: true, icon: Icons.error_outline_rounded),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Inicio ${widget.visit.start}', style: T.tiny),
                        const SizedBox(width: 12),
                        const Icon(Icons.gps_fixed_rounded, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        const Text('GPS activo', style: T.tiny),
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
              _chip(Icons.photo_camera_rounded, '22', 'fotos', AppColors.accent),
              _chip(Icons.videocam_rounded, '2', 'videos', AppColors.teal),
              _chip(Icons.electric_bolt_rounded, '11', 'mediciones', AppColors.warning),
              _chip(Icons.report_problem_rounded, '5', 'hallazgos', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData i, String n, String l, Color c) {
    return Expanded(
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
  }

  Widget _sectionCard(SurveySection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openSection(s),
        borderColor:
            s.requiredPending > 0 ? AppColors.danger.withValues(alpha: 0.28) : null,
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: ProgressRing(
                value: s.progress,
                size: 46,
                stroke: 4,
                color: s.complete ? AppColors.success : s.color,
                center: s.complete
                    ? const Icon(Icons.check_rounded, size: 19, color: AppColors.success)
                    : Text(s.code,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: s.color)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: T.h3),
                  const SizedBox(height: 3),
                  Text(s.subtitle, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text('${s.done}/${s.total}',
                          style: T.tiny.copyWith(
                              color: s.complete ? AppColors.success : AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      if (s.requiredPending > 0) ...[
                        const SizedBox(width: 8),
                        StatusPill('${s.requiredPending} obligatorio${s.requiredPending > 1 ? 's' : ''}',
                            color: AppColors.danger, dense: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openSection(SurveySection s) {
    switch (s.route) {
      case 'form':
        push(context, const DynamicFormScreen());
      case 'docs':
        push(context, const DocumentsScreen());
      case 'photos':
        push(context, const PhotoSectionsScreen());
      case 'videos':
        push(context, const VideosScreen());
      case 'measure':
        push(context, const MeasurementsScreen());
      case 'equipment':
        push(context, const EquipmentScreen());
      case 'findings':
        push(context, const FindingsScreen());
      case 'notes':
        push(context, const ObservationsScreen());
    }
  }
}
