import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../projects/project_detail_screen.dart';
import '../shell/home_shell.dart';

enum BreakdownKind { evidences, documents }

/// Detalle de los indicadores Evidencias y Documentos del inicio del admin:
/// gráfica de todos los proyectos o del que se elija.
class ProjectBreakdownScreen extends StatefulWidget {
  const ProjectBreakdownScreen({super.key, required this.kind, required this.projects});
  final BreakdownKind kind;
  final List<SurveyProject> projects;

  @override
  State<ProjectBreakdownScreen> createState() => _ProjectBreakdownScreenState();
}

class _ProjectBreakdownScreenState extends State<ProjectBreakdownScreen> {
  final _store = SurveyStore.instance;
  final _scroll = ScrollController();

  /// Proyecto elegido; `null` muestra todos.
  SurveyProject? _selected;

  bool get _isEvidence => widget.kind == BreakdownKind.evidences;

  static const _kinds = [
    (EvidenceKind.photo, 'Fotografías', AppColors.accent),
    (EvidenceKind.video, 'Videos', AppColors.blue),
    (EvidenceKind.document, 'Documentos', AppColors.violet),
    (EvidenceKind.signature, 'Firmas', AppColors.teal),
  ];
  static const _palette = [AppColors.violet, AppColors.blue, AppColors.accent, AppColors.teal, AppColors.warning];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Etiqueta del chip; se agrega la clave si dos proyectos se llaman igual.
  String _label(SurveyProject p) =>
      widget.projects.where((o) => o.name == p.name).length > 1 ? '${p.name} · ${p.code}' : p.name;

  void _select(SurveyProject? p) {
    setState(() => _selected = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final scope = _selected == null ? widget.projects : [_selected!];
        final ids = scope.map((p) => p.id).toSet();
        final evidences = _store.evidences.where((e) => ids.contains(e.projectId)).toList();
        final documents = _store.documents.where((d) => ids.contains(d.projectId)).toList();
        final total = _isEvidence ? evidences.length : documents.length;
        final noun = _isEvidence ? 'evidencia' : 'documento';

        return DetailScaffold(
          title: _isEvidence ? 'Evidencias por proyecto' : 'Documentos por proyecto',
          subtitle: _selected == null ? 'Todos los proyectos' : '${_selected!.client} · ${_selected!.site}',
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              FilterChips(
                options: ['Todos', ...widget.projects.map(_label)],
                selected: _selected == null ? 'Todos' : _label(_selected!),
                onSelected: (v) => _select(widget.projects.where((p) => _label(p) == v).firstOrNull),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selected?.name ?? 'Todos los proyectos', style: T.h2),
                      const SizedBox(height: 4),
                      Text('$total $noun${total == 1 ? '' : 's'}', style: T.small),
                      const SizedBox(height: 18),
                      if (total == 0)
                        EmptyState(
                          icon: _isEvidence ? Icons.photo_library_outlined : Icons.folder_off_rounded,
                          title: 'Sin registros',
                          message: _isEvidence
                              ? 'Este proyecto aún no tiene evidencias capturadas.'
                              : 'Este proyecto aún no tiene documentos.',
                        )
                      else
                        DonutChart(
                          segments: _isEvidence ? _byKind(evidences) : _byCategory(documents),
                          centerValue: '$total',
                          centerLabel: 'total',
                        ),
                    ],
                  ),
                ),
              ),
              if (_isEvidence && total > 0) ..._bySection(evidences),
              if (_selected == null)
                ..._perProject(evidences, documents)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: AppButton(
                    'Abrir proyecto',
                    icon: Icons.open_in_new_rounded,
                    kind: AppButtonKind.secondary,
                    expand: true,
                    onPressed: () => push(context, ProjectDetailScreen(project: _selected!)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<(String, double, Color)> _byKind(List<Evidence> list) => [
        for (final k in _kinds)
          if (list.any((e) => e.kind == k.$1)) (k.$2, list.where((e) => e.kind == k.$1).length.toDouble(), k.$3),
      ];

  /// Las categorías más usadas; más de cinco no se distinguen en la dona.
  List<(String, double, Color)> _byCategory(List<ProjectDocument> list) {
    final counts = <String, int>{};
    for (final d in list) {
      counts[d.category] = (counts[d.category] ?? 0) + 1;
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (top.length <= _palette.length) {
      return [for (var i = 0; i < top.length; i++) (top[i].key, top[i].value.toDouble(), _palette[i])];
    }
    final shown = top.take(_palette.length - 1).toList();
    final rest = top.skip(_palette.length - 1).fold<int>(0, (a, e) => a + e.value);
    return [
      for (var i = 0; i < shown.length; i++) (shown[i].key, shown[i].value.toDouble(), _palette[i]),
      ('Otras', rest.toDouble(), _palette.last),
    ];
  }

  /// Evidencias por sección de la plantilla de cada visita.
  List<Widget> _bySection(List<Evidence> list) {
    final counts = <String, int>{};
    for (final e in list) {
      final v = _store.visit(e.visitId);
      if (v == null) continue;
      final groupId = AnswerKey.parse(e.key).groupId;
      final section = _store
          .templateFor(v)
          .sections
          .where((s) => s.groups.any((g) => g.id == groupId))
          .firstOrNull;
      final title = section?.title ?? 'Otras';
      counts[title] = (counts[title] ?? 0) + 1;
    }
    if (counts.isEmpty) return const [];
    final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = rows.first.value;
    return [
      const SizedBox(height: 22),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SectionLabel('Por sección')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          child: Column(
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LinearMeter(
                    label: r.key,
                    value: r.value / max,
                    color: AppColors.teal,
                    showPct: false,
                    trailingText: '${r.value}',
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Comparativo entre proyectos; tocar uno lo selecciona.
  List<Widget> _perProject(List<Evidence> evidences, List<ProjectDocument> documents) {
    final rows = [
      for (final p in widget.projects)
        (
          p,
          _isEvidence
              ? evidences.where((e) => e.projectId == p.id).length
              : documents.where((d) => d.projectId == p.id).length,
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (rows.isEmpty) return const [];
    final max = rows.first.$2 == 0 ? 1 : rows.first.$2;
    return [
      const SizedBox(height: 22),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SectionLabel('Por proyecto')),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            onTap: () => _select(r.$1),
            child: Row(
              children: [
                Expanded(
                  child: LinearMeter(
                    label: _label(r.$1),
                    value: r.$2 / max,
                    color: _isEvidence ? AppColors.teal : AppColors.violet,
                    showPct: false,
                    trailingText: '${r.$2}',
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
    ];
  }
}
