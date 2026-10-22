import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';

/// Tipos de proyecto que el admin puede agregar, renombrar o eliminar.
class ProjectTypesScreen extends StatelessWidget {
  const ProjectTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DetailScaffold(
        title: 'Tipos de proyecto',
        subtitle: '${store.projectTypes.length} disponibles al crear un proyecto',
        bottomBar: AppButton(
          'Nuevo tipo',
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => showProjectTypeSheet(context),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          itemCount: store.projectTypes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final t = store.projectTypes[i];
            final uses = store.projectTypeUses(t.name);
            return GlassCard(
              onTap: () => showProjectTypeSheet(context, editing: t),
              child: Row(
                children: [
                  const IconBadge(Icons.category_rounded, color: AppColors.blue, size: 40),
                  const SizedBox(width: 13),
                  Expanded(child: Text(t.name, style: T.h3, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$uses', style: T.h2.copyWith(color: AppColors.accent)),
                      Text('proyecto${uses == 1 ? '' : 's'}', style: T.tiny),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Alta o edición de un tipo. Devuelve el tipo creado o editado, o `null` si
/// se cancela o se elimina.
Future<ProjectType?> showProjectTypeSheet(BuildContext context, {ProjectType? editing}) {
  return showAppSheet<ProjectType>(
    context,
    title: editing == null ? 'Nuevo tipo de proyecto' : 'Editar tipo',
    subtitle: editing == null
        ? 'Aparecerá como opción al crear proyectos.'
        : 'Los proyectos de este tipo se actualizan con el nuevo nombre.',
    child: _ProjectTypeForm(editing: editing),
  );
}

class _ProjectTypeForm extends StatefulWidget {
  const _ProjectTypeForm({this.editing});
  final ProjectType? editing;

  @override
  State<_ProjectTypeForm> createState() => _ProjectTypeFormState();
}

class _ProjectTypeFormState extends State<_ProjectTypeForm> {
  final _store = SurveyStore.instance;
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = _store.validateProjectTypeName(_name.text, except: widget.editing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    final editing = widget.editing;
    final ProjectType result;
    if (editing == null) {
      result = await _store.addProjectType(_name.text);
    } else {
      await _store.renameProjectType(editing, _name.text);
      result = editing;
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    await _store.removeProjectType(widget.editing!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final uses = editing == null ? 0 : _store.projectTypeUses(editing.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Nombre', required: true),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Ej. Mantenimiento FV', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 18),
          AppButton(
            editing == null ? 'Agregar tipo' : 'Guardar cambios',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: _saving ? null : _save,
          ),
          if (editing != null) ...[
            const SizedBox(height: 10),
            AppButton(
              'Eliminar tipo',
              icon: Icons.delete_outline_rounded,
              kind: AppButtonKind.danger,
              expand: true,
              onPressed: _saving || uses > 0 ? null : _delete,
            ),
            if (uses > 0) ...[
              const SizedBox(height: 8),
              Text(
                'No se puede eliminar: lo usa${uses == 1 ? '' : 'n'} $uses proyecto${uses == 1 ? '' : 's'}.',
                style: T.tiny,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
