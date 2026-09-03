import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../main.dart';
import '../documents/documents_screen.dart';
import '../findings/finding_form_screen.dart';
import '../measurements/measurement_form_screen.dart';
import '../photos/camera_capture_screen.dart';
import '../videos/video_record_screen.dart';

/// Captura rápida: permite capturar en el orden que el técnico necesite.
void showQuickCapture(BuildContext context) {
  final project = Mock.active;

  showAppSheet(
    context,
    title: 'Captura rápida',
    subtitle: '${project.name} · Visita VIS-001 en curso',
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.42,
              children: [
                _CaptureTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Fotografía',
                  hint: '2 obligatorias pendientes',
                  color: AppColors.accent,
                  onTap: () {
                    Navigator.pop(context);
                    push(
                      context,
                      CameraCaptureScreen(
                        slotTitle: 'Transformador 01 – placa de datos',
                        groupCode: '3.3',
                        groupTitle: 'Acometida, Medidor y Transformador',
                      ),
                      fullscreenDialog: true,
                    );
                  },
                ),
                _CaptureTile(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  hint: 'Recorrido o dron',
                  color: AppColors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    push(context, const VideoRecordScreen(), fullscreenDialog: true);
                  },
                ),
                _CaptureTile(
                  icon: Icons.electric_bolt_rounded,
                  label: 'Medición',
                  hint: 'Tensión / corriente',
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.pop(context);
                    push(context, const MeasurementFormScreen(), fullscreenDialog: true);
                  },
                ),
                _CaptureTile(
                  icon: Icons.report_problem_rounded,
                  label: 'Hallazgo',
                  hint: 'Registrar incidencia',
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(context);
                    push(context, const FindingFormScreen(), fullscreenDialog: true);
                  },
                ),
                _CaptureTile(
                  icon: Icons.upload_file_rounded,
                  label: 'Documento',
                  hint: 'PDF, DWG, XLSX…',
                  color: AppColors.violet,
                  onTap: () {
                    Navigator.pop(context);
                    push(context, const DocumentsScreen());
                  },
                ),
                _CaptureTile(
                  icon: Icons.mic_rounded,
                  label: 'Nota de voz',
                  hint: 'Dictado → texto',
                  color: AppColors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    showAppSnack(context, 'Dictado por voz: función prevista para v2',
                        icon: Icons.auto_awesome_rounded);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const IconBadge(Icons.auto_awesome_rounded, color: AppColors.accent, size: 34),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Captura en el orden que necesites. La app clasifica cada evidencia en su sección y sigue marcando los pendientes.',
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
  );
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBadge(icon, color: color, size: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.h3),
              const SizedBox(height: 2),
              Text(hint, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}
