import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';
import 'evidence_actions.dart';
import 'video_view.dart';

/// Consulta de una evidencia: vista completa, metadatos, comentario y
/// acciones de reemplazar o eliminar mientras la visita siga abierta.
class EvidenceViewerScreen extends StatefulWidget {
  const EvidenceViewerScreen({
    super.key,
    required this.evidence,
    required this.question,
    required this.editable,
  });

  final Evidence evidence;
  final ResolvedQuestion question;
  final bool editable;

  @override
  State<EvidenceViewerScreen> createState() => _EvidenceViewerScreenState();
}

class _EvidenceViewerScreenState extends State<EvidenceViewerScreen> {
  final _store = SurveyStore.instance;
  late final _comment = TextEditingController(text: widget.evidence.comment);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    final e = widget.evidence;
    if (_comment.text.trim() == e.comment) return;
    e.comment = _comment.text.trim();
    await _store.updateEvidence(e);
    if (mounted) showAppSnack(context, 'Comentario guardado', icon: Icons.check_rounded);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar evidencia?'),
        content: const Text('El archivo se borra del teléfono y no se puede recuperar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.removeEvidence(widget.evidence);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _share() async {
    final file = _store.files.file(widget.evidence.path);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evidence;
    final rq = widget.question;
    final file = _store.files.file(e.path);
    final exists = file.existsSync();

    return DetailScaffold(
      title: rq.question.label,
      subtitle: '${rq.code} · ${rq.instanceName}',
      actions: [HeaderIconButton(Icons.ios_share_rounded, onTap: exists ? _share : null)],
      bottomBar: widget.editable
          ? Row(
              children: [
                if (e.kind == EvidenceKind.photo || e.kind == EvidenceKind.video) ...[
                  Expanded(
                    child: AppButton(
                      'Reemplazar',
                      icon: Icons.cameraswitch_rounded,
                      kind: AppButtonKind.secondary,
                      expand: true,
                      onPressed: () async {
                        await EvidenceActions.replacePhoto(context, e, rq);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AppButton('Eliminar',
                      icon: Icons.delete_outline_rounded, kind: AppButtonKind.danger, expand: true, onPressed: _delete),
                ),
              ],
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              color: Colors.black,
              constraints: const BoxConstraints(minHeight: 200),
              alignment: Alignment.center,
              child: !exists
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('El archivo ya no está en el teléfono', style: T.small),
                    )
                  : switch (e.kind) {
                      EvidenceKind.photo || EvidenceKind.signature => InteractiveViewer(
                          maxScale: 6,
                          child: Image.file(file, key: ValueKey(e.path), fit: BoxFit.contain),
                        ),
                      EvidenceKind.video => VideoView(key: ValueKey(e.path), file: file),
                      EvidenceKind.document => Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              const IconBadge(Icons.description_rounded, color: AppColors.violet, size: 56),
                              const SizedBox(height: 12),
                              Text(e.originalName, style: T.h3, textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(fmtBytes(file.lengthSync()), style: T.tiny),
                              const SizedBox(height: 14),
                              AppButton('Abrir con…', icon: Icons.open_in_new_rounded, compact: true, onPressed: _share),
                            ],
                          ),
                        ),
                    },
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Metadatos'),
          GlassCard(
            child: Column(
              children: [
                KeyValue('Fecha y hora', fmtStamp(e.capturedAt)),
                KeyValue('Coordenadas', e.point?.label ?? (e.imported ? 'Importada' : 'Sin señal GPS'),
                    icon: Icons.place_rounded, valueColor: e.point == null ? AppColors.warning : AppColors.blue),
                KeyValue('Capturó', e.user),
                KeyValue('Origen', e.imported ? 'Importada · ${e.originalName}' : 'Cámara de Solaris'),
                if (exists) KeyValue('Tamaño', fmtBytes(file.lengthSync())),
                KeyValue('ID interno', e.id.substring(0, 8)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Comentario'),
          TextField(
            controller: _comment,
            enabled: widget.editable,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Agrega un comentario a esta evidencia…'),
            onEditingComplete: _saveComment,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _saveComment();
            },
          ),
        ],
      ),
    );
  }
}
