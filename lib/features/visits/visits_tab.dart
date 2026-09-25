import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';
import 'visit_screen.dart';

/// Pestaña de visitas: en curso, por iniciar y finalizadas.
class VisitsTab extends StatelessWidget {
  const VisitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([state, store]),
      builder: (context, _) {
        final mine = state.role == UserRole.tecnico;
        final visits = store.visits.where((v) => !mine || v.technician == state.userName).toList();
        final running = visits.where((v) => v.started && !v.finished).toList()
          ..sort((a, b) => b.startedAt!.compareTo(a.startedAt!));
        final pending = visits.where((v) => !v.started).toList()
          ..sort((a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(b.scheduledAt ?? DateTime(2100)));
        final done = visits.where((v) => v.finished).toList()..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              TabHeader(
                title: 'Visitas',
                subtitle: '${running.length} en curso · ${pending.length} por iniciar · ${done.length} finalizadas',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  children: [
                    if (visits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.event_busy_rounded,
                          title: 'Sin visitas',
                          message: 'Las visitas se crean al asignar técnicos a un proyecto.',
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
