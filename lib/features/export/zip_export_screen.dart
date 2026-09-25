import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/export_service.dart';
import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';

/// Exportación del proyecto a un ZIP con la estructura de carpetas de
/// "Instrucciones de llenado" y nombres de archivo automáticos.
class ZipExportScreen extends StatefulWidget {
  const ZipExportScreen({super.key, required this.project});
  final SurveyProject project;

  @override
  State<ZipExportScreen> createState() => _ZipExportScreenState();
}

class _ZipExportScreenState extends State<ZipExportScreen> {
  final _store = SurveyStore.instance;
  late final _service = ExportService(_store);
  late ExportPlan _plan = _service.plan(widget.project);
  final _open = <String>{};
  File? _zip;
  bool _working = false;

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _plan = _service.plan(widget.project);
    });
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/exportaciones');
      final zip = await _service.writeZip(_plan, dir);
      if (!mounted) return;
      setState(() => _zip = zip);
      showAppSnack(context, 'ZIP generado · ${fmtBytes(zip.lengthSync())}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    } catch (e) {
      if (mounted) showAppSnack(context, 'No se pudo generar el ZIP: $e', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final zip = _zip;
    if (zip == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(zip.path, mimeType: 'application/zip')],
      subject: _plan.zipName,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final open = _store.visitsOf(widget.project.id).where((v) => v.started && !v.finished).toList();
    final byFolder = <String, List<ExportEntry>>{};
    for (final e in _plan.entries) {
      final i = e.path.lastIndexOf('/');
      byFolder.putIfAbsent(i < 0 ? '' : e.path.substring(0, i), () => []).add(e);
    }

    return DetailScaffold(
      title: 'Exportar proyecto',
      subtitle: widget.project.name,
      bottomBar: Builder(
        builder: (btnCtx) => Row(
          children: [
            Expanded(
              child: AppButton(
                _working ? 'Generando…' : _zip == null ? 'Generar ZIP' : 'Generar de nuevo',
                icon: Icons.folder_zip_rounded,
                kind: _zip == null ? AppButtonKind.primary : AppButtonKind.secondary,
                expand: true,
                onPressed: _working ? null : _generate,
              ),
            ),
            if (_zip != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('Compartir',
                    icon: Icons.ios_share_rounded, expand: true, onPressed: () => _share(btnCtx)),
              ),
            ],
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GlassCard(
            child: Row(
              children: [
                const IconBadge(Icons.folder_zip_rounded, color: AppColors.violet, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_plan.zipName, style: T.small.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${_plan.fileCount} archivos · ${fmtBytes(_plan.totalBytes)} · ${_plan.folders.length} carpetas',
                          style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (open.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              '${open.map((v) => v.label).join(', ')} sigue en captura: se exporta lo registrado hasta ahora.',
              icon: Icons.pending_actions_rounded,
              color: AppColors.warning,
            ),
          ],
          if (_zip != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              'Listo. Compártelo por AirDrop, WhatsApp o guárdalo en Archivos para subirlo a Drive.',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
          ],
          const SizedBox(height: 20),
          SectionLabel(_plan.root),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final folder in _plan.folders) _folderRow(folder, byFolder[folder] ?? const []),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Las carpetas y los nombres se generan solos a partir de la plantilla: el técnico no crea '
            'carpetas ni renombra archivos. Los CSV de "05 Reporte" incluyen respuestas, mediciones y '
            'metadatos de cada evidencia (hora, GPS, usuario e ID interno).',
            style: T.tiny,
          ),
        ],
      ),
    );
  }

  Widget _folderRow(String folder, List<ExportEntry> files) {
    final depth = '/'.allMatches(folder).length;
    final name = folder.split('/').last;
    final isOpen = _open.contains(folder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: files.isEmpty ? null : () => setState(() => isOpen ? _open.remove(folder) : _open.add(folder)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.0 + depth * 18, 9, 14, 9),
            child: Row(
              children: [
                Icon(files.isEmpty ? Icons.folder_outlined : Icons.folder_rounded,
                    size: 17, color: files.isEmpty ? AppColors.textMuted : AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: T.small.copyWith(color: files.isEmpty ? AppColors.textMuted : AppColors.textPrimary)),
                ),
                if (files.isNotEmpty) ...[
                  Text('${files.length}', style: T.tiny),
                  Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        ),
        if (isOpen)
          for (final f in files)
            Padding(
              padding: EdgeInsets.fromLTRB(42.0 + depth * 18, 3, 14, 5),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f.path.split('/').last,
                        style: T.mono.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                  Text(fmtBytes(f.size), style: T.tiny),
                ],
              ),
            ),
      ],
    );
  }
}

