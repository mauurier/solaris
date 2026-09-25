import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/template.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'question_editor_screen.dart';

String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

Future<bool> confirmDiscard(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('¿Descartar cambios?'),
      content: const Text('Los cambios a la plantilla no se han guardado.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir editando')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Descartar', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Editor de una plantilla completa. Trabaja sobre una copia y sólo la guarda
/// (como versión nueva) al tocar "Guardar".
class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key, required this.template, this.isNew = false});
  final TemplateDef template;
  final bool isNew;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final TemplateDef _draft = widget.template.copy();
  late final _name = TextEditingController(text: _draft.name);
  late final _type = TextEditingController(text: _draft.type);
  late bool _dirty = widget.isNew;

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppSnack(context, 'La plantilla necesita un nombre', color: AppColors.danger);
      return;
    }
    if (_draft.questionCount == 0) {
      showAppSnack(context, 'Agrega al menos una pregunta', color: AppColors.danger);
      return;
    }
    _draft
      ..name = _name.text.trim()
      ..type = _type.text.trim();
    final isNew = SurveyStore.instance.template(_draft.id) == null;
    await SurveyStore.instance.saveTemplate(_draft);
    if (!mounted) return;
    setState(() => _dirty = false);
    Navigator.pop(context);
    showAppSnack(
      context,
      isNew ? 'Plantilla creada' : 'Guardada como ${_draft.version} · aplica a las visitas que inicien desde ahora',
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextVersion = widget.isNew ? 'v1.0' : 'v${_draft.major}.${_draft.minor + 1}';
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: DetailScaffold(
        title: widget.isNew ? 'Nueva plantilla' : 'Editar plantilla',
        subtitle: widget.isNew ? 'Sin guardar' : '${widget.template.name} · ${widget.template.version}',
        bottomBar: AppButton(
          widget.isNew ? 'Crear plantilla' : 'Guardar como $nextVersion',
          icon: Icons.save_rounded,
          expand: true,
          onPressed: _dirty ? _save : null,
        ),
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          buildDefaultDragHandles: false,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Nombre', required: true),
              TextField(controller: _name, onChanged: (_) => _changed()),
              const SizedBox(height: 14),
              const FieldLabel('Tipo de levantamiento'),
              TextField(controller: _type, onChanged: (_) => _changed()),
              const SizedBox(height: 22),
              SectionLabel(
                'Secciones · ${_draft.sections.length}',
                trailing: const Text('Mantén ≡ para reordenar', style: T.tiny),
              ),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppButton(
              'Agregar sección',
              icon: Icons.add_rounded,
              kind: AppButtonKind.secondary,
              expand: true,
              onPressed: () async {
                final title = await showTextPrompt(context,
                    title: 'Nueva sección', hint: 'Ej. Sistema de tierras', requireText: true);
                if (title == null || title.isEmpty) return;
                _draft.sections.add(SectionDef(
                  id: newId('s'),
                  title: title,
                  groups: [GroupDef(id: newId('g'), title: title)],
                ));
                _changed();
              },
            ),
          ),
          itemCount: _draft.sections.length,
          onReorderItem: (from, to) {
            final s = _draft.sections.removeAt(from);
            _draft.sections.insert(to, s);
            _changed();
          },
          itemBuilder: (context, i) {
            final s = _draft.sections[i];
            final qs = s.groups.fold<int>(0, (a, g) => a + g.questions.length);
            return Padding(
              key: ValueKey(s.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                onTap: () => push(context, SectionEditorScreen(section: s, sectionIndex: i, onChanged: _changed)),
                child: Row(
                  children: [
                    IconBadge(s.iconData, color: AppColors.accent, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ${s.title}', style: T.h3),
                          const SizedBox(height: 3),
                          Text('${s.groups.length} bloque${s.groups.length == 1 ? '' : 's'} · $qs preguntas',
                              style: T.tiny),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar sección',
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.textMuted),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            title: Text('¿Eliminar "${s.title}"?'),
                            content: Text('Se quitan sus $qs preguntas de la plantilla.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          _draft.sections.removeAt(i);
                          _changed();
                        }
                      },
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bloques y preguntas de una sección.
class SectionEditorScreen extends StatefulWidget {
  const SectionEditorScreen({super.key, required this.section, required this.sectionIndex, required this.onChanged});
  final SectionDef section;
  final int sectionIndex;
  final VoidCallback onChanged;

  @override
  State<SectionEditorScreen> createState() => _SectionEditorScreenState();
}

class _SectionEditorScreenState extends State<SectionEditorScreen> {
  late final _title = TextEditingController(text: widget.section.title);

  SectionDef get s => widget.section;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '${widget.sectionIndex + 1}. ${s.title}',
      subtitle: 'Los cambios se guardan al volver y tocar "Guardar"',
      bottomBar: AppButton(
        'Agregar bloque',
        icon: Icons.add_box_rounded,
        kind: AppButtonKind.secondary,
        expand: true,
        onPressed: () async {
          final g = GroupDef(id: newId('g'), title: 'Nuevo bloque');
          if (await _editGroup(g, isNew: true)) {
            s.groups.add(g);
            _changed();
          }
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Título de la sección', required: true),
          TextField(
            controller: _title,
            onChanged: (v) {
              if (v.trim().isEmpty) return;
              s.title = v.trim();
              widget.onChanged();
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('Icono'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in sectionIcons.entries)
                GestureDetector(
                  onTap: () {
                    s.icon = e.key;
                    _changed();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: s.icon == e.key ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: s.icon == e.key ? AppColors.accent : AppColors.border),
                    ),
                    child: Icon(e.value, size: 20, color: s.icon == e.key ? AppColors.accent : AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          for (var gi = 0; gi < s.groups.length; gi++) ...[
            const SizedBox(height: 22),
            _groupCard(gi),
          ],
        ],
      ),
    );
  }

  Widget _groupCard(int gi) {
    final g = s.groups[gi];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(TemplateDef.code(widget.sectionIndex, gi), style: T.mono),
              const SizedBox(width: 8),
              Expanded(child: Text(g.title, style: T.h3)),
              if (g.repeatable) const StatusPill('Repetible', color: AppColors.teal, dense: true),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                color: AppColors.surfaceHigh,
                onSelected: (a) async {
                  switch (a) {
                    case 'edit':
                      if (await _editGroup(g)) _changed();
                    case 'up':
                      s.groups.insert(gi - 1, s.groups.removeAt(gi));
                      _changed();
                    case 'down':
                      s.groups.insert(gi + 1, s.groups.removeAt(gi));
                      _changed();
                    case 'delete':
                      s.groups.removeAt(gi);
                      _changed();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Configurar bloque')),
                  if (gi > 0) const PopupMenuItem(value: 'up', child: Text('Subir')),
                  if (gi < s.groups.length - 1) const PopupMenuItem(value: 'down', child: Text('Bajar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar bloque')),
                ],
              ),
            ],
          ),
          if (g.repeatable)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Instancias: ${g.instanceName(0)}, ${g.instanceName(1)}, ${g.instanceName(2)}…',
                  style: T.tiny),
            ),
          const Divider(),
          for (var qi = 0; qi < g.questions.length; qi++) _questionRow(g, gi, qi),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              'Pregunta',
              icon: Icons.add_rounded,
              compact: true,
              kind: AppButtonKind.ghost,
              onPressed: () async {
                final q = await Navigator.of(context).push<QuestionDef>(appRoute(
                  QuestionEditorScreen(group: g, question: QuestionDef(id: newId('q'), label: '', type: QType.text)),
                  fullscreenDialog: true,
                ));
                if (q != null) {
                  g.questions.add(q);
                  _changed();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionRow(GroupDef g, int gi, int qi) {
    final q = g.questions[qi];
    return InkWell(
      onTap: () async {
        final edited = await Navigator.of(context).push<QuestionDef>(appRoute(
          QuestionEditorScreen(group: g, question: q.copy()),
          fullscreenDialog: true,
        ));
        if (edited != null) {
          g.questions[qi] = edited;
          _changed();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(q.type.icon, size: 17, color: q.type.isEvidence ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${TemplateDef.code(widget.sectionIndex, gi, qi)}  ${q.label}',
                      style: T.small.copyWith(color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      q.type.label,
                      if (q.required) 'obligatoria',
                      if (q.showIf != null) 'si ${q.showIf!.equals}',
                      if (q.folder.isNotEmpty) q.folder.split('/').last,
                    ].join(' · '),
                    style: T.tiny,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textMuted),
              color: AppColors.surfaceHigh,
              onSelected: (a) {
                switch (a) {
                  case 'up':
                    g.questions.insert(qi - 1, g.questions.removeAt(qi));
                  case 'down':
                    g.questions.insert(qi + 1, g.questions.removeAt(qi));
                  case 'dup':
                    g.questions.insert(qi + 1, QuestionDef.fromJson({...q.toJson(), 'id': newId('q')}));
                  case 'delete':
                    g.questions.removeAt(qi);
                    for (final other in g.questions) {
                      if (other.showIf?.questionId == q.id) other.showIf = null;
                    }
                }
                _changed();
              },
              itemBuilder: (_) => [
                if (qi > 0) const PopupMenuItem(value: 'up', child: Text('Subir')),
                if (qi < g.questions.length - 1) const PopupMenuItem(value: 'down', child: Text('Bajar')),
                const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _editGroup(GroupDef g, {bool isNew = false}) async {
    final r = await showAppSheet<({String title, bool repeatable, String inst, String first})>(
      context,
      title: isNew ? 'Nuevo bloque' : 'Configurar bloque',
      subtitle: 'Un bloque repetible se captura una vez por equipo encontrado',
      child: _GroupConfigSheet(group: g),
    );
    if (r == null || r.title.isEmpty) return false;
    g
      ..title = r.title
      ..repeatable = r.repeatable
      ..instanceLabel = r.repeatable ? r.inst : ''
      ..firstInstanceLabel = r.repeatable ? r.first : '';
    return true;
  }
}

class _GroupConfigSheet extends StatefulWidget {
  const _GroupConfigSheet({required this.group});
  final GroupDef group;

  @override
  State<_GroupConfigSheet> createState() => _GroupConfigSheetState();
}

class _GroupConfigSheetState extends State<_GroupConfigSheet> {
  late final _title = TextEditingController(text: widget.group.title);
  late final _inst = TextEditingController(text: widget.group.instanceLabel);
  late final _first = TextEditingController(text: widget.group.firstInstanceLabel);
  late bool _repeatable = widget.group.repeatable;

  @override
  void dispose() {
    _title.dispose();
    _inst.dispose();
    _first.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      children: [
        const FieldLabel('Título', required: true),
        TextField(controller: _title),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repetible', style: T.body),
          subtitle: const Text('Ej. un bloque por transformador o por tablero', style: T.tiny),
          value: _repeatable,
          onChanged: (v) => setState(() => _repeatable = v),
        ),
        if (_repeatable) ...[
          const FieldLabel('Nombre de cada instancia', hint: 'Transformador → Transformador 1, 2…'),
          TextField(controller: _inst, decoration: const InputDecoration(hintText: 'Ej. Tablero')),
          const SizedBox(height: 12),
          const FieldLabel('Nombre especial de la primera', hint: 'Opcional'),
          TextField(controller: _first, decoration: const InputDecoration(hintText: 'Ej. Tablero Principal')),
        ],
        const SizedBox(height: 20),
        AppButton(
          'Aceptar',
          expand: true,
          onPressed: () => Navigator.pop(context, (
            title: _title.text.trim(),
            repeatable: _repeatable,
            inst: _inst.text.trim(),
            first: _first.text.trim(),
          )),
        ),
      ],
    );
  }
}
