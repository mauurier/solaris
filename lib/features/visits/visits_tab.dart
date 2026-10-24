import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
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
/// finalizadas y aprobadas). Admin, supervisor y técnico filtran por
/// estado; admin y supervisor además buscan, el supervisor filtra por
/// técnico y fecha, y el admin crea visitas desde aquí.
class VisitsTab extends StatefulWidget {
  const VisitsTab({super.key});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  String _filter = 'Todas';
  String _query = '';

  /// Filtros extra del supervisor.
  String? _technician;
  DateTimeRange? _range;
  String _rangeLabel = 'Cualquier fecha';

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
  static const _supervisorFilters = [
    'Todas',
    'En curso',
    'Por iniciar',
    'Finalizadas',
    'Aprobadas',
    'Con correcciones',
  ];

  bool _matches(FieldVisit v) {
    final store = SurveyStore.instance;
    final p = store.project(v.projectId);
    final q = _query.trim().toLowerCase();
    final text = q.isEmpty ||
        [p?.name, p?.client, p?.code, v.technician, v.motive, v.label]
            .any((f) => f != null && f.toLowerCase().contains(q));
    if (!text) return false;
    if (_technician != null && v.technician != _technician) return false;
    final range = _range;
    if (range != null) {
      // Fecha de la visita: la de inicio o, si no ha iniciado, la programada.
      final d = v.startedAt ?? v.scheduledAt;
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(range.start) || day.isAfter(range.end)) return false;
    }
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
        final isSupervisor = state.role == UserRole.supervisor;
        final filters = isAdmin
            ? _adminFilters
            : isSupervisor
                ? _supervisorFilters
                : _fieldFilters;
        final all = store.visits.where((v) => !mine || v.technician == state.userName).toList();
        final visits = all.where(_matches).toList();
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
              if (isAdmin || isSupervisor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: AppSearchField(
                    hint: 'Buscar proyecto, cliente, técnico o motivo…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              if (isSupervisor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterButton(
                          icon: Icons.engineering_rounded,
                          label: _technician ?? 'Todos los técnicos',
                          active: _technician != null,
                          onTap: () => _pickTechnician(all),
                          onClear: () => setState(() => _technician = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterButton(
                          icon: Icons.calendar_today_rounded,
                          label: _rangeLabel,
                          active: _range != null,
                          onTap: _pickDate,
                          onClear: () => _setRange(null, 'Cualquier fecha'),
                        ),
                      ),
                    ],
                  ),
                ),
              FilterChips(options: filters, selected: _filter, onSelected: (v) => setState(() => _filter = v)),
              const SizedBox(height: 4),
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

  void _setRange(DateTimeRange? range, String label) => setState(() {
        _range = range;
        _rangeLabel = label;
      });

  /// Técnicos que tienen al menos una visita.
  void _pickTechnician(List<FieldVisit> all) {
    final names = all.map((v) => v.technician).toSet().toList()..sort();
    showAppSheet(
      context,
      title: 'Filtrar por técnico',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            for (final name in [null, ...names])
              _option(
                name ?? 'Todos los técnicos',
                selected: _technician == name,
                trailing: name == null ? null : '${all.where((v) => v.technician == name).length}',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _technician = name);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _pickDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <(String, DateTimeRange?)>[
      ('Cualquier fecha', null),
      ('Hoy', DateTimeRange(start: today, end: today)),
      ('Últimos 7 días', DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today)),
      ('Este mes', DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1, 0))),
    ];
    showAppSheet(
      context,
      title: 'Filtrar por fecha',
      subtitle: 'Fecha de inicio de la visita o, si no ha iniciado, la programada',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in presets)
              _option(p.$1, selected: _rangeLabel == p.$1, onTap: () {
                Navigator.pop(context);
                _setRange(p.$2, p.$1);
              }),
            _option('Elegir rango…', selected: false, onTap: () async {
              Navigator.pop(context);
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
                initialDateRange: _range,
              );
              if (picked != null && mounted) {
                _setRange(picked, '${fmtDate(picked.start)} – ${fmtDate(picked.end)}');
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _option(String label, {required bool selected, required VoidCallback onTap, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        color: AppColors.surfaceAlt,
        padding: const EdgeInsets.all(12),
        borderColor: selected ? AppColors.accent.withValues(alpha: 0.45) : null,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(child: Text(label, style: T.h3.copyWith(fontSize: 14))),
            if (trailing != null) Text(trailing, style: T.tiny),
            const SizedBox(width: 8),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 19, color: selected ? AppColors.accent : AppColors.textMuted),
          ],
        ),
      ),
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

/// Botón de filtro: muestra el valor elegido y permite quitarlo.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: active ? AppColors.accent.withValues(alpha: 0.45) : null,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 15, color: active ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: T.small.copyWith(color: active ? AppColors.textPrimary : AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: active ? onClear : onTap,
            child: Icon(active ? Icons.close_rounded : Icons.expand_more_rounded,
                size: 17, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
