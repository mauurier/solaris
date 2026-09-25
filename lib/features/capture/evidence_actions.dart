import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
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

  static Future<void> recordVideo(BuildContext context, FieldVisit visit, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, CaptureMode.video);
    if (r == null) return;
    await _store.addEvidence(
      visit: visit,
      key: rq.key,
      kind: EvidenceKind.video,
      file: r.file,
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
      if (path == null) continue;
      await _store.addEvidence(
        visit: visit,
        key: rq.key,
        kind: kind,
        file: File(path),
        originalName: f.name,
        imported: true,
      );
      saved++;
    }
    if (saved > 0 && context.mounted) {
      showAppSnack(context, '$saved archivo${saved == 1 ? '' : 's'} agregado${saved == 1 ? '' : 's'}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }

  /// "Reemplazar fotografía": abre la cámara y sustituye el archivo.
  static Future<void> replacePhoto(BuildContext context, Evidence e, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, e.kind == EvidenceKind.video ? CaptureMode.video : CaptureMode.photo);
    if (r == null) return;
    await _store.replaceEvidenceFile(e, r.file, point: r.point, capturedAt: r.capturedAt, moveFile: true);
  }
}
