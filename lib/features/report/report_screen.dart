import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/formatting.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';

/// Genera el reporte PDF de la visita en el teléfono (sin conexión) y lo
/// comparte con el menú del sistema.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.visit});
  final FieldVisit visit;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _store = SurveyStore.instance;
  late final _service = ReportService(_store);
  File? _pdf;
  bool _working = false;
  String _progress = '';

  FieldVisit get v => widget.visit;

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _progress = 'Preparando…';
    });
    try {
      final bytes = await _service.build(v, onProgress: (done, total) {
        if (mounted) setState(() => _progress = 'Preparando fotos $done de $total…');
      });
      final dir = Directory('${(await getTemporaryDirectory()).path}/reportes');
      await dir.create(recursive: true);
      final file = File('${dir.path}/${_service.fileName(v)}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _pdf = file);
      showAppSnack(context, 'Reporte generado · ${fmtBytes(bytes.length)}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    } catch (e) {
      if (mounted) showAppSnack(context, 'No se pudo generar el reporte: $e', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final pdf = _pdf;
    if (pdf == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(pdf.path, mimeType: 'application/pdf')],
      subject: _service.fileName(v),
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final project = _store.project(v.projectId);
    final template = _store.templateFor(v);
    final evidence = _store.evidenceOf(v.id);
    final photos = evidence.where((e) => e.kind == EvidenceKind.photo || e.kind == EvidenceKind.signature).length;
    final files = evidence.length - photos;
    final findings = _store.findingsOf(v.id).length;
    final pdf = _pdf;

    return DetailScaffold(
      title: 'Reporte PDF',
      subtitle: '${project?.code ?? ''} · ${v.label}',
      bottomBar: pdf == null
          ? AppButton(
              _working ? _progress : 'Generar PDF',
              icon: Icons.picture_as_pdf_rounded,
              expand: true,
              onPressed: _working ? null : _generate,
            )
          : Builder(
              builder: (buttonContext) => AppButton('Compartir',
                  icon: Icons.ios_share_rounded, expand: true, onPressed: () => _share(buttonContext)),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          if (!v.finished) ...[
            const InfoBanner('La visita sigue abierta: el reporte sale con lo capturado hasta ahora.',
                icon: Icons.edit_note_rounded),
            const SizedBox(height: 14),
          ],
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qué incluye', style: T.h3),
                const SizedBox(height: 10),
                _line(Icons.description_rounded, 'Portada con proyecto, cliente, sitio, equipo y fechas'),
                _line(Icons.summarize_rounded, 'Resumen, avance y hallazgos por severidad'),
                _line(Icons.report_problem_rounded,
                    findings == 1 ? '1 hallazgo con sus fotos' : '$findings hallazgos con sus fotos'),
                _line(Icons.view_list_rounded,
                    '${template.sections.length} secciones de "${template.name}" con cada respuesta'),
                _line(Icons.photo_camera_rounded, '$photos fotos y firmas, reducidas para que el PDF pese poco'),
                if (files > 0)
                  _line(Icons.attach_file_rounded, '$files videos y archivos, listados (completos van en el ZIP)'),
              ],
            ),
          ),
          if (pdf != null) ...[
            const SizedBox(height: 14),
            GlassCard(
              color: AppColors.surfaceAlt,
              child: Row(
                children: [
                  const IconBadge(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_service.fileName(v), style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(fmtBytes(pdf.lengthSync()), style: T.tiny),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _working ? null : _generate, child: const Text('Rehacer')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: T.small)),
          ],
        ),
      );
}
