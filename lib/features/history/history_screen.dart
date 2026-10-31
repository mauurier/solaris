import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/history.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/home_shell.dart';
import 'history_text.dart';

/// Quién cambió qué y cuándo, según el registro de Solaris. Con [project],
/// sólo lo de ese proyecto; sin él, todo lo que el usuario puede ver (el
/// admin, también cuentas, plantillas y catálogos). Necesita conexión.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.project});
  final SurveyProject? project;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _page = 50;

  /// Filtro → tablas de Solaris.
  static const _filters = <String, Set<String>?>{
    'Todo': null,
    'Visitas': {'visita', 'respuesta'},
    'Evidencias': {'evidencia', 'documento'},
    'Revisión': {'revision', 'correccion'},
    'Proyecto': {'proyecto', 'proyecto_tecnico'},
  };

  String _filter = 'Todo';
  final _entries = <HistoryEntry>[];
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries.clear();
        _done = false;
      }
    });
    try {
      final page = await historySource.page(
        projectId: widget.project?.id,
        tables: _filters[_filter],
        offset: _entries.length,
        limit: _page,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _done = page.length < _page;
      });
    } on HistoryError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _subtitle {
    if (widget.project case final p?) return '${p.code} · ${p.name}';
    return AppState.instance.role == UserRole.admin ? 'Toda la actividad' : 'Actividad de tus proyectos';
  }

  @override
  Widget build(BuildContext context) {
    final days = <String, List<HistoryEvent>>{};
    for (final (e, event) in describeHistory(_entries)) {
      days.putIfAbsent(_day(e.at), () => []).add(event);
    }

    return DetailScaffold(
      title: 'Historial',
      subtitle: _subtitle,
      child: Column(
        children: [
          FilterChips(
            options: _filters.keys.toList(),
            selected: _filter,
            onSelected: (v) {
              setState(() => _filter = v);
              _load(reset: true);
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  if (_error != null) ...[
                    InfoBanner('No se pudo cargar el historial. $_error',
                        icon: Icons.cloud_off_rounded, color: AppColors.warning),
                    const SizedBox(height: 14),
                  ],
                  if (_entries.isEmpty && _loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_entries.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Sin actividad',
                        message: 'Aquí aparecen los cambios cuando se sincronizan con Solaris.',
                      ),
                    ),
                  for (final MapEntry(key: day, value: rows) in days.entries) ...[
                    SectionLabel(day),
                    GlassCard(
                      child: Column(
                        children: [
                          for (var j = 0; j < rows.length; j++)
                            TimelineRow(event: rows[j], isLast: j == rows.length - 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_entries.isNotEmpty && !_done)
                    Center(
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : TextButton(onPressed: _load, child: const Text('Ver más')),
                    ),
                  const SizedBox(height: 8),
                  const GlassCard(
                    color: AppColors.surfaceAlt,
                    child: Row(
                      children: [
                        IconBadge(Icons.verified_user_rounded, color: AppColors.teal, size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Solaris registra cada cambio con usuario, fecha y hora en cuanto se sincroniza.',
                            style: T.tiny,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  static String _day(DateTime at) {
    final now = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'Hoy';
    if (d == today.subtract(const Duration(days: 1))) return 'Ayer';
    return fmtDate(at);
  }
}
