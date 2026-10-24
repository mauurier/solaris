import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../projects/new_project_screen.dart';
import '../visits/new_visit_screen.dart';

/// Botón + del administrador: crear un proyecto nuevo o una visita de un
/// proyecto existente.
void showCreateSheet(BuildContext context) {
  showAppSheet(
    context,
    title: 'Crear',
    subtitle: 'Un proyecto nuevo o una visita de un proyecto existente',
    child: _CreateMenu(outer: context),
  );
}

/// Nueva visita: elegir el proyecto y abrir su alta de visita.
void showNewVisitPicker(BuildContext context) {
  showAppSheet(
    context,
    title: 'Nueva visita',
    subtitle: 'Elige el proyecto al que pertenece la visita',
    child: _CreateMenu(outer: context, visitOnly: true),
  );
}

class _CreateMenu extends StatefulWidget {
  const _CreateMenu({required this.outer, this.visitOnly = false});

  /// Contexto de la pantalla que abrió la hoja, para navegar al cerrarla.
  final BuildContext outer;

  /// Abre directo en la elección de proyecto, sin el menú.
  final bool visitOnly;

  @override
  State<_CreateMenu> createState() => _CreateMenuState();
}

class _CreateMenuState extends State<_CreateMenu> {
  final _store = SurveyStore.instance;
  late bool _pickingProject = widget.visitOnly;
  String _query = '';

  void _open(Widget page) {
    Navigator.of(context).pop();
    push(widget.outer, page, fullscreenDialog: true);
  }

  bool _matches(SurveyProject p) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.client.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q) ||
        p.site.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) => _pickingProject ? _projectPicker() : _menu();

  Widget _menu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(
            icon: Icons.create_new_folder_rounded,
            color: AppColors.accent,
            title: 'Nuevo proyecto',
            subtitle: 'Cliente, sitio, técnicos y plantilla. Crea también la primera visita.',
            onTap: () => _open(const NewProjectScreen()),
          ),
          const SizedBox(height: 10),
          _option(
            icon: Icons.event_available_rounded,
            color: AppColors.blue,
            title: 'Nueva visita',
            subtitle: _store.projects.isEmpty
                ? 'Primero crea un proyecto.'
                : 'Para un proyecto existente: información incompleta, correcciones o mediciones adicionales.',
            onTap: _store.projects.isEmpty ? null : () => setState(() => _pickingProject = true),
          ),
        ],
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.h3),
                  const SizedBox(height: 4),
                  Text(subtitle, style: T.tiny),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _projectPicker() {
    final list = _store.projects.where(_matches).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                if (!widget.visitOnly)
                  GestureDetector(
                    onTap: () => setState(() {
                      _pickingProject = false;
                      _query = '';
                    }),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                Expanded(
                  child: AppSearchField(
                    hint: '¿Para qué proyecto es la visita?',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(30, 10, 30, 24),
                    child: EmptyState(icon: Icons.search_off_rounded, title: 'Sin coincidencias'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final visits = _store.visitsOf(p.id).length;
                      return GlassCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => _open(NewVisitScreen(project: p)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${p.client} · $visits visita${visits == 1 ? '' : 's'}',
                                    style: T.tiny,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusPill(p.status.label, color: p.status.color, dense: true),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
