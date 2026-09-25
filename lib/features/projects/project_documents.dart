import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';

/// Abre el selector de archivos del sistema (PDF, DWG, XLSX, imágenes…).
Future<List<PickedDocument>> pickDocuments(BuildContext context, String category) async {
  try {
    final files = await FilePicker.pickFiles(type: FileType.any);
    return [
      for (final f in files)
        if (f.path != null) PickedDocument(category: category, file: File(f.path!), name: f.name),
    ];
  } catch (_) {
    if (context.mounted) showAppSnack(context, 'No se pudo abrir el selector de archivos', color: AppColors.danger);
    return const [];
  }
}

IconData docIcon(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'jpg' || 'jpeg' || 'png' || 'heic' => Icons.image_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'dwg' || 'dxf' || 'skp' => Icons.architecture_rounded,
    'doc' || 'docx' => Icons.article_rounded,
    _ => Icons.insert_drive_file_rounded,
  };
}

/// Fila de categoría con sus archivos y el botón para agregar.
class DocCategoryCard extends StatelessWidget {
  const DocCategoryCard({
    super.key,
    required this.category,
    required this.files,
    required this.onAdd,
    this.onRemove,
    this.onOpen,
  });

  final DocCategory category;
  final List<({String name, int size})> files;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;
  final ValueChanged<int>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        borderColor: files.isNotEmpty ? AppColors.success.withValues(alpha: 0.22) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.label, style: T.h3.copyWith(fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(category.hint, style: T.tiny),
                    ],
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.accent),
                    tooltip: 'Agregar',
                  ),
              ],
            ),
            for (var i = 0; i < files.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: onOpen == null ? null : () => onOpen!(i),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Row(
                    children: [
                      Icon(docIcon(files[i].name), size: 18, color: AppColors.violet),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(files[i].name,
                            style: T.small.copyWith(color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                      ),
                      Text(fmtBytes(files[i].size), style: T.tiny),
                      if (onRemove != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onRemove!(i),
                          icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Documentos ya guardados de un proyecto, agrupados por categoría.
class ProjectDocumentsPanel extends StatelessWidget {
  const ProjectDocumentsPanel({super.key, required this.project, required this.canEdit});
  final SurveyProject project;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final docs = store.documentsOf(project.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final cat in DocCategory.all)
          Builder(builder: (context) {
            final mine = docs.where((d) => d.category == cat.id).toList();
            return DocCategoryCard(
              category: cat,
              files: [for (final d in mine) (name: d.originalName, size: d.size)],
              onAdd: canEdit
                  ? () async {
                      final picked = await pickDocuments(context, cat.id);
                      for (final p in picked) {
                        await store.addDocument(project.id, cat.id, p.file, p.name);
                      }
                      if (picked.isNotEmpty && context.mounted) {
                        showAppSnack(context, '${picked.length} documento(s) agregado(s) a ${cat.label}',
                            icon: Icons.check_circle_rounded, color: AppColors.success);
                      }
                    }
                  : null,
              onOpen: (i) => SharePlus.instance
                  .share(ShareParams(files: [XFile(store.files.file(mine[i].path).path)])),
              onRemove: canEdit
                  ? (i) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('¿Quitar documento?'),
                          content: Text(mine[i].originalName),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Quitar', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await store.removeDocument(mine[i]);
                    }
                  : null,
            );
          }),
      ],
    );
  }
}
