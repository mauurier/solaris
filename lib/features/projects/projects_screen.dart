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
import '../shell/home_shell.dart';
import '../visits/visit_screen.dart';
import 'new_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _query = '';

  static const _filters = [
    'Todos',
    'Con pendientes',
    'Asignados',
    'En captura',
    'Por sincronizar',
    'En revisión',
    'Con correcciones',
    'Aprobados',
    'Cerrados',
  ];

  // El filtro vive en HomeNav para que el inicio pueda abrir la pestaña ya filtrada.
  String get _filter => HomeNav.projectsFilter.value;

  bool _matches(SurveyProject p) {
    final q = _query.toLowerCase();
    final text = q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.client.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q) ||
        p.site.toLowerCase().contains(q);
    if (!text) return false;
    return switch (_filter) {
      'Con pendientes' => SurveyStore.instance.blockingPendingsOf(p.id) > 0,
      'Asignados' => p.status == ProjectStatus.asignado || p.status == ProjectStatus.borrador,
      'En captura' => p.status == ProjectStatus.enCaptura,
      'Por sincronizar' => p.status == ProjectStatus.pendienteSync,
      'En revisión' => p.status == ProjectStatus.enRevision,
      'Con correcciones' => p.status == ProjectStatus.conCorrecciones,
      'Aprobados' => p.status == ProjectStatus.aprobado,
      'Cerrados' => p.status == ProjectStatus.cerrado,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, state, HomeNav.projectsFilter]),
      builder: (context, _) {
        final all = store.projectsFor(state.role, state.userName);
        final list = all.where(_matches).toList();
        final canCreate = state.role == UserRole.admin || state.role == UserRole.supervisor;
        final byClient = state.role == UserRole.admin;

        final body = SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabHeader(
                title: 'Proyectos',
                subtitle: state.role == UserRole.tecnico
                    ? '${all.length} asignado${all.length == 1 ? '' : 's'} a ti'
                    : byClient
                        ? '${all.length} proyecto${all.length == 1 ? '' : 's'} · ${_clientsOf(all).length} cliente${_clientsOf(all).length == 1 ? '' : 's'}'
                        : '${all.length} proyecto${all.length == 1 ? '' : 's'} en este teléfono',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: AppSearchField(
                  hint: 'Buscar proyecto, cliente, sitio o clave…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              FilterChips(options: _filters, selected: _filter, onSelected: (v) => HomeNav.projectsFilter.value = v),
              const SizedBox(height: 14),
              Expanded(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: EmptyState(
                          icon: Icons.folder_off_rounded,
                          title: all.isEmpty ? 'Aún no hay proyectos' : 'Sin coincidencias',
                          message: all.isEmpty
                              ? (canCreate
                                  ? 'Crea el primero con el botón +. Podrás subir el recibo CFE, el unifilar y planos.'
                                  : 'Cuando un supervisor te asigne un proyecto aparecerá aquí.')
                              : 'Ningún proyecto coincide con la búsqueda o el filtro.',
                          action: all.isEmpty && canCreate
                              ? AppButton('Nuevo proyecto',
                                  icon: Icons.add_rounded,
                                  onPressed: () => push(context, const NewProjectScreen(), fullscreenDialog: true))
                              : null,
                        ),
                      )
                    : byClient
                        ? ListView(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, canCreate ? 180 : 110),
                            children: [
                              for (final client in _clientsOf(list)) ...[
                                _ClientHeader(client: client, projects: list.where((p) => p.client == client).toList()),
                                for (final p in list.where((p) => p.client == client)) ...[
                                  ProjectRowCard(
                                    project: p,
                                    expanded: true,
                                    onTap: () => showProjectVisitsSheet(context, p),
                                  ),
                                  const SizedBox(height: 11),
                                ],
                                const SizedBox(height: 10),
                              ],
                            ],
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, canCreate ? 180 : 110),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 11),
                            itemBuilder: (_, i) => ProjectRowCard(project: list[i], expanded: true),
                          ),
              ),
            ],
          ),
        );

        if (!canCreate) return body;
        return withFloatingAction(
          context,
          body: body,
          button: ProminentButton(
            'Nuevo proyecto',
            onPressed: () => push(context, const NewProjectScreen(), fullscreenDialog: true),
          ),
        );
      },
    );
  }

  /// Clientes en orden alfabético.
  static List<String> _clientsOf(List<SurveyProject> list) =>
      list.map((p) => p.client).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Encabezado de cliente: nombre, proyectos y visitas.
class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.client, required this.projects});
  final String client;
  final List<SurveyProject> projects;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final visits = projects.fold<int>(0, (a, p) => a + store.visitsOf(p.id).length);
    final name = client.isEmpty ? 'Sin cliente' : client;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          InitialsAvatar(name.substring(0, 1), size: 34, color: AppColors.blue),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${projects.length} proyecto${projects.length == 1 ? '' : 's'} · '
                  '$visits visita${visits == 1 ? '' : 's'}',
                  style: T.tiny,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de un proyecto: cuántas visitas tiene y en qué estado está cada una.
Future<void> showProjectVisitsSheet(BuildContext context, SurveyProject project) {
  final store = SurveyStore.instance;
  final visits = store.visitsOf(project.id);
  final counts = <String, (int, Color)>{};
  for (final v in visits) {
    final label = visitStateLabel(v);
    counts[label] = ((counts[label]?.$1 ?? 0) + 1, v.status.color);
  }
  return showAppSheet(
    context,
    title: project.name,
    subtitle: '${project.client} · ${visits.length} visita${visits.length == 1 ? '' : 's'}',
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        if (visits.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Sin visitas',
            message: 'La primera visita se crea al asignar un técnico al proyecto.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in counts.entries) StatusPill('${e.key} · ${e.value.$1}', color: e.value.$2),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Visitas'),
          for (final v in visits) ...[
            VisitTile(visit: v),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 6),
        AppButton(
          'Abrir proyecto',
          icon: Icons.open_in_new_rounded,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            push(context, ProjectDetailScreen(project: project));
          },
        ),
      ],
    ),
  );
}

/// Tarjeta de proyecto reutilizada en listas.
class ProjectRowCard extends StatelessWidget {
  const ProjectRowCard({super.key, required this.project, this.expanded = false, this.onTap});
  final SurveyProject project;
  final bool expanded;

  /// Por defecto abre el detalle del proyecto.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final progress = store.progressOf(project);
    final color = project.status.color;
    return GlassCard(
      onTap: onTap ?? () => push(context, ProjectDetailScreen(project: project)),
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
                    colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Text(
                  project.client.isEmpty ? '?' : project.client.substring(0, 1),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${project.code} · ${project.client}',
                        style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(project.status.label, color: color, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          LinearMeter(label: expanded ? project.site : 'Avance', value: progress, color: color),
          if (expanded) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                _meta(Icons.engineering_rounded,
                    project.technicians.isEmpty ? 'Sin técnico' : project.technicians.join(', ')),
                const SizedBox(width: 14),
                _meta(Icons.schedule_rounded, fmtAgo(project.updatedAt)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) => Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(child: Text(t, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}
