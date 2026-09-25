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
import 'new_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _filter = 'Todos';
  String _query = '';

  static const _filters = ['Todos', 'Asignados', 'En captura', 'Por sincronizar', 'Con correcciones'];

  bool _matches(SurveyProject p) {
    final q = _query.toLowerCase();
    final text = q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.client.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q) ||
        p.site.toLowerCase().contains(q);
    if (!text) return false;
    return switch (_filter) {
      'Asignados' => p.status == ProjectStatus.asignado || p.status == ProjectStatus.borrador,
      'En captura' => p.status == ProjectStatus.enCaptura,
      'Por sincronizar' => p.status == ProjectStatus.pendienteSync,
      'Con correcciones' => p.status == ProjectStatus.conCorrecciones,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, state]),
      builder: (context, _) {
        final all = store.projectsFor(state.role, state.userName);
        final list = all.where(_matches).toList();
        final canCreate = state.role == UserRole.admin || state.role == UserRole.supervisor;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabHeader(
                title: 'Proyectos',
                subtitle: state.role == UserRole.tecnico
                    ? '${all.length} asignado${all.length == 1 ? '' : 's'} a ti'
                    : '${all.length} proyecto${all.length == 1 ? '' : 's'} en este teléfono',
                actions: [
                  if (canCreate)
                    HeaderIconButton(
                      Icons.add_rounded,
                      color: AppColors.accent,
                      onTap: () => push(context, const NewProjectScreen(), fullscreenDialog: true),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: AppSearchField(
                  hint: 'Buscar proyecto, cliente, sitio o clave…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              FilterChips(options: _filters, selected: _filter, onSelected: (v) => setState(() => _filter = v)),
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
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 11),
                        itemBuilder: (_, i) => ProjectRowCard(project: list[i], expanded: true),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de proyecto reutilizada en listas.
class ProjectRowCard extends StatelessWidget {
  const ProjectRowCard({super.key, required this.project, this.expanded = false});
  final SurveyProject project;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final progress = store.progressOf(project);
    final color = project.status.color;
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
