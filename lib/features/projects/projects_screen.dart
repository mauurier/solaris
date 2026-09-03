import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
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

  static const _filters = [
    'Todos',
    'En campo',
    'En revisión',
    'Con correcciones',
    'Aprobados',
    'Cerrados',
  ];

  List<Project> get _visible {
    var list = Mock.projects.where((p) {
      final q = _query.toLowerCase();
      return q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.client.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();

    switch (_filter) {
      case 'En campo':
        list = list
            .where((p) => p.status == ProjectStatus.enCampo || p.status == ProjectStatus.enCaptura)
            .toList();
      case 'En revisión':
        list = list.where((p) => p.status == ProjectStatus.enRevision).toList();
      case 'Con correcciones':
        list = list.where((p) => p.status == ProjectStatus.conCorrecciones).toList();
      case 'Aprobados':
        list = list.where((p) => p.status == ProjectStatus.aprobado).toList();
      case 'Cerrados':
        list = list.where((p) => p.status == ProjectStatus.cerrado).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    final canCreate = AppState.instance.role != UserRole.tecnico;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TabHeader(
            title: 'Proyectos',
            subtitle: '${Mock.projects.length} proyectos · 4 asignados a ti',
            actions: [
              HeaderIconButton(
                Icons.tune_rounded,
                onTap: () => _showFilters(),
              ),
              if (canCreate) ...[
                const SizedBox(width: 8),
                HeaderIconButton(
                  Icons.add_rounded,
                  color: AppColors.accent,
                  onTap: () => push(context, const NewProjectScreen(), fullscreenDialog: true),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: AppSearchField(
              hint: 'Buscar proyecto, cliente o ID…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          FilterChips(
            options: _filters,
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_off_rounded,
                    title: 'Sin proyectos',
                    message: 'No hay proyectos que coincidan con el filtro seleccionado.',
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
  }

  void _showFilters() {
    showAppSheet(
      context,
      title: 'Filtros y orden',
      subtitle: 'Ajusta la vista de la cartera de proyectos',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FieldLabel('Ordenar por'),
            const SegmentedPicker(
              options: ['Reciente', 'Avance', 'Fecha'],
              selected: 'Reciente',
              onSelected: _noop,
            ),
            const SizedBox(height: 18),
            const FieldLabel('Cliente'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Todos', ...Mock.clients.map((c) => c.name)]
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: c == 'Todos'
                              ? AppColors.accent.withValues(alpha: 0.14)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: c == 'Todos'
                                ? AppColors.accent.withValues(alpha: 0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c == 'Todos' ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            AppButton('Aplicar filtros', expand: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  static void _noop(String _) {}
}
