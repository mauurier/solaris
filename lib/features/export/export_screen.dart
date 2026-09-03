import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.project});
  final Project project;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _include = <String, bool>{
    'Documentos': true,
    'Fotografías': true,
    'Videos': true,
    'Reporte PDF': true,
    'Mediciones (CSV)': true,
    'Evidencias adicionales': true,
    'CAD y modelos 3D': false,
  };
  bool _exporting = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Exportar y compartir',
      subtitle: widget.project.name,
      bottomBar: AppButton(
        _exporting ? 'Generando ZIP…' : 'Generar y compartir ZIP',
        icon: Icons.folder_zip_rounded,
        expand: true,
        onPressed: _exporting ? null : _export,
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
                      Text('TRUPER_MONTERREY_LEVANTAMIENTO_2026-08-16.zip',
                          style: T.small.copyWith(
                              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Tamaño estimado: 462 MB · 38 archivos', style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_exporting) ...[
            const SizedBox(height: 14),
            GlassCard(
              child: LinearMeter(
                label: 'Comprimiendo evidencia…',
                value: _progress,
                color: AppColors.violet,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionLabel('Contenido a incluir'),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: _include.keys.map((k) {
                final i = _include.keys.toList().indexOf(k);
                return Column(
                  children: [
                    if (i > 0) const Divider(),
                    Row(
                      children: [
                        Expanded(child: Text(k, style: T.body.copyWith(fontSize: 13.5))),
                        Transform.scale(
                          scale: 0.78,
                          child: Switch(
                            value: _include[k]!,
                            onChanged: (v) => setState(() => _include[k] = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Estructura generada automáticamente'),
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: Mock.folderTree.map((n) {
                final depth = n.$1;
                final name = n.$2;
                final kind = n.$3;
                final isFolder = kind == 'folder';
                return Padding(
                  padding: EdgeInsets.only(left: depth * 14.0, bottom: 7),
                  child: Row(
                    children: [
                      Icon(
                        isFolder ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                        size: 14,
                        color: isFolder
                            ? (depth == 0 ? AppColors.accent : AppColors.violet)
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: T.mono.copyWith(
                            color: depth == 0 ? AppColors.accent : AppColors.textSecondary,
                            fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Compartir'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                NavRow(
                  dense: true,
                  title: 'Compartir con apps del dispositivo',
                  subtitle: 'AirDrop, Mensajes, Correo, WhatsApp…',
                  icon: Icons.ios_share_rounded,
                  iconColor: AppColors.blue,
                  onTap: _shareSheet,
                ),
                const Divider(indent: 14, endIndent: 14),
                NavRow(
                  dense: true,
                  title: 'Guardar en Archivos',
                  subtitle: 'Almacenamiento local del dispositivo',
                  icon: Icons.folder_open_rounded,
                  iconColor: AppColors.violet,
                  onTap: () => showAppSnack(context, 'Guardado en Archivos (prototipo)'),
                ),
                const Divider(indent: 14, endIndent: 14),
                NavRow(
                  dense: true,
                  title: 'Servicios en la nube',
                  subtitle: 'Google Drive, OneDrive, SharePoint (v2)',
                  icon: Icons.cloud_rounded,
                  iconColor: AppColors.textMuted,
                  trailing: const StatusPill('Próximamente', color: AppColors.textMuted, dense: true),
                  onTap: () => showAppSnack(context, 'Integración prevista para v2',
                      icon: Icons.auto_awesome_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _progress = 0;
    });
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _progress = i / 10);
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    _shareSheet();
  }

  void _shareSheet() {
    showAppSheet(
      context,
      title: 'Compartir proyecto',
      subtitle: 'TRUPER_MONTERREY_LEVANTAMIENTO_2026-08-16.zip · 462 MB',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _shareTile(Icons.wifi_tethering_rounded, 'AirDrop', AppColors.blue),
                  _shareTile(Icons.mail_rounded, 'Correo', AppColors.teal),
                  _shareTile(Icons.chat_rounded, 'Mensajes', AppColors.success),
                  _shareTile(Icons.cloud_upload_rounded, 'Drive', AppColors.warning),
                  _shareTile(Icons.more_horiz_rounded, 'Más', AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            NavRow(
              dense: true,
              title: 'Sólo el reporte PDF',
              subtitle: 'REPORTE_TRUPER_MTY_v1.2.pdf · 8.4 MB',
              icon: Icons.picture_as_pdf_rounded,
              iconColor: AppColors.danger,
              onTap: () => Navigator.pop(context),
            ),
            NavRow(
              dense: true,
              title: 'Sólo fotografías',
              subtitle: '22 archivos · 94 MB',
              icon: Icons.photo_library_rounded,
              iconColor: AppColors.accent,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareTile(IconData i, String label, Color c) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.withValues(alpha: 0.25)),
            ),
            child: Icon(i, color: c, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: T.tiny),
        ],
      ),
    );
  }
}
