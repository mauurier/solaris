import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'finding_form_screen.dart';

class FindingsScreen extends StatefulWidget {
  const FindingsScreen({super.key});

  @override
  State<FindingsScreen> createState() => _FindingsScreenState();
}

class _FindingsScreenState extends State<FindingsScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final list = switch (_filter) {
      'Críticos' => Mock.findings.where((f) => f.severity == Severity.critica).toList(),
      'Abiertos' => Mock.findings.where((f) => f.status == FindingStatus.abierto).toList(),
      'Cerrados' => Mock.findings.where((f) => f.status == FindingStatus.cerrado).toList(),
      _ => Mock.findings,
    };

    return DetailScaffold(
      title: '07 Hallazgos',
      subtitle: '${Mock.findings.length} registrados · 2 críticos',
      bottomBar: AppButton(
        'Registrar hallazgo',
        icon: Icons.add_rounded,
        expand: true,
        onPressed: () => push(context, const FindingFormScreen(), fullscreenDialog: true),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: GlassCard(
              child: Row(
                children: Severity.values.map((s) {
                  final n = Mock.findings.where((f) => f.severity == s).length;
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(height: 8),
                        Text('$n', style: T.h2),
                        const SizedBox(height: 2),
                        Text(s.label, style: T.tiny),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          FilterChips(
            options: const ['Todos', 'Críticos', 'Abiertos', 'Cerrados'],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Sin hallazgos',
                    message: 'No hay hallazgos con este filtro.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Finding f) {
    return GlassCard(
      onTap: () => push(context, FindingFormScreen(finding: f)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: f.severity.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: f.severity.color.withValues(alpha: 0.3)),
                ),
                child: Text(f.id,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: f.severity.color)),
              ),
              const SizedBox(width: 8),
              StatusPill(f.severity.label, color: f.severity.color, dense: true),
              const Spacer(),
              StatusPill(f.status.label, color: f.status.color, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(f.description, style: T.body.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(f.category, style: T.tiny),
              const SizedBox(width: 12),
              const Icon(Icons.place_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Expanded(child: Text(f.location, style: T.tiny, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 74,
                height: 34,
                child: Stack(
                  children: List.generate(
                    f.evidences.clamp(0, 3),
                    (i) => Positioned(
                      left: i * 20.0,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: PhotoThumb(seed: f.id.hashCode + i, radius: 8),
                      ),
                    ),
                  ),
                ),
              ),
              Text('${f.evidences} evidencias', style: T.tiny),
              const Spacer(),
              Text(f.date, style: T.tiny),
            ],
          ),
        ],
      ),
    );
  }
}
