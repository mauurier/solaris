import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';

/// El supervisor aprueba la visita terminada o la devuelve al técnico con lo
/// que debe corregir. Las observaciones quedan en la revisión.
Future<void> showReviewSheet(BuildContext context, FieldVisit visit, {required bool approve}) =>
    showAppSheet(
      context,
      title: approve ? 'Aprobar visita' : 'Pedir correcciones',
      subtitle: approve
          ? 'La visita queda aprobada; el proyecto, cuando todas sus visitas lo estén.'
          : 'La visita vuelve al técnico y no se puede cerrar hasta que atienda cada punto.',
      child: _ReviewForm(visit: visit, approve: approve),
    );

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.visit, required this.approve});
  final FieldVisit visit;
  final bool approve;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _notes = TextEditingController();
  final _items = [TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    for (final c in _items) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _filled => [for (final c in _items) if (c.text.trim().isNotEmpty) c.text.trim()];

  Future<void> _save() async {
    final store = SurveyStore.instance;
    setState(() => _saving = true);
    if (widget.approve) {
      await store.approveVisit(widget.visit, notes: _notes.text);
    } else {
      await store.requestCorrections(widget.visit, items: _filled, notes: _notes.text);
    }
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(
      context,
      widget.approve ? 'Visita aprobada' : 'Correcciones enviadas al técnico',
      icon: widget.approve ? Icons.verified_rounded : Icons.assignment_return_rounded,
      color: widget.approve ? AppColors.success : AppColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _filled.length;
    final ready = widget.approve || count > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.approve) ...[
            const FieldLabel('Qué debe corregir', required: true),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _items[i],
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: i == 0 ? 'Ej. Falta la foto de la placa del Transformador 2' : 'Otra corrección',
                    suffixIcon: _items.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _items.removeAt(i).dispose()),
                          )
                        : null,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _items.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar otra'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const FieldLabel('Observaciones', hint: 'Opcional'),
          TextField(
            controller: _notes,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.approve ? 'Ej. Buen levantamiento, completo' : 'Comentario general para el técnico',
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            _saving
                ? 'Guardando…'
                : widget.approve
                    ? 'Aprobar visita'
                    : count <= 1
                        ? 'Enviar corrección'
                        : 'Enviar $count correcciones',
            icon: widget.approve ? Icons.verified_rounded : Icons.assignment_return_rounded,
            expand: true,
            onPressed: ready && !_saving ? _save : null,
          ),
        ],
      ),
    );
  }
}

/// Correcciones sin atender de la visita. Quien puede capturar las marca
/// como atendidas al resolverlas.
class PendingCorrectionsCard extends StatelessWidget {
  const PendingCorrectionsCard({super.key, required this.visit, required this.editable});
  final FieldVisit visit;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final pending = store.pendingCorrections(visit.id);
    if (pending.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      borderColor: AppColors.warning.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.assignment_return_rounded, color: AppColors.warning, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pending.length == 1 ? '1 corrección pedida' : '${pending.length} correcciones pedidas',
                        style: T.h3),
                    const SizedBox(height: 3),
                    const Text('Atiende cada punto para poder cerrar la visita.', style: T.tiny),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in pending) CorrectionRow(correction: c, editable: editable),
        ],
      ),
    );
  }
}

class CorrectionRow extends StatelessWidget {
  const CorrectionRow({super.key, required this.correction, required this.editable});
  final Correction correction;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = correction;
    return InkWell(
      onTap: editable ? () => SurveyStore.instance.setCorrectionAttended(c, !c.attended) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              c.attended ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: c.attended ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.description, style: T.small.copyWith(color: AppColors.textPrimary)),
                  if (c.attendedAt != null)
                    Text('Atendida ${fmtDateTime(c.attendedAt!)}', style: T.tiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Historial de revisiones de la visita, la más reciente primero.
class ReviewHistory extends StatelessWidget {
  const ReviewHistory({super.key, required this.visit, required this.editable});
  final FieldVisit visit;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    final reviews = store.reviewsOf(visit.id);
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Revisiones · ${reviews.length}'),
        for (final r in reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusPill(
                        r.decision == ReviewDecision.approved ? 'Aprobada' : 'Con correcciones',
                        color: r.decision == ReviewDecision.approved ? AppColors.success : AppColors.warning,
                        dense: true,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${r.supervisor} · ${fmtDateTime(r.createdAt)}',
                            style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (r.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(r.notes, style: T.small),
                  ],
                  for (final c in store.correctionsOf(r.id)) CorrectionRow(correction: c, editable: editable),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
