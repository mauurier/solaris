import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../documents/documents_screen.dart';
import '../export/export_screen.dart';
import '../findings/findings_screen.dart';
import '../history/history_screen.dart';
import '../measurements/measurements_screen.dart';
import '../photos/photo_sections_screen.dart';
import '../report/report_preview_screen.dart';
import '../review/review_screen.dart';
import '../shell/home_shell.dart';
import '../videos/videos_screen.dart';
import '../visits/new_visit_screen.dart';
import '../visits/visit_screen.dart';

/// Tarjeta de proyecto reutilizada en listas.
class ProjectRowCard extends StatelessWidget {
  const ProjectRowCard({super.key, required this.project, this.expanded = false});
  final Project project;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => push(context, ProjectDetailScreen(project: project)),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      project.status.color.withValues(alpha: 0.25),
                      project.status.color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: project.status.color.withValues(alpha: 0.28)),
                ),
                child: Text(
                  project.client.substring(0, 1),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: project.status.color,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${project.client} · ${project.type}',
                        style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(project.status.label, color: project.status.color, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          LinearMeter(
            label: expanded ? project.site : 'Avance',
            value: project.progress,
            color: project.status.color,
          ),
          if (expanded) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                _meta(Icons.person_outline_rounded, project.responsible),
                const SizedBox(width: 14),
                _meta(Icons.schedule_rounded, project.lastActivity),
                const Spacer(),
                if (project.criticalFindings > 0)
                  Row(
                    children: [
                      const Icon(Icons.priority_high_rounded, size: 13, color: AppColors.critical),
                      const SizedBox(width: 3),
                      Text('${project.criticalFindings}',
                          style: T.tiny.copyWith(color: AppColors.critical, fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) {
    return Row(
      children: [
        Icon(i, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(t, style: T.tiny),
      ],
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  String _tab = 'Resumen';

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final isField = AppState.instance.role == UserRole.tecnico;

    return DetailScaffold(
      title: p.name,
      subtitle: '${p.id} · ${p.client}',
      showGlow: true,
      actions: [
        HeaderIconButton(Icons.history_rounded, onTap: () => push(context, const HistoryScreen())),
        const SizedBox(width: 8),
        HeaderIconButton(Icons.ios_share_rounded,
            onTap: () => push(context, ExportScreen(project: p))),
      ],
      bottomBar: Row(
        children: [
          Expanded(
            child: AppButton(
              isField ? 'Continuar levantamiento' : 'Revisar levantamiento',
              icon: isField ? Icons.play_arrow_rounded : Icons.rate_review_rounded,
              expand: true,
              onPressed: () => push(
                context,
                isField
                    ? VisitScreen(project: p, visit: p.visits.first)
                    : ReviewScreen(project: p),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            'PDF',
            icon: Icons.picture_as_pdf_rounded,
            kind: AppButtonKind.secondary,
            onPressed: () => push(context, ReportPreviewScreen(project: p)),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: SegmentedPicker(
              options: const ['Resumen', 'Visitas', 'Evidencias', 'Reportes'],
              selected: _tab,
              onSelected: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tab) {
                'Visitas' => _visits(p),
                'Evidencias' => _evidence(p),
                'Reportes' => _reports(p),
                _ => _summary(p),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ resumen
  Widget _summary(Project p) {
    return ListView(
      key: const ValueKey('resumen'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        GlassCard(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF161B25), Color(0xFF12161E)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ProgressRing(value: p.progress, size: 82, stroke: 7, color: p.status.color),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AVANCE GENERAL', style: T.overline),
                        const SizedBox(height: 8),
                        StatusPill(p.status.label, color: p.status.color, icon: p.status.icon),
                        const SizedBox(height: 10),
                        Text('Última actividad ${p.lastActivity.toLowerCase()}', style: T.tiny),
                        const SizedBox(height: 4),
                        Text('Responsable: ${p.responsible}', style: T.tiny),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),
              ...p.indicators.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Row(
                    children: [
                      Icon(i.icon, size: 15, color: i.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LinearMeter(label: i.label, value: i.value, color: i.color, height: 5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Datos del proyecto'),
        GlassCard(
          child: Column(
            children: [
              KeyValue('ID', p.id),
              const Divider(),
              KeyValue('Cliente', p.client),
              KeyValue('Tipo', p.type),
              KeyValue('Sitio', p.site),
              KeyValue('Dirección', p.address),
              KeyValue('Coordenadas', p.coords, icon: Icons.place_rounded, valueColor: AppColors.blue),
              const Divider(),
              KeyValue('Responsable', p.responsible),
              KeyValue('Supervisor', p.supervisor),
              KeyValue('Técnicos', p.technicians.join(', ')),
              const Divider(),
              KeyValue('Creado', p.createdAt),
              KeyValue('Programado', p.scheduledAt),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Descripción'),
        GlassCard(child: Text(p.description, style: T.bodyMuted)),
        const SizedBox(height: 20),
        const SectionLabel('Accesos rápidos'),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              NavRow(
                title: 'Estructura de carpetas',
                subtitle: 'Organización automática de la evidencia',
                icon: Icons.account_tree_rounded,
                iconColor: AppColors.violet,
                dense: true,
                onTap: () => push(context, ExportScreen(project: p)),
              ),
              const Divider(indent: 14, endIndent: 14),
              NavRow(
                title: 'Historial y trazabilidad',
                subtitle: '38 eventos registrados',
                icon: Icons.history_rounded,
                iconColor: AppColors.blue,
                dense: true,
                onTap: () => push(context, const HistoryScreen()),
              ),
              const Divider(indent: 14, endIndent: 14),
              NavRow(
                title: 'Hallazgos',
                subtitle: '${Mock.findings.length} registrados · ${p.criticalFindings} críticos',
                icon: Icons.report_problem_rounded,
                iconColor: AppColors.danger,
                dense: true,
                onTap: () => push(context, const FindingsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ visitas
  Widget _visits(Project p) {
    return ListView(
      key: const ValueKey('visitas'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        SectionLabel(
          '${p.visits.length} visitas registradas',
          trailing: GestureDetector(
            onTap: () => push(context, NewVisitScreen(project: p), fullscreenDialog: true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 15, color: AppColors.accent),
                const SizedBox(width: 4),
                Text('Nueva visita',
                    style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        ...p.visits.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: GlassCard(
                onTap: () => push(context, VisitScreen(project: p, visit: v)),
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
                              Text('${v.id} · ${v.date}', style: T.h3),
                              const SizedBox(height: 3),
                              Text(v.type, style: T.tiny),
                            ],
                          ),
                        ),
                        StatusPill(v.status.label, color: v.status.color, dense: true),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(child: KeyValue('Técnico', v.technician)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: KeyValue('Horario', '${v.start} – ${v.end}')),
                      ],
                    ),
                    KeyValue('Motivo', v.motive),
                    const SizedBox(height: 8),
                    LinearMeter(label: 'Avance de la visita', value: v.progress, color: v.status.color),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ---------------------------------------------------------------- evidencias
  Widget _evidence(Project p) {
    final items = [
      (Icons.photo_camera_rounded, 'Fotografías', '22 de 24 · 5 subsecciones', AppColors.accent,
          const PhotoSectionsScreen()),
      (Icons.videocam_rounded, 'Videos', '2 archivos · 429 MB', AppColors.teal, const VideosScreen()),
      (Icons.folder_copy_rounded, 'Documentos', '5 archivos · 1 pendiente', AppColors.violet,
          const DocumentsScreen()),
      (Icons.electric_bolt_rounded, 'Mediciones', '11 registros', AppColors.warning,
          const MeasurementsScreen()),
      (Icons.report_problem_rounded, 'Hallazgos', '5 registrados · 2 críticos', AppColors.danger,
          const FindingsScreen()),
    ];

    return ListView(
      key: const ValueKey('evidencias'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        const SectionLabel('Evidencia capturada'),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(indent: 14, endIndent: 14),
                NavRow(
                  title: items[i].$2,
                  subtitle: items[i].$3,
                  icon: items[i].$1,
                  iconColor: items[i].$4,
                  onTap: () => push(context, items[i].$5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Últimas fotografías'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (_, i) => PhotoThumb(seed: i + 3),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ reportes
  Widget _reports(Project p) {
    final versions = [
      ('Reporte v1.2', 'Hoy · 12:48', 'Borrador con evidencia actualizada', AppColors.accent, true),
      ('Reporte v1.1', '14 Ago 2026', 'Correcciones de mediciones', AppColors.textMuted, false),
      ('Reporte v1.0', '12 Ago 2026', 'Primera versión generada', AppColors.textMuted, false),
    ];

    return ListView(
      key: const ValueKey('reportes'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        GlassCard(
          onTap: () => push(context, ReportPreviewScreen(project: p)),
          child: Row(
            children: [
              const IconBadge(Icons.auto_awesome_rounded, color: AppColors.accent, size: 44),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generar reporte técnico', style: T.h3),
                    SizedBox(height: 4),
                    Text('Plantilla: Reporte FV estándar · 12 secciones', style: T.tiny),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Control de revisiones'),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < versions.length; i++) ...[
                if (i > 0) const Divider(indent: 14, endIndent: 14),
                NavRow(
                  dense: true,
                  title: versions[i].$1,
                  subtitle: '${versions[i].$2} · ${versions[i].$3}',
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: versions[i].$4,
                  trailing: versions[i].$5
                      ? const StatusPill('Actual', color: AppColors.accent, dense: true)
                      : const Icon(Icons.download_rounded, size: 17, color: AppColors.textMuted),
                  onTap: () => push(context, ReportPreviewScreen(project: p)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Exportación'),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              NavRow(
                dense: true,
                title: 'Exportar proyecto (.ZIP)',
                subtitle: 'TRUPER_MONTERREY_LEVANTAMIENTO_2026-08-16.zip',
                icon: Icons.folder_zip_rounded,
                iconColor: AppColors.violet,
                onTap: () => push(context, ExportScreen(project: p)),
              ),
              const Divider(indent: 14, endIndent: 14),
              NavRow(
                dense: true,
                title: 'Compartir',
                subtitle: 'PDF, ZIP, fotografías y documentos',
                icon: Icons.ios_share_rounded,
                iconColor: AppColors.blue,
                onTap: () => push(context, ExportScreen(project: p)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
