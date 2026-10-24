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

/// Pestaña de visitas agrupadas por estado (en curso, por iniciar,
/// finalizadas y aprobadas). Admin y técnico filtran por estado; el admin
/// además busca y crea visitas desde aquí.
class VisitsTab extends StatefulWidget {
  const VisitsTab({super.key});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  String _filter = 'Todas';
  String _query = '';

  static const _adminFilters = [
    'Todas',
    'En curso',
    'Por iniciar',
    'Con pendientes',
    'Finalizadas',
    'Aprobadas',
    'Con correcciones',
  ];
  static const _fieldFilters = ['Todas', 'En curso', 'Por iniciar', 'Finalizadas', 'Aprobadas'];

  bool _matches(FieldVisit v) {
    final store = SurveyStore.instance;
    final p = store.project(v.projectId);
    final q = _query.trim().toLowerCase();
    final text = q.isEmpty ||
        [p?.name, p?.client, p?.code, v.technician, v.motive, v.label]
            .any((f) => f != null && f.toLowerCase().contains(q));
    if (!text) return false;
    final running = v.state == VisitState.enCurso;
    return switch (_filter) {
      'En curso' => running,
      'Por iniciar' => v.state == VisitState.porIniciar,
      'Con pendientes' => running && store.engineFor(v).blockingCount > 0,
      'Finalizadas' => v.state == VisitState.finalizada,
      'Aprobadas' => v.state == VisitState.aprobada,
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
        final filters = isAdmin ? _adminFilters : mine ? _fieldFilters : null;
        final all = store.visits.where((v) => !mine || v.technician == state.userName).toList();
        final visits = filters == null ? all : all.where(_matches).toList();
        List<FieldVisit> inState(VisitState s) => visits.where((v) => v.state == s).toList();
        final running = inState(VisitState.enCurso)..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
        final pending = inState(VisitState.porIniciar)
          ..sort((a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(b.scheduledAt ?? DateTime(2100)));
        final done = inState(VisitState.finalizada)..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
        final approved = inState(VisitState.aprobada)..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));

        final body = SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabHeader(
                title: 'Visitas',
                subtitle: '${running.length} en curso · ${pending.length} por iniciar · '
                    '${done.length} finalizadas · ${approved.length} aprobadas',
              ),
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: AppSearchField(
                    hint: 'Buscar proyecto, cliente, técnico o motivo…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              if (filters != null) ...[
                FilterChips(options: filters, selected: _filter, onSelected: (v) => setState(() => _filter = v)),
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
                    ..._group(VisitState.enCurso, running),
                    ..._group(VisitState.porIniciar, pending),
                    ..._group(VisitState.finalizada, done),
                    ..._group(VisitState.aprobada, approved),
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

  List<Widget> _group(VisitState state, List<FieldVisit> list) {
    if (list.isEmpty) return const [];
    final store = SurveyStore.instance;
    return [
      const SizedBox(height: 12),
      // El color del estado, igual que en la pastilla de cada visita.
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 2, right: 8, bottom: 10),
            decoration: BoxDecoration(color: state.color, shape: BoxShape.circle),
          ),
          Expanded(child: SectionLabel('${state.plural} · ${list.length}')),
        ],
      ),
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
