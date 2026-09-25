import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../admin/clients_screen.dart';
import '../admin/templates_screen.dart';
import '../admin/users_screen.dart';
import '../projects/new_project_screen.dart';
import '../projects/projects_screen.dart';
import '../shell/home_shell.dart';
import '../visits/visit_screen.dart';

/// Inicio: visita en curso (técnico) o resumen de la cartera (supervisor y
/// admin), todo calculado con los datos guardados en el teléfono.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onSeeProjects});
  final VoidCallback? onSeeProjects;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([state, store]),
      builder: (context, _) {
        final isField = state.role == UserRole.tecnico;
        final projects = store.projectsFor(state.role, state.userName);
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              TabHeader(
                title: 'Hola, ${state.userName.split(' ').first}',
                subtitle: state.role.label,
                leading: InitialsAvatar(state.userInitials, size: 44, color: state.role.color),
                actions: const [_OfflineChip()],
              ),
              const SizedBox(height: 6),
              if (isField) _FieldCard(store: store, user: state.userName) else _PortfolioCard(projects: projects),
              const SizedBox(height: 22),
              _KpiRow(projects: projects, isField: isField),
              const SizedBox(height: 24),
              _RecentProjects(projects: projects, onSeeAll: onSeeProjects, canCreate: !isField && state.role != UserRole.revisor),
              if (state.role == UserRole.admin) ...[
                const SizedBox(height: 24),
                const _AdminTools(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_iphone_rounded, size: 13, color: AppColors.teal),
          SizedBox(width: 6),
          Text('Offline', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.teal)),
        ],
      ),
    );
  }
}

/// Técnico: visita en curso o la siguiente asignada.
class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.store, required this.user});
  final SurveyStore store;
  final String user;

  @override
  Widget build(BuildContext context) {
    final active = store.activeVisitFor(user);
    final next = active ??
        (store.visits.where((v) => !v.started && v.technician == user).toList()
              ..sort((a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(b.scheduledAt ?? DateTime(2100))))
            .firstOrNull;

    if (next == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          child: Row(
            children: [
              IconBadge(Icons.event_available_rounded, color: AppColors.blue, size: 44),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin visitas pendientes', style: T.h2),
                    SizedBox(height: 4),
                    Text('Cuando te asignen un levantamiento aparecerá aquí.', style: T.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final project = store.project(next.projectId)!;
    final engine = next.started ? store.engineFor(next) : null;
    final blocking = engine?.blockingCount ?? 0;
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
        onTap: () => push(context, VisitScreen(visit: next)),
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
                        Text(next.started ? 'VISITA EN CURSO' : 'SIGUIENTE VISITA',
                            style: T.overline.copyWith(color: AppColors.accent)),
                        const SizedBox(height: 10),
                        Text(project.name, style: T.h1, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${project.site} · ${next.label}', style: T.small),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                next.started
                                    ? 'Inició ${fmtTime(next.startedAt!)} · ${fmtDuration(DateTime.now().difference(next.startedAt!))}'
                                    : next.scheduledAt == null
                                        ? 'Sin fecha programada'
                                        : 'Programada ${fmtDate(next.scheduledAt!)}',
                                style: T.tiny,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ProgressRing(value: engine?.overall.value ?? 0, size: 76, stroke: 7),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  Icon(next.started ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                      size: 15, color: next.started && blocking > 0 ? AppColors.danger : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      next.started
                          ? (blocking == 0 ? 'Sin pendientes obligatorios' : '$blocking pendientes obligatorios')
                          : 'Se registrará hora y GPS al iniciar',
                      style: T.small,
                    ),
                  ),
                  AppButton(
                    next.started ? 'Continuar' : 'Abrir',
                    icon: Icons.play_arrow_rounded,
                    compact: true,
                    onPressed: () => push(context, VisitScreen(visit: next)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supervisor y admin: avance de los proyectos del teléfono.
class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.projects});
  final List<SurveyProject> projects;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final active = projects.where((p) => p.status != ProjectStatus.cerrado).toList();
    final avg = active.isEmpty ? 0.0 : active.fold<double>(0, (a, p) => a + store.progressOf(p)) / active.length;
    final inField = projects.where((p) => p.status == ProjectStatus.enCaptura).length;
    final toSync = projects.where((p) => p.status == ProjectStatus.pendienteSync).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141A24), Color(0xFF12161E)],
        ),
        borderColor: AppColors.blue.withValues(alpha: 0.22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AVANCE DE LA CARTERA', style: T.overline.copyWith(color: AppColors.blue)),
                  const SizedBox(height: 10),
                  Text('${active.length} proyecto${active.length == 1 ? '' : 's'} activo${active.length == 1 ? '' : 's'}',
                      style: T.h1),
                  const SizedBox(height: 4),
                  Text('$inField en campo · $toSync por sincronizar', style: T.small),
                  const SizedBox(height: 14),
                  LinearMeter(label: 'Avance promedio', value: avg, color: AppColors.blue),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ProgressRing(value: avg, size: 76, stroke: 7, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.projects, required this.isField});
  final List<SurveyProject> projects;
  final bool isField;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final ids = projects.map((p) => p.id).toSet();
    final visits = store.visits.where((v) => ids.contains(v.projectId)).toList();
    final ev = store.evidences.where((e) => ids.contains(e.projectId)).toList();
    final today = DateTime.now();
    final todayEv = ev.where((e) =>
        e.capturedAt.year == today.year && e.capturedAt.month == today.month && e.capturedAt.day == today.day);
    final blocking = visits
        .where((v) => v.started && !v.finished)
        .fold<int>(0, (a, v) => a + store.engineFor(v).blockingCount);
    final docs = store.documents.where((d) => ids.contains(d.projectId)).length;

    final kpis = [
      ('Proyectos', '${projects.length}', isField ? 'asignados' : 'en el teléfono', AppColors.blue,
          Icons.folder_rounded),
      ('Visitas', '${visits.where((v) => v.started && !v.finished).length}', 'en curso', AppColors.accent,
          Icons.pending_actions_rounded),
      ('Pendientes', '$blocking', 'obligatorios', AppColors.danger, Icons.checklist_rounded),
      ('Evidencias', '${ev.length}', '${todayEv.length} hoy', AppColors.teal, Icons.photo_library_rounded),
      ('Documentos', '$docs', 'de proyecto', AppColors.violet, Icons.folder_copy_rounded),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(k.$5, size: 15, color: k.$4),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(k.$1,
                            style: T.tiny.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.$2, style: T.display.copyWith(fontSize: 27, color: AppColors.textPrimary)),
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
}

class _RecentProjects extends StatelessWidget {
  const _RecentProjects({required this.projects, required this.onSeeAll, required this.canCreate});
  final List<SurveyProject> projects;
  final VoidCallback? onSeeAll;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(
            'Proyectos recientes',
            trailing: projects.isEmpty
                ? null
                : GestureDetector(
                    onTap: onSeeAll,
                    child: Text('Ver todos',
                        style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ),
          ),
        ),
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              color: AppColors.surfaceAlt,
              child: Column(
                children: [
                  const Text('Todavía no hay proyectos en este teléfono.', style: T.small),
                  if (canCreate) ...[
                    const SizedBox(height: 12),
                    AppButton('Crear proyecto',
                        icon: Icons.add_rounded,
                        onPressed: () => push(context, const NewProjectScreen(), fullscreenDialog: true)),
                  ],
                ],
              ),
            ),
          ),
        for (final p in projects.take(3))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: ProjectRowCard(project: p),
          ),
      ],
    );
  }
}

class _AdminTools extends StatelessWidget {
  const _AdminTools();

  @override
  Widget build(BuildContext context) {
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
              _tile(context, Icons.dashboard_customize_rounded, 'Plantillas', AppColors.accent, const TemplatesScreen()),
              const SizedBox(width: 10),
              _tile(context, Icons.group_rounded, 'Usuarios', AppColors.violet, const UsersScreen()),
              const SizedBox(width: 10),
              _tile(context, Icons.business_rounded, 'Clientes', AppColors.blue, const ClientsScreen()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, Color color, Widget page) {
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
