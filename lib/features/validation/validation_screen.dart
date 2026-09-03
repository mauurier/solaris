import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../report/report_preview_screen.dart';
import '../shell/home_shell.dart';
import '../sync/sync_screen.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key, required this.project, required this.progress});
  final Project project;
  final double progress;

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final _pendings = Mock.pendings;

  List<PendingItem> get _blocking =>
      _pendings.where((p) => p.blocking && !p.justified).toList();
  List<PendingItem> get _optional => _pendings.where((p) => !p.blocking).toList();
  List<PendingItem> get _justified => _pendings.where((p) => p.blocking && p.justified).toList();

  bool get _canClose => _blocking.isEmpty;

  @override
  Widget build(BuildContext context) {
    final isSupervisor = AppState.instance.role != UserRole.tecnico;

    return DetailScaffold(
      title: 'Validación del levantamiento',
      subtitle: '${widget.project.name} · VIS-001',
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_canClose)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 13, color: AppColors.danger),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${_blocking.length} pendientes obligatorios impiden cerrar la visita',
                      style: T.tiny.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          AppButton(
            'Finalizar visita',
            icon: Icons.flag_rounded,
            expand: true,
            onPressed: _canClose ? _finish : null,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
        children: [
          GlassCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _canClose
                  ? [const Color(0xFF14211A), const Color(0xFF12161E)]
                  : [const Color(0xFF201519), const Color(0xFF12161E)],
            ),
            borderColor: (_canClose ? AppColors.success : AppColors.danger).withValues(alpha: 0.28),
            child: Row(
              children: [
                ProgressRing(
                  value: widget.progress,
                  size: 82,
                  stroke: 7,
                  color: _canClose ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LEVANTAMIENTO', style: T.overline),
                      const SizedBox(height: 8),
                      Text(
                        _canClose ? 'Listo para cerrar' : 'Faltan datos obligatorios',
                        style: T.h2,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _canClose
                            ? 'Todos los requisitos de la plantilla se cumplen.'
                            : 'Resuelve o justifica los pendientes obligatorios.',
                        style: T.tiny,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_blocking.isNotEmpty) ...[
            SectionLabel('Pendientes obligatorios (${_blocking.length})'),
            ..._blocking.map((p) => _pendingCard(p, AppColors.danger, isSupervisor)),
            const SizedBox(height: 12),
          ],
          if (_justified.isNotEmpty) ...[
            SectionLabel('Justificados por el supervisor (${_justified.length})'),
            ..._justified.map((p) => _pendingCard(p, AppColors.warning, false)),
            const SizedBox(height: 12),
          ],
          SectionLabel('Pendientes opcionales (${_optional.length})'),
          ..._optional.map((p) => _pendingCard(p, AppColors.textMuted, false)),
          const SizedBox(height: 12),
          const SectionLabel('Resumen de la captura'),
          GlassCard(
            child: Column(
              children: [
                _summaryRow(Icons.description_rounded, 'Formularios', '14 de 14 campos', 1.0),
                const Divider(),
                _summaryRow(Icons.photo_camera_rounded, 'Fotografías', '22 de 24 evidencias', 0.92),
                const Divider(),
                _summaryRow(Icons.videocam_rounded, 'Videos', '2 de 2 requeridos', 1.0),
                const Divider(),
                _summaryRow(Icons.electric_bolt_rounded, 'Mediciones', '11 de 13 registros', 0.85),
                const Divider(),
                _summaryRow(Icons.precision_manufacturing_rounded, 'Equipos', '7 de 8 completos', 0.87),
                const Divider(),
                _summaryRow(Icons.report_problem_rounded, 'Hallazgos', '5 registrados', 1.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(PendingItem p, Color color, bool canJustify) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassCard(
        padding: const EdgeInsets.all(13),
        borderColor: color == AppColors.textMuted ? null : color.withValues(alpha: 0.25),
        color: color == AppColors.textMuted
            ? AppColors.surface
            : color.withValues(alpha: 0.04),
        child: Row(
          children: [
            Icon(
              p.justified
                  ? Icons.gpp_good_rounded
                  : (p.blocking ? Icons.error_outline_rounded : Icons.info_outline_rounded),
              size: 18,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: T.body.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(p.section, style: T.tiny),
                ],
              ),
            ),
            if (canJustify)
              GestureDetector(
                onTap: () => _justify(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Justificar',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData i, String title, String detail, double v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(i, size: 16, color: v >= 1 ? AppColors.success : AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(detail, style: T.tiny),
              ],
            ),
          ),
          Text('${(v * 100).round()} %',
              style: T.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: v >= 1 ? AppColors.success : AppColors.warning)),
        ],
      ),
    );
  }

  void _justify(PendingItem p) {
    showAppSheet(
      context,
      title: 'Justificar pendiente',
      subtitle: p.title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Motivo de la justificación', required: true),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: 'Ej. Acceso restringido al transformador durante la visita'),
            ),
            const SizedBox(height: 18),
            AppButton(
              'Autorizar cierre con pendiente',
              icon: Icons.gpp_good_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => p.justified = true);
                showAppSnack(context, 'Pendiente justificado por el supervisor',
                    icon: Icons.check_circle_rounded, color: AppColors.warning);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    showAppSheet(
      context,
      title: 'Visita finalizada',
      subtitle: 'Hora de finalización 13:26 · GPS registrado',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              color: AppColors.surfaceAlt,
              child: Column(
                children: [
                  Row(
                    children: [
                      const IconBadge(Icons.check_circle_rounded, color: AppColors.success, size: 40),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Levantamiento cerrado', style: T.h3),
                            SizedBox(height: 3),
                            Text('La información quedó lista para sincronizar', style: T.tiny),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  KeyValue('Duración', '4 h 44 min'),
                  KeyValue('Evidencias', '22 fotos · 2 videos · 5 documentos'),
                  KeyValue('Estado', 'Pendiente de sincronización',
                      valueColor: AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              'Sincronizar ahora',
              icon: Icons.cloud_upload_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                push(context, const SyncScreen());
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              'Generar borrador del reporte',
              icon: Icons.picture_as_pdf_rounded,
              kind: AppButtonKind.secondary,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                push(context, ReportPreviewScreen(project: widget.project));
              },
            ),
          ],
        ),
      ),
    );
  }
}
