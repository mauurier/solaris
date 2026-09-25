import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';
import 'question_field.dart';

/// Una sección de la plantilla con sus bloques y preguntas. Los bloques
/// repetibles muestran una instancia a la vez y permiten agregar más.
class SectionScreen extends StatefulWidget {
  const SectionScreen({
    super.key,
    required this.visit,
    required this.sectionIndex,
    required this.editable,
    this.focusGroup,
    this.focusInstance = 0,
  });

  final FieldVisit visit;
  final int sectionIndex;
  final bool editable;
  final String? focusGroup;
  final int focusInstance;

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  final _store = SurveyStore.instance;
  late final _selected = <String, int>{
    if (widget.focusGroup != null) widget.focusGroup!: widget.focusInstance,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final template = _store.templateFor(widget.visit);
        final section = template.sections[widget.sectionIndex];
        final engine = _store.engineFor(widget.visit);
        final progress = engine.sectionProgress(section);
        final project = _store.project(widget.visit.projectId);
        final hasNext = widget.sectionIndex < template.sections.length - 1;

        return DetailScaffold(
          title: '${widget.sectionIndex + 1}. ${section.title}',
          subtitle: '${project?.name ?? ''} · ${widget.visit.label}',
          bottomBar: Row(
            children: [
              Expanded(
                child: AppButton(
                  hasNext ? 'Siguiente: ${template.sections[widget.sectionIndex + 1].title}' : 'Volver al levantamiento',
                  icon: hasNext ? Icons.arrow_forward_rounded : Icons.check_rounded,
                  expand: true,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (!hasNext) {
                      Navigator.pop(context);
                      return;
                    }
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => SectionScreen(
                        visit: widget.visit,
                        sectionIndex: widget.sectionIndex + 1,
                        editable: widget.editable,
                      ),
                    ));
                  },
                ),
              ),
            ],
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _header(section, progress),
              if (!widget.editable) ...[
                const SizedBox(height: 12),
                InfoBanner(
                  widget.visit.finished
                      ? 'Visita finalizada: sólo consulta. Un supervisor puede reabrirla.'
                      : 'Inicia la visita para capturar información.',
                  icon: Icons.lock_outline_rounded,
                ),
              ],
              for (var gi = 0; gi < section.groups.length; gi++) ...[
                const SizedBox(height: 22),
                ..._group(section, gi, engine),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _header(SectionDef s, SectionProgress p) {
    return GlassCard(
      child: Row(
        children: [
          ProgressRing(
            value: p.value,
            size: 58,
            stroke: 5,
            color: p.complete ? AppColors.success : AppColors.accent,
            center: Icon(s.iconData, size: 20, color: p.complete ? AppColors.success : AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.answered} de ${p.total} respondidas', style: T.h3),
                const SizedBox(height: 6),
                if (p.requiredPending > 0)
                  StatusPill('${p.requiredPending} obligatoria${p.requiredPending == 1 ? '' : 's'} pendiente${p.requiredPending == 1 ? '' : 's'}',
                      color: AppColors.danger, dense: true, icon: Icons.error_outline_rounded)
                else
                  const StatusPill('Obligatorias completas',
                      color: AppColors.success, dense: true, icon: Icons.check_rounded),
                const SizedBox(height: 6),
                const Text('Todo se guarda al momento, aunque cierres la app.', style: T.tiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _group(SectionDef section, int gi, VisitEngine engine) {
    final g = section.groups[gi];
    final count = engine.instanceCount(g);
    final inst = (_selected[g.id] ?? 0).clamp(0, count - 1);
    final questions = <ResolvedQuestion>[
      for (var qi = 0; qi < g.questions.length; qi++)
        if (engine.isVisible(g, inst, g.questions[qi]))
          ResolvedQuestion(
            section: section,
            sectionIndex: widget.sectionIndex,
            group: g,
            groupIndex: gi,
            question: g.questions[qi],
            questionIndex: qi,
            instance: inst,
          ),
    ];

    return [
      SectionLabel('${TemplateDef.code(widget.sectionIndex, gi)}  ${g.title}'),
      if (g.repeatable) ...[
        _instanceBar(section, g, count, inst, engine),
        const SizedBox(height: 12),
      ],
      for (final rq in questions) ...[
        QuestionCard(
          key: ValueKey('${widget.visit.id}-${rq.key}'),
          visit: widget.visit,
          rq: rq,
          engine: engine,
          editable: widget.editable,
        ),
        const SizedBox(height: 10),
      ],
      if (g.repeatable && widget.editable && count > 1 && inst == count - 1)
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            'Quitar ${g.instanceName(inst)}',
            icon: Icons.remove_circle_outline_rounded,
            kind: AppButtonKind.ghost,
            compact: true,
            onPressed: () => _removeLast(g, inst),
          ),
        ),
    ];
  }

  Widget _instanceBar(SectionDef section, GroupDef g, int count, int selected, VisitEngine engine) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < count; i++) ...[
            _instanceChip(g.instanceName(i), engine.groupProgress(section, g, i), i == selected,
                () => setState(() => _selected[g.id] = i)),
            const SizedBox(width: 8),
          ],
          if (widget.editable)
            GestureDetector(
              onTap: () async {
                await _store.addInstance(widget.visit, g);
                setState(() => _selected[g.id] = count);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text('Agregar ${g.instanceLabel.isEmpty ? g.title.toLowerCase() : g.instanceLabel.toLowerCase()}',
                        style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _instanceChip(String label, SectionProgress p, bool selected, VoidCallback onTap) {
    final color = p.requiredPending == 0 ? AppColors.success : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: p.value,
                strokeWidth: 2.4,
                color: color,
                backgroundColor: AppColors.surfaceHigh,
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: T.small.copyWith(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _removeLast(GroupDef g, int inst) async {
    final name = g.instanceName(inst);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('¿Quitar $name?'),
        content: const Text('Se borran sus respuestas y sus fotos de este teléfono.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.removeLastInstance(widget.visit, g);
    setState(() => _selected[g.id] = inst - 1);
  }
}
