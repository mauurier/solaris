import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/location_service.dart';
import '../../core/services/video_processing.dart';
import '../../core/services/watermark.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import 'camera_screen.dart';
import 'photo_text_editor.dart';

/// Acciones de captura ligadas a una pregunta: abren cámara o selector de
/// archivos y guardan el resultado como evidencia de la visita.
///
/// Todas las fotos y videos llevan la marca de agua con fecha, hora,
/// coordenadas y el enlace de Maps: los de la cámara con la ubicación de la
/// toma y los de la galería con la ubicación del momento en que se suben.
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

  /// Muestra un diálogo de avance mientras corre [task]. El diálogo no se
  /// puede cerrar a mano; se cierra solo al terminar, aunque falle.
  static Future<R> _withProgress<R>(
    BuildContext context,
    String title,
    Future<R> Function(_Progress progress) task,
  ) async {
    final progress = _Progress();
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: ListenableBuilder(
            listenable: progress,
            builder: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress.value),
                const SizedBox(height: 10),
                Text(
                  progress.value == null ? progress.message : '${(progress.value! * 100).round()} %',
                  style: T.small,
                ),
                if (progress.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(progress.detail, style: T.tiny),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    try {
      return await task(progress);
    } finally {
      navigator.pop();
      progress.dispose();
    }
  }

  /// Marca de agua y 720p en una pasada, mostrando el avance. Si no se puede,
  /// devuelve [file] tal cual: el video se guarda aunque sin marca.
  @visibleForTesting
  static Future<File> processVideo(BuildContext context, File file, {required DateTime at, GeoPoint? point}) {
    return _withProgress(context, 'Preparando video', (progress) async {
      progress.set(message: 'Preparando…', detail: 'Se imprime la marca de agua y se reduce a 720p.');
      final out = await videoProcessor.process(
        file,
        lines: watermarkLines(at, point),
        point: point,
        onProgress: (v) => progress.set(value: v),
      );
      return out ?? file;
    });
  }

  static Future<void> recordVideo(BuildContext context, FieldVisit visit, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, CaptureMode.video);
    if (r == null || !context.mounted) return;
    final file = await processVideo(context, r.file, at: r.capturedAt, point: r.point);
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
      showAppSnack(
        context,
        file.path == r.file.path ? 'Video guardado sin marca de agua (no se pudo procesar)' : 'Video guardado',
        icon: Icons.check_circle_rounded,
        color: file.path == r.file.path ? AppColors.warning : AppColors.success,
      );
    }
  }

  /// En iOS pide JPEG/H.264 en lugar de HEIC/HEVC: así la foto se puede
  /// marcar y el video se ve en cualquier teléfono.
  static Future<List<PlatformFile>?> _pick(BuildContext context, FileType type) async {
    try {
      return await FilePicker.pickFiles(
        type: type,
        darwinOptions: const DarwinOptions(assetRepresentationMode: DarwinAssetRepresentationMode.compatible),
      );
    } catch (_) {
      if (context.mounted) showAppSnack(context, 'No se pudo abrir el selector', color: AppColors.danger);
      return null;
    }
  }

  /// Foto de la galería con la marca de agua de [at] y [point] en un
  /// temporal; nula si no se pudo leer (entonces se guarda la original).
  static Future<File?> _stampImported(String path, DateTime at, GeoPoint? point) async {
    final dir = await getTemporaryDirectory();
    final out = File(p.join(dir.path, 'solaris_import_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    try {
      await stampPhoto(
        inputPath: path,
        outputPath: out.path,
        lines: watermarkLines(at, point),
        gps: point,
        maxSide: importMaxSide,
      );
      return out;
    } catch (e) {
      debugPrint('Galería: sin marca de agua para $path: $e');
      return null;
    }
  }

  /// Fotos o videos de la galería, ya con su marca de agua. Cada uno sale
  /// con el archivo listo, el nombre a mostrar y si quedó marcado.
  static Future<List<({File file, String name, bool stamped, bool temp})>> _prepareImports(
    BuildContext context,
    List<PlatformFile> picked,
    EvidenceKind kind,
    _Progress progress,
    DateTime at,
    GeoPoint? point,
  ) async {
    final out = <({File file, String name, bool stamped, bool temp})>[];
    final files = picked.where((f) => f.path != null).toList();
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final original = File(f.path!);
      final count = files.length > 1 ? ' ${i + 1} de ${files.length}' : '';
      if (kind == EvidenceKind.photo) {
        progress.set(message: 'Marcando foto$count…', value: null);
        final stamped = await _stampImported(original.path, at, point);
        out.add((
          file: stamped ?? original,
          // Ya es JPEG aunque viniera en HEIC o PNG.
          name: stamped == null ? f.name : '${p.basenameWithoutExtension(f.name)}.jpg',
          stamped: stamped != null,
          temp: stamped != null,
        ));
      } else if (kind == EvidenceKind.video) {
        progress.set(message: 'Preparando video$count…', value: null);
        final processed = await videoProcessor.process(
          original,
          lines: watermarkLines(at, point),
          point: point,
          onProgress: (v) => progress.set(value: v),
        );
        out.add((
          file: processed ?? original,
          name: processed == null ? f.name : '${p.basenameWithoutExtension(f.name)}.mp4',
          stamped: processed != null,
          temp: processed != null,
        ));
      } else {
        out.add((file: original, name: f.name, stamped: false, temp: false));
      }
    }
    return out;
  }

  /// Ubicación del momento en que se suben fotos o videos de la galería.
  static Future<GeoPoint?> _locate(_Progress progress) async {
    progress.set(message: 'Obteniendo ubicación…', detail: 'Se imprime en la marca de agua con el enlace de Maps.');
    final fix = await LocationService.current();
    return fix.point;
  }

  static void _reportImport(BuildContext context, int saved, int unstamped, GeoPoint? point, EvidenceKind kind) {
    if (!context.mounted || saved == 0) return;
    final noun = kind == EvidenceKind.video ? 'video' : (kind == EvidenceKind.photo ? 'foto' : 'archivo');
    final text = StringBuffer('$saved $noun${saved == 1 ? '' : 's'} agregad${noun == 'foto' ? 'a' : 'o'}${saved == 1 ? '' : 's'}');
    if (kind != EvidenceKind.document) {
      if (unstamped > 0) {
        text.write(' · $unstamped sin marca de agua (no se pudo leer)');
      } else if (point == null) {
        text.write(' · marca "SIN GPS"');
      }
    }
    final warn = kind != EvidenceKind.document && (unstamped > 0 || point == null);
    showAppSnack(context, text.toString(),
        icon: warn ? Icons.info_outline_rounded : Icons.check_circle_rounded,
        color: warn ? AppColors.warning : AppColors.success);
  }

  /// Importa desde galería o archivos (fotos de dron, capturas de mapa,
  /// termografías). Las fotos y videos llevan la marca de agua con la hora y
  /// la ubicación del momento en que se suben, y quedan como importados.
  static Future<void> importFiles(BuildContext context, FieldVisit visit, ResolvedQuestion rq, EvidenceKind kind) async {
    final picked = await _pick(context, switch (kind) {
      EvidenceKind.photo => FileType.image,
      EvidenceKind.video => FileType.video,
      _ => FileType.any,
    });
    if (picked == null || picked.isEmpty || !context.mounted) return;

    final media = kind == EvidenceKind.photo || kind == EvidenceKind.video;
    var unstamped = 0;
    GeoPoint? point;
    final at = DateTime.now();
    final saved = await _withProgress(context, media ? 'Agregando ${kind == EvidenceKind.photo ? 'fotos' : 'videos'}' : 'Agregando archivos',
        (progress) async {
      if (media) point = await _locate(progress);
      if (!context.mounted) return 0;
      final ready = await _prepareImports(context, picked, kind, progress, at, point);
      for (final r in ready) {
        if (media && !r.stamped) unstamped++;
        await _store.addEvidence(
          visit: visit,
          key: rq.key,
          kind: kind,
          file: r.file,
          originalName: r.name,
          point: r.stamped ? point : null,
          capturedAt: r.stamped ? at : null,
          imported: true,
          moveFile: r.temp,
        );
      }
      return ready.length;
    });
    if (context.mounted) _reportImport(context, saved, unstamped, point, kind);
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

  /// Fotos del hallazgo desde la galería (p. ej. termografías), con la marca
  /// de agua del momento en que se suben.
  static Future<void> importFindingPhotos(BuildContext context, FieldVisit visit, VisitFinding finding) async {
    final picked = await _pick(context, FileType.image);
    if (picked == null || picked.isEmpty || !context.mounted) return;
    var unstamped = 0;
    GeoPoint? point;
    final at = DateTime.now();
    final saved = await _withProgress(context, 'Agregando fotos', (progress) async {
      point = await _locate(progress);
      if (!context.mounted) return 0;
      final ready = await _prepareImports(context, picked, EvidenceKind.photo, progress, at, point);
      for (final r in ready) {
        if (!r.stamped) unstamped++;
        await _store.addEvidence(
          visit: visit,
          findingId: finding.id,
          kind: EvidenceKind.photo,
          file: r.file,
          originalName: r.name,
          point: r.stamped ? point : null,
          capturedAt: r.stamped ? at : null,
          imported: true,
          moveFile: r.temp,
        );
      }
      return ready.length;
    });
    if (context.mounted) _reportImport(context, saved, unstamped, point, EvidenceKind.photo);
  }

  /// "Reemplazar fotografía": abre la cámara y sustituye el archivo.
  static Future<void> replacePhoto(BuildContext context, Evidence e, ResolvedQuestion rq) async {
    final r = await _openCamera(context, rq, e.kind == EvidenceKind.video ? CaptureMode.video : CaptureMode.photo);
    if (r == null || !context.mounted) return;
    var file = r.file;
    if (e.kind == EvidenceKind.video) {
      file = await processVideo(context, r.file, at: r.capturedAt, point: r.point);
      if (file.path != r.file.path) await _deleteQuietly(r.file);
    }
    await _store.replaceEvidenceFile(e, file, point: r.point, capturedAt: r.capturedAt, moveFile: true);
  }

  /// Abre el editor para escribir texto encima de la foto y guarda el
  /// resultado en la misma evidencia (conserva fecha, coordenadas y origen).
  static Future<bool> addText(BuildContext context, Evidence e) async {
    final source = _store.files.file(e.path);
    if (!source.existsSync()) return false;
    final edited = await PhotoTextEditor.open(context, source);
    if (edited == null) return false;
    await _store.replaceEvidenceFile(e, edited,
        point: e.point, capturedAt: e.capturedAt, imported: e.imported, moveFile: true);
    if (context.mounted) {
      showAppSnack(context, 'Texto agregado a la foto', icon: Icons.check_circle_rounded, color: AppColors.success);
    }
    return true;
  }

  /// El original de la cámara, ya procesado, sobra; si no se puede borrar
  /// el sistema limpia sus temporales.
  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Temporal del sistema.
    }
  }
}

/// Avance que muestra el diálogo de [EvidenceActions._withProgress]. Con
/// [value] nulo la barra se mueve sola y se lee [message].
class _Progress extends ChangeNotifier {
  String message = 'Preparando…';
  String detail = '';
  double? value;

  void set({String? message, String? detail, double? value}) {
    if (message != null) this.message = message;
    if (detail != null) this.detail = detail;
    this.value = value;
    notifyListeners();
  }
}
