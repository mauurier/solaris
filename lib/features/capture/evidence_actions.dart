import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/video_compression.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import 'camera_screen.dart';

/// Acciones de captura ligadas a una pregunta: abren cámara o selector de
/// archivos y guardan el resultado como evidencia de la visita.
class EvidenceActions {
  EvidenceActions._();

  static SurveyStore get _store => SurveyStore.instance;

  static Future<CaptureResult?> _openCamera(BuildContext context, ResolvedQuestion rq, CaptureMode mode) {
    return Navigator.of(context).push<CaptureResult>(
      appRoute(
        CameraScreen(
          title: rq.question.label,
          subtitle: '${rq.code} · ${rq.group.repeatable ? rq.instanceName : rq.section.title}',
          mode: mode,
          hint: rq.question.hint,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  static Future<void> takePhoto(BuildContext context, FieldVisit visit, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, CaptureMode.photo);
    if (r == null) return;
    await _store.addEvidence(
      visit: visit,
      key: rq.key,
      kind: EvidenceKind.photo,
      file: r.file,
      point: r.point,
      capturedAt: r.capturedAt,
      comment: r.comment,
      moveFile: true,
    );
    if (context.mounted) {
      showAppSnack(context, 'Foto guardada · ${rq.question.label}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }

  /// Comprime el video mostrando el avance. Si no se puede, devuelve
  /// [file] tal cual: el video se guarda aunque pese más.
  @visibleForTesting
  static Future<File> compressVideo(BuildContext context, File file) async {
    final progress = ValueNotifier<double>(0);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Comprimiendo video'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: p == 0 ? null : p),
                const SizedBox(height: 10),
                Text(p == 0 ? 'Preparando…' : '${(p * 100).round()} %', style: T.small),
                const SizedBox(height: 4),
                const Text('Así ocupa menos y sube más rápido.', style: T.tiny),
              ],
            ),
          ),
        ),
      ),
    );
    final out = await videoCompressor.compress(file, onProgress: (p) => progress.value = p);
    navigator.pop();
    progress.dispose();
    return out ?? file;
  }

  static Future<void> recordVideo(BuildContext context, FieldVisit visit, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, CaptureMode.video);
    if (r == null || !context.mounted) return;
    final file = await compressVideo(context, r.file);
    if (file.path != r.file.path) await _deleteQuietly(r.file);
    await _store.addEvidence(
      visit: visit,
      key: rq.key,
      kind: EvidenceKind.video,
      file: file,
      point: r.point,
      capturedAt: r.capturedAt,
      moveFile: true,
    );
    if (context.mounted) {
      showAppSnack(context, 'Video guardado', icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }

  /// Importa desde galería o archivos (fotos de dron, capturas de mapa,
  /// termografías). No llevan marca de agua y quedan marcadas como importadas.
  static Future<void> importFiles(BuildContext context, FieldVisit visit, ResolvedQuestion rq, EvidenceKind kind) async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: switch (kind) {
          EvidenceKind.photo => FileType.image,
          EvidenceKind.video => FileType.video,
          _ => FileType.any,
        },
      );
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'No se pudo abrir el selector', color: AppColors.danger);
      return;
    }
    var saved = 0;
    for (final f in picked) {
      final path = f.path;
      if (path == null || !context.mounted) continue;
      final original = File(path);
      // Los videos importados también se comprimen; el original no se toca.
      final file = kind == EvidenceKind.video ? await compressVideo(context, original) : original;
      await _store.addEvidence(
        visit: visit,
        key: rq.key,
        kind: kind,
        file: file,
        originalName: f.name,
        imported: true,
        moveFile: file.path != original.path,
      );
      saved++;
    }
    if (saved > 0 && context.mounted) {
      showAppSnack(context, '$saved archivo${saved == 1 ? '' : 's'} agregado${saved == 1 ? '' : 's'}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }

  /// Foto de un hallazgo: con marca de agua, como las de la plantilla.
  static Future<void> takeFindingPhoto(BuildContext context, FieldVisit visit, VisitFinding finding) async {
    final r = await Navigator.of(context).push<CaptureResult>(
      appRoute(
        CameraScreen(
          title: 'Hallazgo ${finding.code}',
          subtitle: '${finding.category.label} · ${finding.severity.label}',
          mode: CaptureMode.photo,
          hint: finding.description,
        ),
        fullscreenDialog: true,
      ),
    );
    if (r == null) return;
    await _store.addEvidence(
      visit: visit,
      findingId: finding.id,
      kind: EvidenceKind.photo,
      file: r.file,
      point: r.point,
      capturedAt: r.capturedAt,
      comment: r.comment,
      moveFile: true,
    );
    if (context.mounted) {
      showAppSnack(context, 'Foto agregada a ${finding.code}', icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }

  /// Fotos del hallazgo desde la galería (p. ej. termografías).
  static Future<void> importFindingPhotos(BuildContext context, FieldVisit visit, VisitFinding finding) async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(type: FileType.image);
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'No se pudo abrir el selector', color: AppColors.danger);
      return;
    }
    for (final f in picked) {
      final path = f.path;
      if (path == null) continue;
      await _store.addEvidence(
        visit: visit,
        findingId: finding.id,
        kind: EvidenceKind.photo,
        file: File(path),
        originalName: f.name,
        imported: true,
      );
    }
  }

  /// "Reemplazar fotografía": abre la cámara y sustituye el archivo.
  static Future<void> replacePhoto(BuildContext context, Evidence e, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, e.kind == EvidenceKind.video ? CaptureMode.video : CaptureMode.photo);
    if (r == null || !context.mounted) return;
    var file = r.file;
    if (e.kind == EvidenceKind.video) {
      file = await compressVideo(context, r.file);
      if (file.path != r.file.path) await _deleteQuietly(r.file);
    }
    await _store.replaceEvidenceFile(e, file, point: r.point, capturedAt: r.capturedAt, moveFile: true);
  }

  /// El original de la cámara, ya comprimido, sobra; si no se puede borrar
  /// el sistema limpia sus temporales.
  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Temporal del sistema.
    }
  }
}
