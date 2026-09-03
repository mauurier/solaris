import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../findings/findings_screen.dart';
import '../measurements/measurements_screen.dart';
import '../photos/photo_sections_screen.dart';
import '../report/report_preview_screen.dart';
import '../shell/home_shell.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.project});
  final Project project;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _corrections = <String>[];

  @override
  Widget build(BuildContext context) {
    final p = widget.project;

    return DetailScaffold(
      title: 'Revisión',
      subtitle: '${p.name} · ${p.id}',
      bottomBar: Row(
        children: [
          Expanded(
            child: AppButton(
              'Solicitar correcciones',
              icon: Icons.assignment_return_rounded,
              kind: AppButtonKind.secondary,
              expand: true,
              onPressed: _requestCorrections,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              'Aprobar',
              icon: Icons.verified_rounded,
              expand: true,
              onPressed: _approve,
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GlassCard(
            child: Row(
              children: [
                ProgressRing(value: p.progress, size: 70, stroke: 6, color: AppColors.teal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENDIENTE DE REVISIÓN',
                          style: T.overline.copyWith(color: AppColors.teal)),
                      const SizedBox(height: 8),
                      Text('Levantamiento completo', style: T.h2),
                      const SizedBox(height: 5),
                      Text('Técnico: ${p.responsible} · Finalizado ${p.lastActivity.toLowerCase()}',
                          style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Revisar por sección'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _reviewRow('Información capturada', '14 campos · sin observaciones',
                    Icons.description_rounded, AppColors.blue, true, null),
                const Divider(indent: 14, endIndent: 14),
                _reviewRow('Evidencia fotográfica', '22 fotografías · 2 pendientes',
                    Icons.photo_camera_rounded, AppColors.accent, false,
                    const PhotoSectionsScreen()),
                const Divider(indent: 14, endIndent: 14),
                _reviewRow('Mediciones eléctricas', '11 registros · 1 faltante',
                    Icons.electric_bolt_rounded, AppColors.warning, false,
                    const MeasurementsScreen()),
                const Divider(indent: 14, endIndent: 14),
                _reviewRow('Hallazgos', '5 registrados · 2 críticos',
                    Icons.report_problem_rounded, AppColors.danger, false, const FindingsScreen()),
                const Divider(indent: 14, endIndent: 14),
                _reviewRow('Reporte generado', 'v1.2 · borrador',
                    Icons.picture_as_pdf_rounded, AppColors.violet, false,
                    ReportPreviewScreen(project: p)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Observaciones del revisor'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                      hintText: 'Comentarios técnicos para el levantamiento…'),
                ),
                const SizedBox(height: 12),
                AppButton('Agregar observación',
                    icon: Icons.add_comment_rounded,
                    kind: AppButtonKind.secondary,
                    compact: true,
                    onPressed: () => showAppSnack(context, 'Observación registrada')),
              ],
            ),
          ),
          if (_corrections.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionLabel('Correcciones solicitadas (${_corrections.length})'),
            GlassCard(
              borderColor: AppColors.danger.withValues(alpha: 0.28),
              child: Column(
                children: _corrections
                    .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment_late_rounded,
                                  size: 16, color: AppColors.danger),
                              const SizedBox(width: 11),
                              Expanded(child: Text(c, style: T.small)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionLabel('Historial de revisión'),
          GlassCard(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  _timeline(Mock.history[i + 4], i == 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String title, String sub, IconData icon, Color color, bool ok, Widget? page) {
    return NavRow(
      dense: true,
      title: title,
      subtitle: sub,
      icon: icon,
      iconColor: color,
      trailing: ok
          ? const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success)
          : const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      onTap: page == null ? null : () => push(context, page),
    );
  }

  Widget _timeline(HistoryEvent e, bool last) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: e.color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: e.color.withValues(alpha: 0.3)),
            ),
            child: Icon(e.icon, size: 13, color: e.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('${e.detail} · ${e.user}', style: T.tiny),
              ],
            ),
          ),
          Text(e.time, style: T.tiny),
        ],
      ),
    );
  }

  void _requestCorrections() {
    final options = [
      'Repetir fotografía del Tablero 03 (ilegible)',
      'Completar medición Fase-Tierra',
      'Agregar número de serie del Tablero 03',
      'Actualizar diagrama unifilar as-built',
    ];
    final selected = <String>{...options.take(2)};

    showAppSheet(
      context,
      title: 'Solicitar correcciones',
      subtitle: 'El proyecto regresará al técnico asignado',
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...options.map((o) {
                final sel = selected.contains(o);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setSheet(() => sel ? selected.remove(o) : selected.add(o)),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.danger.withValues(alpha: 0.07) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: sel ? AppColors.danger.withValues(alpha: 0.35) : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 19,
                            color: sel ? AppColors.danger : AppColors.textMuted,
                          ),
                          const SizedBox(width: 11),
                          Expanded(child: Text(o, style: T.small)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              AppButton(
                'Enviar ${selected.length} correcciones',
                icon: Icons.send_rounded,
                expand: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _corrections
                    ..clear()
                    ..addAll(selected));
                  showAppSnack(context, 'Correcciones enviadas al técnico',
                      icon: Icons.assignment_return_rounded, color: AppColors.danger);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _approve() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar levantamiento'),
        content: const Text(
            'Se generará el reporte final, la estructura de carpetas y el paquete ZIP del proyecto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => widget.project.status = ProjectStatus.aprobado);
              showAppSnack(context, 'Levantamiento aprobado',
                  icon: Icons.verified_rounded, color: AppColors.success);
            },
            child: const Text('Aprobar', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }
}
