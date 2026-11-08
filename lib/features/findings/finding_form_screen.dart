import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/services/maps.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../capture/evidence_actions.dart';
import '../shell/home_shell.dart';
import '../visits/question_field.dart';

/// Quién puede registrar y editar hallazgos de la visita: el técnico mientras
/// está abierta, y quien la revisa en cualquier momento (como
/// `puede_capturar_visita` en Solaris).
bool canEditFindings(FieldVisit v) {
  final app = AppState.instance;
  final project = SurveyStore.instance.project(v.projectId);
  final reviewer = app.role == UserRole.admin || v.supervisorId == app.userId || project?.supervisorId == app.userId;
  return reviewer || (v.started && !v.finished && v.technicianId == app.userId);
}

/// Sólo quien revisa puede cerrar un hallazgo.
bool canCloseFindings(FieldVisit v) {
  final app = AppState.instance;
  final project = SurveyStore.instance.project(v.projectId);
  return app.role == UserRole.admin || v.supervisorId == app.userId || project?.supervisorId == app.userId;
}

/// Registro de un hallazgo nuevo ([finding] nulo) o detalle para darle
/// seguimiento: estado, datos y fotos.
class FindingFormScreen extends StatefulWidget {
  const FindingFormScreen({super.key, required this.visit, this.finding});
  final FieldVisit visit;
  final VisitFinding? finding;

  @override
  State<FindingFormScreen> createState() => _FindingFormScreenState();
}

class _FindingFormScreenState extends State<FindingFormScreen> {
  final _store = SurveyStore.instance;
  late FindingCategory _category = widget.finding?.category ?? FindingCategory.electrico;
  late Severity _severity = widget.finding?.severity ?? Severity.media;
  late FindingStatus _status = widget.finding?.status ?? FindingStatus.abierto;
  late final _description = TextEditingController(text: widget.finding?.description ?? '');
  late final _location = TextEditingController(text: widget.finding?.location ?? '');
  late final _recommendation = TextEditingController(text: widget.finding?.recommendation ?? '');
  bool _saving = false;

  FieldVisit get v => widget.visit;
  bool get _editable => canEditFindings(v);

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    _recommendation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_description.text.trim().isEmpty) {
      showAppSnack(context, 'Describe el hallazgo', icon: Icons.error_outline_rounded, color: AppColors.danger);
      return;
    }
    setState(() => _saving = true);
    final f = widget.finding;
    if (f == null) {
      final fix = await LocationService.current();
      final created = await _store.addFinding(
        v,
        category: _category,
        severity: _severity,
        description: _description.text,
        location: _location.text,
        recommendation: _recommendation.text,
        point: fix.point,
      );
      if (!mounted) return;
      // Ya registrado, se le pueden agregar fotos.
      Navigator.of(context).pushReplacement(appRoute(FindingFormScreen(visit: v, finding: created)));
      showAppSnack(context, 'Hallazgo ${created.code} registrado · agrega sus fotos',
          icon: Icons.check_circle_rounded, color: AppColors.success);
      return;
    }
    f
      ..category = _category
      ..severity = _severity
      ..status = _status
      ..description = _description.text.trim()
      ..location = _location.text.trim()
      ..recommendation = _recommendation.text.trim();
    await _store.updateFinding(f);
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(context, 'Hallazgo ${f.code} actualizado', icon: Icons.check_circle_rounded, color: AppColors.success);
  }

  Future<void> _delete(VisitFinding f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar ${f.code}?'),
        content: const Text('Se borran el hallazgo y sus fotos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.deleteFinding(f);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final project = _store.project(v.projectId);
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => DetailScaffold(
        title: f == null ? 'Nuevo hallazgo' : f.code,
        subtitle: '${project?.name ?? ''} · ${v.label}',
        actions: [
          if (f != null && _editable) HeaderIconButton(Icons.delete_outline_rounded, onTap: () => _delete(f)),
        ],
        bottomBar: _editable
            ? AppButton(
                _saving ? 'Guardando…' : (f == null ? 'Registrar hallazgo' : 'Guardar cambios'),
                icon: Icons.check_rounded,
                expand: true,
                onPressed: _saving ? null : _save,
              )
            : null,
        child: AbsorbPointer(
          absorbing: !_editable,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              if (f != null) ...[
                const FieldLabel('Estado'),
                SegmentedPicker(
                  options: [
                    for (final s in FindingStatus.values)
                      if (s != FindingStatus.cerrado || canCloseFindings(v) || _status == s) s.label,
                  ],
                  selected: _status.label,
                  onSelected: (l) => setState(() => _status = FindingStatus.values.firstWhere((s) => s.label == l)),
                  activeColor: _status.color,
                ),
                const SizedBox(height: 20),
              ],
              const FieldLabel('Categoría', required: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in FindingCategory.values)
                    ChoicePill(label: c.label, selected: c == _category, onTap: () => setState(() => _category = c)),
                ],
              ),
              const SizedBox(height: 20),
              const FieldLabel('Severidad', required: true),
              SegmentedPicker(
                options: [for (final s in Severity.values) s.label],
                selected: _severity.label,
                onSelected: (l) => setState(() => _severity = Severity.values.firstWhere((s) => s.label == l)),
                activeColor: _severity.color,
              ),
              const SizedBox(height: 20),
              const FieldLabel('Descripción', required: true),
              TextField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ej. Punto caliente en la zapata L2 del ITM principal'),
              ),
              const SizedBox(height: 18),
              const FieldLabel('Ubicación', hint: 'Opcional'),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ej. Cuarto eléctrico · Tablero Principal',
                  prefixIcon: Icon(Icons.place_rounded, size: 17),
                ),
              ),
              const SizedBox(height: 18),
              const FieldLabel('Recomendación', hint: 'Opcional'),
              TextField(
                controller: _recommendation,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Acción sugerida'),
              ),
              if (f != null) ...[
                const SizedBox(height: 20),
                _photos(f),
                const SizedBox(height: 18),
                GlassCard(
                  color: AppColors.surfaceAlt,
                  child: Column(
                    children: [
                      KeyValue('Registró', f.user),
                      KeyValue('Fecha', fmtDateTime(f.createdAt)),
                      if (f.point != null) KeyValue('Coordenadas', f.point!.label, icon: Icons.place_rounded),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                const Text('Se guarda la ubicación GPS al registrarlo. Después podrás agregar fotos.', style: T.tiny),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photos(VisitFinding f) {
    final photos = _store.evidenceOfFinding(f.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Fotos · ${photos.length}'),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in photos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _openPhoto(e),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 92,
                        child: _store.files.exists(e.path)
                            ? Image.file(_store.files.file(e.path), fit: BoxFit.cover, cacheWidth: 276)
                            : const ColoredBox(
                                color: AppColors.surfaceHigh,
                                child: Icon(Icons.cloud_download_rounded, color: AppColors.textMuted),
                              ),
                      ),
                    ),
                  ),
                ),
              if (_editable) ...[
                _addTile(Icons.add_a_photo_outlined, 'Cámara', () => EvidenceActions.takeFindingPhoto(context, v, f)),
                _addTile(Icons.photo_library_outlined, 'Galería', () => EvidenceActions.importFindingPhotos(context, v, f)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _addTile(IconData icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 92,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: AppColors.textMuted),
                const SizedBox(height: 6),
                Text(label, style: T.tiny),
              ],
            ),
          ),
        ),
      );

  Future<void> _openPhoto(Evidence e) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_store.files.exists(e.path))
              MapsPhoto(
                point: e.point,
                child: InteractiveViewer(child: Image.file(_store.files.file(e.path), fit: BoxFit.contain)),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: Text(fmtDateTime(e.capturedAt), style: T.tiny)),
                  if (_editable && _store.files.exists(e.path))
                    TextButton(onPressed: () => Navigator.pop(ctx, 'text'), child: const Text('Texto')),
                  if (_editable) TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Borrar')),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') await _store.removeEvidence(e);
    if (action != 'text' || !mounted) return;
    if (await EvidenceActions.addText(context, e) && mounted) setState(() {});
  }
}
