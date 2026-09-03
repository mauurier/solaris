import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _scope = 'Empresa';
  String _period = '6 meses';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Estadísticas',
      subtitle: 'Periodo: últimos $_period',
      actions: [
        HeaderIconButton(Icons.tune_rounded, onTap: _filters),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          SegmentedPicker(
            options: const ['Empresa', 'Técnico', 'Proyecto'],
            selected: _scope,
            onSelected: (v) => setState(() => _scope = v),
          ),
          const SizedBox(height: 20),
          if (_scope == 'Empresa') ..._company(),
          if (_scope == 'Técnico') ..._byTechnician(),
          if (_scope == 'Proyecto') ..._byProject(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ empresa
  List<Widget> _company() => [
        Row(
          children: [
            _kpi('12', 'Proyectos activos', AppColors.blue, Icons.folder_rounded),
            const SizedBox(width: 10),
            _kpi('47', 'Cerrados', AppColors.success, Icons.verified_rounded),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _kpi('3', 'Atrasados', AppColors.warning, Icons.timelapse_rounded),
            const SizedBox(width: 10),
            _kpi('8', 'Hallazgos críticos', AppColors.critical, Icons.priority_high_rounded),
          ],
        ),
        const SizedBox(height: 20),
        const SectionLabel('Levantamientos por periodo'),
        GlassCard(
          child: BarChart(
            values: const [6, 9, 7, 12, 10, 14],
            labels: const ['Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago'],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Hallazgos por severidad'),
        GlassCard(
          child: DonutChart(
            segments: [
              ('Crítica', 8, AppColors.sevCritica),
              ('Alta', 14, AppColors.sevAlta),
              ('Media', 21, AppColors.sevMedia),
              ('Baja', 11, AppColors.sevBaja),
            ],
            centerLabel: 'hallazgos',
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Distribución por cliente'),
        GlassCard(
          child: Column(
            children: Mock.clients
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: LinearMeter(
                        label: c.name,
                        value: c.projects / 12,
                        color: AppColors.blue,
                        trailingText: '${c.projects}',
                      ),
                    ))
                .toList(),
          ),
        ),
      ];

  // ------------------------------------------------------------------ técnico
  List<Widget> _byTechnician() => [
        const SectionLabel('Desempeño por técnico'),
        ...Mock.users.where((u) => u.role == UserRole.tecnico && u.active).map((u) {
          final idx = Mock.users.indexOf(u);
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      InitialsAvatar(u.initials, size: 40, color: AppColors.accent),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: T.h3),
                            const SizedBox(height: 3),
                            Text('${u.projects} levantamientos realizados', style: T.tiny),
                          ],
                        ),
                      ),
                      Text('${(4.2 + idx * 0.3).toStringAsFixed(1)} h',
                          style: T.h3.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _mini('${180 + idx * 47}', 'Evidencias'),
                      _mini('${3 - idx.clamp(0, 2)}', 'Pendientes'),
                      _mini('${idx + 1}', 'Correcciones'),
                      _mini('${(4.2 + idx * 0.3).toStringAsFixed(1)} h', 'Prom./hito'),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ];

  // ----------------------------------------------------------------- proyecto
  List<Widget> _byProject() => [
        const SectionLabel('Indicadores por proyecto'),
        ...Mock.projects.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProgressRing(value: p.progress, size: 46, stroke: 4.5, color: p.status.color),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: T.h3),
                              const SizedBox(height: 3),
                              Text('${p.client} · ${p.type}', style: T.tiny),
                            ],
                          ),
                        ),
                        StatusPill(p.status.label, color: p.status.color, dense: true),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _mini('4.7 h', 'Tiempo'),
                        _mini('${(p.progress * 24).round()}', 'Fotos'),
                        _mini('2', 'Videos'),
                        _mini('${p.criticalFindings}', 'Críticos'),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ];

  Widget _kpi(String n, String l, Color c, IconData i) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, size: 16, color: c),
            const SizedBox(height: 12),
            Text(n, style: T.display.copyWith(fontSize: 26)),
            const SizedBox(height: 3),
            Text(l, style: T.tiny),
          ],
        ),
      ),
    );
  }

  Widget _mini(String v, String l) => Expanded(
        child: Column(
          children: [
            Text(v, style: T.h3.copyWith(fontSize: 14)),
            const SizedBox(height: 3),
            Text(l, style: T.tiny),
          ],
        ),
      );

  void _filters() {
    showAppSheet(
      context,
      title: 'Filtrar estadísticas',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Periodo'),
            SegmentedPicker(
              options: const ['30 días', '3 meses', '6 meses', 'Año'],
              selected: _period,
              onSelected: (v) => setState(() => _period = v),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Filtrar por'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Fecha', 'Cliente', 'Técnico', 'Proyecto', 'Estado']
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(f, style: T.small),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            AppButton('Aplicar', expand: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
