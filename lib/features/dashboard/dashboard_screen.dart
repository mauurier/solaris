import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../admin/clients_screen.dart';
import '../admin/templates_screen.dart';
import '../admin/users_screen.dart';
import '../findings/findings_screen.dart';
import '../history/history_screen.dart';
import '../projects/project_detail_screen.dart';
import '../review/review_screen.dart';
import '../shell/home_shell.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_screen.dart';
import '../visits/visit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSeeProjects});
  final VoidCallback? onSeeProjects;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _state = AppState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final active = Mock.active;
    final isField = _state.role == UserRole.tecnico;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          _header(),
          const SizedBox(height: 6),
          if (isField) _activeVisitCard(active) else _supervisorSummary(),
          const SizedBox(height: 22),
          _kpiRow(),
          const SizedBox(height: 24),
          _syncStrip(),
          const SizedBox(height: 24),
          if (!isField) ...[
            _pendingReviews(),
            const SizedBox(height: 24),
          ],
          _projectsSection(),
          const SizedBox(height: 24),
          _criticalFindings(),
          const SizedBox(height: 24),
          if (_state.role == UserRole.admin) ...[
            _adminTools(),
            const SizedBox(height: 24),
          ],
          _activity(),
        ],
      ),
    );
  }

  Widget _header() {
    return TabHeader(
      title: _greeting(),
      subtitle: _state.role.label,
      leading: InitialsAvatar(_state.userInitials, size: 44, color: _state.role.color),
      actions: [
        const ConnectionChip(),
        const SizedBox(width: 8),
        HeaderIconButton(
          Icons.notifications_none_rounded,
          badge: '3',
          onTap: () => _notifications(),
        ),
      ],
    );
  }

  String _greeting() {
    final first = _state.userName.split(' ').first;
    return 'Hola, $first';
  }

  void _notifications() {
    showAppSheet(
      context,
      title: 'Notificaciones',
      subtitle: '3 sin leer',
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _notif(Icons.rate_review_rounded, AppColors.danger, 'Correcciones solicitadas',
              'FEMSA Guadalajara · Laura Méndez pidió 5 correcciones', 'Hace 2 h'),
          _notif(Icons.cloud_off_rounded, AppColors.warning, 'Sincronización incompleta',
              '2 videos pendientes de subir (429 MB)', 'Hace 3 h'),
          _notif(Icons.event_available_rounded, AppColors.blue, 'Nueva visita asignada',
              'CEMEX Puebla · programada 03 Sep 2026', 'Ayer'),
        ],
      ),
    );
  }

  Widget _notif(IconData i, Color c, String title, String body, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        color: AppColors.surfaceAlt,
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(i, color: c, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h3),
                  const SizedBox(height: 3),
                  Text(body, style: T.tiny),
                  const SizedBox(height: 5),
                  Text(time, style: T.tiny.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- visita
  Widget _activeVisitCard(Project p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: EdgeInsets.zero,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1712), Color(0xFF12161E)],
        ),
        borderColor: AppColors.accent.withValues(alpha: 0.28),
        onTap: () => push(context, VisitScreen(project: p, visit: p.visits.first)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text('VISITA EN CURSO',
                                style: T.overline.copyWith(color: AppColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(p.name, style: T.h1),
                        const SizedBox(height: 4),
                        Text('${p.site} · ${p.type}', style: T.small),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 5),
                                const Text('Inició 08:42 · 3 h 18 min', style: T.tiny),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_rounded,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(p.coords, style: T.tiny),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ProgressRing(value: p.progress, size: 76, stroke: 7),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('3 pendientes obligatorios para cerrar', style: T.small),
                  ),
                  AppButton(
                    'Continuar',
                    icon: Icons.play_arrow_rounded,
                    compact: true,
                    onPressed: () => push(context, VisitScreen(project: p, visit: p.visits.first)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supervisorSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141A24), Color(0xFF12161E)],
        ),
        borderColor: AppColors.blue.withValues(alpha: 0.22),
        onTap: () => push(context, const StatsScreen()),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AVANCE DE LA CARTERA', style: T.overline.copyWith(color: AppColors.blue)),
                  const SizedBox(height: 10),
                  const Text('5 proyectos activos', style: T.h1),
                  const SizedBox(height: 4),
                  const Text('2 esperan tu revisión · 1 atrasado', style: T.small),
                  const SizedBox(height: 14),
                  const LinearMeter(label: 'Avance promedio', value: 0.70, color: AppColors.blue),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const ProgressRing(value: 0.70, size: 76, stroke: 7, color: AppColors.blue),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- kpis
  Widget _kpiRow() {
    final kpis = _state.role == UserRole.tecnico
        ? [
            ('Proyectos', '4', 'asignados', AppColors.blue, Icons.folder_rounded),
            ('Pendientes', '6', '3 obligatorios', AppColors.danger, Icons.checklist_rounded),
            ('Evidencias', '38', 'capturadas hoy', AppColors.accent, Icons.photo_library_rounded),
            ('Hallazgos', '5', '2 críticos', AppColors.warning, Icons.report_problem_rounded),
          ]
        : [
            ('Activos', '5', 'proyectos', AppColors.blue, Icons.folder_rounded),
            ('Revisión', '2', 'esperando', AppColors.teal, Icons.rate_review_rounded),
            ('Críticos', '6', 'hallazgos', AppColors.critical, Icons.priority_high_rounded),
            ('Atrasados', '1', 'proyecto', AppColors.warning, Icons.timelapse_rounded),
          ];

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kpis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final k = kpis[i];
          return SizedBox(
            width: 138,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                if (i == 3) push(context, const FindingsScreen());
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(k.$5, size: 15, color: k.$4),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          k.$1,
                          style: T.tiny.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.$2,
                          style: T.display.copyWith(fontSize: 27, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(k.$3, style: T.tiny),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------- sync
  Widget _syncStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        onTap: () => push(context, const SyncScreen()),
        child: Column(
          children: [
            Row(
              children: [
                IconBadge(
                  _state.offlineMode ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
                  color: _state.offlineMode ? AppColors.warning : AppColors.teal,
                  size: 38,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sincronización', style: T.h3),
                      const SizedBox(height: 3),
                      Text(
                        _state.offlineMode
                            ? 'Sin conexión · 3 elementos en cola'
                            : 'Última sincronización hace 12 min',
                        style: T.tiny,
                      ),
                    ],
                  ),
                ),
                Text('${(_state.syncProgress * 100).round()} %',
                    style: T.h3.copyWith(color: AppColors.teal)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 14),
            LinearMeter(
              label: '4 sincronizados · 2 pendientes · 1 error',
              value: _state.syncProgress,
              color: AppColors.teal,
              showPct: false,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- revisión
  Widget _pendingReviews() {
    final list = Mock.projects.where((p) => p.status == ProjectStatus.enRevision).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel('Esperando tu revisión'),
        ),
        ...list.map(
          (p) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: GlassCard(
              padding: const EdgeInsets.all(6),
              onTap: () => push(context, ReviewScreen(project: p)),
              child: NavRow(
                title: p.name,
                subtitle: '${p.client} · avance ${(p.progress * 100).round()} % · ${p.pendings} pendientes',
                icon: Icons.rate_review_rounded,
                iconColor: AppColors.teal,
                onTap: () => push(context, ReviewScreen(project: p)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- proyectos
  Widget _projectsSection() {
    final list = Mock.projects.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            'Proyectos recientes',
            trailing: GestureDetector(
              onTap: widget.onSeeProjects,
              child: Text('Ver todos',
                  style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        ...list.map(
          (p) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: ProjectRowCard(project: p),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- hallazgos
  Widget _criticalFindings() {
    final list = Mock.findings.where((f) => f.severity == Severity.critica).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            'Hallazgos críticos',
            trailing: GestureDetector(
              onTap: () => push(context, const FindingsScreen()),
              child: Text('Ver todos',
                  style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Divider(height: 1),
                    ),
                  NavRow(
                    dense: true,
                    title: list[i].id,
                    subtitle: list[i].description,
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: list[i].severity.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: list[i].severity.color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.priority_high_rounded, size: 17, color: list[i].severity.color),
                    ),
                    onTap: () => push(context, const FindingsScreen()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel('Administración'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _adminTile(Icons.group_rounded, 'Usuarios', AppColors.violet, const UsersScreen()),
              const SizedBox(width: 10),
              _adminTile(Icons.business_rounded, 'Clientes', AppColors.blue, const ClientsScreen()),
              const SizedBox(width: 10),
              _adminTile(Icons.dashboard_customize_rounded, 'Plantillas', AppColors.accent,
                  const TemplatesScreen()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _adminTile(IconData icon, String label, Color color, Widget page) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        onTap: () => push(context, page),
        child: Column(
          children: [
            IconBadge(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(label, style: T.small.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _activity() {
    final list = Mock.history.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            'Actividad reciente',
            trailing: GestureDetector(
              onTap: () => push(context, const HistoryScreen()),
              child: Text('Historial',
                  style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  TimelineRow(event: list[i], isLast: i == list.length - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de línea de tiempo reutilizable.
class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.event, required this.isLast});
  final HistoryEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: event.color.withValues(alpha: 0.3)),
                ),
                child: Icon(event.icon, size: 14, color: event.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.borderSoft),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(event.title, style: T.h3.copyWith(fontSize: 14.5))),
                      Text(event.time, style: T.tiny),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(event.detail, style: T.tiny),
                  const SizedBox(height: 3),
                  Text(event.user, style: T.tiny.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
