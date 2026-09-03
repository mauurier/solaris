import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _docs = List<DocItem>.from(Mock.documents);

  @override
  Widget build(BuildContext context) {
    final missing = Mock.requiredDocs
        .where((c) => !_docs.any((d) => d.category == c))
        .toList();

    return DetailScaffold(
      title: '02 Documentación Existente',
      subtitle: '${_docs.length} archivos · ${missing.length} pendientes',
      bottomBar: AppButton(
        'Agregar documento',
        icon: Icons.upload_file_rounded,
        expand: true,
        onPressed: _addSheet,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          if (missing.isNotEmpty) ...[
            const SectionLabel('Documentos solicitados por la plantilla'),
            GlassCard(
              borderColor: AppColors.warning.withValues(alpha: 0.28),
              color: AppColors.warning.withValues(alpha: 0.04),
              child: Column(
                children: [
                  for (var i = 0; i < missing.length; i++) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              size: 17, color: AppColors.warning),
                          const SizedBox(width: 11),
                          Expanded(child: Text(missing[i], style: T.body.copyWith(fontSize: 14))),
                          const StatusPill('Opcional', color: AppColors.textMuted, dense: true),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SectionLabel('Archivos cargados'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _docs.length; i++) ...[
                  if (i > 0) const Divider(indent: 14, endIndent: 14),
                  _docRow(_docs[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Row(
              children: [
                const IconBadge(Icons.drive_file_rename_outline_rounded,
                    color: AppColors.violet, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nomenclatura automática', style: T.h3),
                      const SizedBox(height: 4),
                      Text('RECIBO_CFE_TRUPER_MONTERREY.pdf',
                          style: T.mono.copyWith(color: AppColors.accent)),
                      const SizedBox(height: 4),
                      const Text('Sin caracteres especiales · sin duplicados', style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docRow(DocItem d) {
    return NavRow(
      dense: true,
      title: d.name,
      subtitle: '${d.category} · ${d.size} · ${d.date}',
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: d.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: d.color.withValues(alpha: 0.24)),
        ),
        child: Text(
          d.ext.toUpperCase(),
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: d.color),
        ),
      ),
      onTap: () => showAppSnack(context, 'Vista previa no disponible en el prototipo'),
    );
  }

  void _addSheet() {
    showAppSheet(
      context,
      title: 'Agregar documento',
      subtitle: 'Se asociará al proyecto y a su categoría',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Categoría', required: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...Mock.requiredDocs,
                'Ingeniería existente',
                'Expediente técnico',
                'Cámara térmica',
                'Otro',
              ].map((c) {
                final sel = c == 'Plano estructural';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: sel ? AppColors.accent : AppColors.textSecondary)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Origen del archivo'),
            Row(
              children: [
                Expanded(child: _source(Icons.folder_open_rounded, 'Archivos', AppColors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _source(Icons.photo_library_rounded, 'Galería', AppColors.teal)),
                const SizedBox(width: 10),
                Expanded(child: _source(Icons.document_scanner_rounded, 'Escanear', AppColors.violet)),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Formatos: PDF, DOC/DOCX, XLS/XLSX, DWG, DXF, imágenes y archivos de cámara térmica.',
                      style: T.tiny,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              'Adjuntar documento',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _docs.add(DocItem(
                      name: 'PLANO_ESTRUCTURAL_CEDIS_MTY',
                      category: 'Plano estructural',
                      size: '2.7 MB',
                      ext: 'pdf',
                      date: 'Hoy · 13:12',
                    )));
                showAppSnack(context, 'Documento agregado y renombrado automáticamente',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _source(IconData i, String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(i, size: 21, color: c),
          const SizedBox(height: 8),
          Text(label, style: T.tiny.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
