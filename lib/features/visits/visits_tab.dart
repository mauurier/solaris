import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/create_sheet.dart';
import '../shell/home_shell.dart';
import 'visit_screen.dart';

/// Pestaña de visitas: en curso, por iniciar y finalizadas. El admin además
/// busca, filtra por estado y crea visitas desde aquí.
class VisitsTab extends StatefulWidget {
  const VisitsTab({super.key});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  String _filter = 'Todas';
  String _query = '';

  static const _filters = ['Todas', 'En curso', 'Por iniciar', 'Con pendientes', 'Finalizadas', 'Con correcciones'];

  bool _matches(FieldVisit v) {
    final store = SurveyStore.instance;
    final p = store.project(v.projectId);
    final q = _query.trim().toLowerCase();
    final text = q.isEmpty ||
        [p?.name, p?.client, p?.code, v.technician, v.motive, v.label]
            .any((f) => f != null && f.toLowerCase().contains(q));
    if (!text) return false;
    final running = v.started && !v.finished;
    return switch (_filter) {
      'En curso' => running,
      'Por iniciar' => !v.started,
      'Con pendientes' => running && store.engineFor(v).blockingCount > 0,
      'Finalizadas' => v.finished,
      // Al reabrir una visita, su proyecto queda con correcciones.
      'Con correcciones' => running && p?.status == ProjectStatus.conCorrecciones,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([state, store]),
      builder: (context, _) {
        final mine = state.role == UserRole.tecnico;
        final isAdmin = state.role == UserRole.admin;
        final all = store.visits.where((v) => !mine || v.technician == state.userName).toList();
        final visits = isAdmin ? all.where(_matches).toList() : all;
        final running = visits.where((v) => v.started && !v.finished).toList()
          ..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
        final pending = visits.where((v) => !v.started).toList()
          ..sort((a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(b.scheduledAt ?? DateTime(2100)));
        final done = visits.where((v) => v.finished).toList()..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));

        final body = SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabHeader(
                title: 'Visitas',
                subtitle: '${running.length} en curso · ${pending.length} por iniciar · ${done.length} finalizadas',
              ),
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: AppSearchField(
                    hint: 'Buscar proyecto, cliente, técnico o motivo…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                FilterChips(options: _filters, selected: _filter, onSelected: (v) => setState(() => _filter = v)),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, isAdmin ? 180 : 110),
                  children: [
                    if (all.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.event_busy_rounded,
                          title: 'Sin visitas',
                          message: 'Las visitas se crean al asignar técnicos a un proyecto.',
                        ),
                      )
                    else if (visits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sin coincidencias',
                          message: 'Ninguna visita coincide con la búsqueda o el filtro.',
                        ),
                      ),
                    ..._group('En curso', running),
                    ..._group('Por iniciar', pending),
                    ..._group('Finalizadas', done),
                  ],
                ),
              ),
            ],
          ),
        );

        if (!isAdmin) return body;
        return withFloatingAction(
          context,
          body: body,
          button: ProminentButton('Nueva visita', onPressed: () => showNewVisitPicker(context)),
        );
      },
    );
  }

  List<Widget> _group(String title, List<FieldVisit> list) {
    if (list.isEmpty) return const [];
    final store = SurveyStore.instance;
    return [
      const SizedBox(height: 12),
      SectionLabel('$title · ${list.length}'),
      for (final v in list) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Text(store.project(v.projectId)?.name ?? '', style: T.tiny),
        ),
        VisitTile(visit: v),
        const SizedBox(height: 12),
      ],
    ];
  }
}
