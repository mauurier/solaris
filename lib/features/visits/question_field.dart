import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../capture/evidence_actions.dart';
import '../capture/evidence_viewer_screen.dart';

/// Tarjeta de una pregunta de la plantilla. Guarda cada respuesta en cuanto
/// cambia (los textos, medio segundo después de dejar de escribir).
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.visit,
    required this.rq,
    required this.engine,
    required this.editable,
  });

  final FieldVisit visit;
  final ResolvedQuestion rq;
  final VisitEngine engine;
  final bool editable;

  QuestionDef get q => rq.question;

  @override
  Widget build(BuildContext context) {
    final answered = engine.isAnswered(rq);
    final justified = visit.justifications[rq.key.toString()];
    final missing = q.required && !answered && justified == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: answered
              ? AppColors.success.withValues(alpha: 0.22)
              : missing
                  ? AppColors.danger.withValues(alpha: 0.22)
                  : AppColors.borderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Text(rq.code, style: T.mono.copyWith(fontSize: 11, color: AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(q.label, style: T.body.copyWith(fontWeight: FontWeight.w500, height: 1.3)),
              ),
              const SizedBox(width: 8),
              if (answered)
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success)
              else if (justified != null)
                const Icon(Icons.gpp_maybe_rounded, size: 18, color: AppColors.warning)
              else if (q.required)
                const _RequiredTag(),
            ],
          ),
          if (q.hint.isNotEmpty && !q.type.isEvidence && q.type != QType.text) ...[
            const SizedBox(height: 6),
            Text(q.hint, style: T.tiny),
          ],
          if (justified != null) ...[
            const SizedBox(height: 6),
            Text('Justificado: $justified', style: T.tiny.copyWith(color: AppColors.warning)),
          ],
          const SizedBox(height: 12),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final store = SurveyStore.instance;
    final value = engine.value(rq.key);
    void save(String? v) => store.setAnswer(visit, rq.key, v);

    switch (q.type) {
      case QType.text:
      case QType.longText:
      case QType.number:
        return _TextAnswer(
          key: ValueKey('txt-${visit.id}-${rq.key}'),
          initial: value ?? '',
          editable: editable,
          multiline: q.type == QType.longText,
          number: q.type == QType.number,
          unit: q.unit,
          hint: q.type == QType.text && q.hint.isNotEmpty ? q.hint : null,
          onSave: save,
        );
      case QType.yesNo:
        return Row(
          children: [
            for (final o in const ['Sí', 'No']) ...[
              if (o == 'No') const SizedBox(width: 10),
              Expanded(
                child: ChoicePill(
                  label: o,
                  selected: value == o,
                  expand: true,
                  onTap: editable ? () => save(value == o ? null : o) : null,
                ),
              ),
            ],
          ],
        );
      case QType.single:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in q.options)
              ChoicePill(label: o, selected: value == o, onTap: editable ? () => save(value == o ? null : o) : null),
          ],
        );
      case QType.multi:
        final sel = VisitEngine.splitMulti(value);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in q.options)
              ChoicePill(
                label: o,
                selected: sel.contains(o),
                check: true,
                onTap: editable
                    ? () {
                        final next = [...sel];
                        next.contains(o) ? next.remove(o) : next.add(o);
                        // Se guarda en el orden de las opciones.
                        save(q.options.where(next.contains).join('|'));
                      }
                    : null,
              ),
          ],
        );
      case QType.scale:
        final current = double.tryParse(value ?? '');
        return Row(
          children: [
            Text('${q.min}', style: T.tiny),
            Expanded(
              child: Slider(
                min: q.min.toDouble(),
                max: q.max.toDouble(),
                divisions: (q.max - q.min).clamp(1, 100),
                value: (current ?? q.min.toDouble()).clamp(q.min.toDouble(), q.max.toDouble()),
                label: current == null ? null : '${current.round()} ${q.unit}',
                onChanged: editable ? (v) => save(v.round().toString()) : null,
              ),
            ),
            Text('${q.max}', style: T.tiny),
            const SizedBox(width: 10),
            SizedBox(
              width: 54,
              child: Text(
                current == null ? '—' : '${current.round()}${q.unit.isEmpty ? '' : ' ${q.unit}'}',
                textAlign: TextAlign.end,
                style: T.h3.copyWith(color: current == null ? AppColors.textMuted : AppColors.accent),
              ),
            ),
          ],
        );
      case QType.photo:
        return _EvidenceStrip(visit: visit, rq: rq, editable: editable, kind: EvidenceKind.photo);
      case QType.video:
        return _EvidenceStrip(visit: visit, rq: rq, editable: editable, kind: EvidenceKind.video);
      case QType.document:
        return _DocumentList(visit: visit, rq: rq, editable: editable);
      case QType.signature:
        return _SignatureAnswer(visit: visit, rq: rq, editable: editable);
    }
  }
}

class _RequiredTag extends StatelessWidget {
  const _RequiredTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('Obligatorio',
          style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w600)),
    );
  }
}

/// Opción seleccionable en forma de píldora (opción única, múltiple, sí/no).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.check = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand;
  final bool check;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: expand ? 12 : 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (check || expand) ...[
              Icon(
                selected
                    ? (check ? Icons.check_box_rounded : Icons.check_circle_rounded)
                    : (check ? Icons.check_box_outline_blank_rounded : Icons.circle_outlined),
                size: 16,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAnswer extends StatefulWidget {
  const _TextAnswer({
    super.key,
    required this.initial,
    required this.editable,
    required this.multiline,
    required this.number,
    required this.unit,
    required this.onSave,
    this.hint,
  });

  final String initial;
  final bool editable;
  final bool multiline;
  final bool number;
  final String unit;
  final String? hint;
  final ValueChanged<String?> onSave;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final _c = TextEditingController(text: widget.initial);
  Timer? _debounce;

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    _debounce?.cancel();
    final v = _c.text.trim();
    widget.onSave(v.isEmpty ? null : v);
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) _flush();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.editable,
      onChanged: _changed,
      onSubmitted: (_) => _flush(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      minLines: widget.multiline ? 2 : 1,
      maxLines: widget.multiline ? 6 : 1,
      style: T.body,
      textInputAction: widget.multiline ? TextInputAction.newline : TextInputAction.done,
      keyboardType: widget.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : widget.multiline
              ? TextInputType.multiline
              : TextInputType.text,
      inputFormatters: widget.number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))] : null,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint ?? (widget.number ? '0' : 'Escribe aquí…'),
        suffixText: widget.unit.isEmpty ? null : widget.unit,
        suffixStyle: T.small.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

/// Miniaturas de fotos o videos de una pregunta con botones de captura.
class _EvidenceStrip extends StatelessWidget {
  const _EvidenceStrip({required this.visit, required this.rq, required this.editable, required this.kind});
  final FieldVisit visit;
  final ResolvedQuestion rq;
  final bool editable;
  final EvidenceKind kind;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final items = store.evidenceOf(visit.id, rq.key);
    final min = rq.question.minCount < 1 ? 1 : rq.question.minCount;
    final isPhoto = kind == EvidenceKind.photo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rq.question.hint.isNotEmpty) ...[
          Text(rq.question.hint, style: T.tiny),
          const SizedBox(height: 10),
        ],
        if (items.isNotEmpty) ...[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => EvidenceThumb(
                evidence: items[i],
                size: 84,
                onTap: () => push(
                  context,
                  EvidenceViewerScreen(evidence: items[i], question: rq, editable: editable),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Text(
              '${items.length}${min > 1 ? ' de $min' : ''} ${isPhoto ? 'foto${items.length == 1 ? '' : 's'}' : 'video${items.length == 1 ? '' : 's'}'}',
              style: T.tiny.copyWith(
                color: items.length >= min ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (editable) ...[
              AppButton(
                'Importar',
                icon: Icons.file_upload_outlined,
                kind: AppButtonKind.ghost,
                compact: true,
                onPressed: () => EvidenceActions.importFiles(context, visit, rq, kind),
              ),
              const SizedBox(width: 6),
              AppButton(
                isPhoto ? 'Tomar foto' : 'Grabar',
                icon: isPhoto ? Icons.photo_camera_rounded : Icons.videocam_rounded,
                compact: true,
                onPressed: () => isPhoto
                    ? EvidenceActions.takePhoto(context, visit, rq)
                    : EvidenceActions.recordVideo(context, visit, rq),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Miniatura de una evidencia (foto real, o icono para video/documento).
class EvidenceThumb extends StatelessWidget {
  const EvidenceThumb({super.key, required this.evidence, this.size = 84, this.onTap});
  final Evidence evidence;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final file = SurveyStore.instance.files.file(evidence.path);
    final isImage = evidence.kind == EvidenceKind.photo || evidence.kind == EvidenceKind.signature;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          color: AppColors.surfaceHigh,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isImage && file.existsSync())
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 3).round(),
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
                )
              else
                Icon(
                  evidence.kind == EvidenceKind.video ? Icons.play_circle_fill_rounded : Icons.description_rounded,
                  color: AppColors.textSecondary,
                  size: 30,
                ),
              if (evidence.imported)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(Icons.file_upload_rounded, size: 13, color: Colors.white70),
                ),
              if (evidence.comment.isNotEmpty)
                const Positioned(
                  left: 4,
                  top: 4,
                  child: Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.visit, required this.rq, required this.editable});
  final FieldVisit visit;
  final ResolvedQuestion rq;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final items = store.evidenceOf(visit.id, rq.key);
    final fromProject = rq.question.docCategory.isEmpty
        ? const <ProjectDocument>[]
        : store.documentsOf(visit.projectId).where((d) => d.category == rq.question.docCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rq.question.hint.isNotEmpty) ...[
          Text(rq.question.hint, style: T.tiny),
          const SizedBox(height: 10),
        ],
        for (final d in fromProject)
          _docRow(Icons.folder_shared_rounded, d.originalName, 'Subido al crear el proyecto · ${fmtBytes(d.size)}',
              AppColors.blue, null),
        for (final e in items)
          _docRow(
            Icons.description_rounded,
            e.originalName,
            '${fmtDateTime(e.capturedAt)} · ${fmtBytes(store.files.sizeOf(e.path))}',
            AppColors.violet,
            () => push(context, EvidenceViewerScreen(evidence: e, question: rq, editable: editable)),
          ),
        Row(
          children: [
            if (items.isEmpty && fromProject.isEmpty) const Text('Sin archivo', style: T.tiny),
            const Spacer(),
            if (editable)
              AppButton(
                'Adjuntar archivo',
                icon: Icons.attach_file_rounded,
                compact: true,
                kind: fromProject.isEmpty ? AppButtonKind.primary : AppButtonKind.secondary,
                onPressed: () => EvidenceActions.importFiles(context, visit, rq, EvidenceKind.document),
              ),
          ],
        ),
      ],
    );
  }

  Widget _docRow(IconData icon, String title, String subtitle, Color color, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.small.copyWith(color: AppColors.textPrimary), maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureAnswer extends StatefulWidget {
  const _SignatureAnswer({required this.visit, required this.rq, required this.editable});
  final FieldVisit visit;
  final ResolvedQuestion rq;
  final bool editable;

  @override
  State<_SignatureAnswer> createState() => _SignatureAnswerState();
}

class _SignatureAnswerState extends State<_SignatureAnswer> {
  final _pad = GlobalKey<SignaturePadState>();
  bool _hasStrokes = false;
  bool _saving = false;

  Future<void> _save() async {
    final png = await _pad.currentState?.toPng();
    if (png == null) return;
    setState(() => _saving = true);
    final store = SurveyStore.instance;
    for (final old in store.evidenceOf(widget.visit.id, widget.rq.key)) {
      await store.removeEvidence(old);
    }
    final dir = await getTemporaryDirectory();
    final tmp = File(p.join(dir.path, 'firma_${DateTime.now().millisecondsSinceEpoch}.png'));
    await tmp.writeAsBytes(png, flush: true);
    await store.addEvidence(
      visit: widget.visit,
      key: widget.rq.key,
      kind: EvidenceKind.signature,
      file: tmp,
      moveFile: true,
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _redo() async {
    final store = SurveyStore.instance;
    for (final old in store.evidenceOf(widget.visit.id, widget.rq.key)) {
      await store.removeEvidence(old);
    }
    setState(() => _hasStrokes = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final signed = store.evidenceOf(widget.visit.id, widget.rq.key).firstOrNull;
    if (signed != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.white,
              height: 140,
              child: Image.file(store.files.file(signed.path), fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('${signed.user} · ${fmtDateTime(signed.capturedAt)}', style: T.tiny)),
              if (widget.editable)
                AppButton('Firmar de nuevo', kind: AppButtonKind.ghost, compact: true, onPressed: _redo),
            ],
          ),
        ],
      );
    }
    if (!widget.editable) return const Text('Sin firma', style: T.tiny);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SignaturePad(key: _pad, height: 160, onChanged: (v) => setState(() => _hasStrokes = v)),
        const SizedBox(height: 10),
        Row(
          children: [
            AppButton('Borrar',
                kind: AppButtonKind.ghost, compact: true, onPressed: () => _pad.currentState?.clear()),
            const Spacer(),
            AppButton(
              _saving ? 'Guardando…' : 'Guardar firma',
              icon: Icons.check_rounded,
              compact: true,
              onPressed: _hasStrokes && !_saving ? _save : null,
            ),
          ],
        ),
      ],
    );
  }
}
