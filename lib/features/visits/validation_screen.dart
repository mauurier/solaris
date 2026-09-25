import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'section_screen.dart';

/// Validación antes de cerrar: los pendientes obligatorios bloquean, los
/// opcionales no, y el supervisor puede justificar un obligatorio.
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key, required this.visit});
  final FieldVisit visit;

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final _store = SurveyStore.instance;
  bool _showOptional = false;
  bool _closing = false;

  bool get _isSupervisor {
    final r = AppState.instance.role;
    return r == UserRole.supervisor || r == UserRole.admin;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final engine = _store.engineFor(widget.visit);
        final pend = engine.pendings();
        final blocking = pend.where((p) => p.kind == PendingKind.blocking).toList();
        final optional = pend.where((p) => p.kind == PendingKind.optional).toList();
        final justified = pend.where((p) => p.kind == PendingKind.justified).toList();
        final pct = (engine.overall.value * 100).round();

        return DetailScaffold(
          title: 'Validación',
          subtitle: '${widget.visit.label} · levantamiento $pct %',
          bottomBar: AppButton(
            _closing
                ? 'Cerrando…'
                : blocking.isEmpty
                    ? 'Finalizar visita'
                    : '${blocking.length} pendiente${blocking.length == 1 ? '' : 's'} obligatorio${blocking.length == 1 ? '' : 's'}',
            icon: blocking.isEmpty ? Icons.flag_rounded : Icons.lock_rounded,
            expand: true,
            onPressed: blocking.isEmpty && !_closing ? _finish : null,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              GlassCard(
                child: Row(
                  children: [
                    ProgressRing(
                      value: engine.overall.value,
                      size: 70,
                      stroke: 6,
                      color: blocking.isEmpty ? AppColors.success : AppColors.accent,
                      center: Text('$pct%', style: T.h3),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(blocking.isEmpty ? 'Listo para cerrar' : 'Aún no se puede cerrar', style: T.h2),
                          const SizedBox(height: 6),
                          Text(
                            '${blocking.length} obligatorios · ${optional.length} opcionales · ${justified.length} justificados',
                            style: T.tiny,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (blocking.isNotEmpty && !_isSupervisor)
                const InfoBanner(
                  'Si algo no se puede capturar en sitio, un supervisor puede justificarlo desde esta pantalla.',
                  icon: Icons.support_agent_rounded,
                ),
              if (blocking.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionLabel('Pendientes obligatorios · ${blocking.length}'),
                ...blocking.map((p) => _row(p, AppColors.danger)),
              ],
              if (justified.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionLabel('Justificados · ${justified.length}'),
                ...justified.map((p) => _row(p, AppColors.warning)),
              ],
              if (optional.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionLabel(
                  'Opcionales · ${optional.length}',
                  trailing: GestureDetector(
                    onTap: () => setState(() => _showOptional = !_showOptional),
                    child: Text(_showOptional ? 'Ocultar' : 'Ver',
                        style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (_showOptional) ...optional.map((p) => _row(p, AppColors.textMuted)),
              ],
              if (pend.isEmpty) ...[
                const SizedBox(height: 30),
                const EmptyState(
                  icon: Icons.verified_rounded,
                  title: 'Levantamiento completo',
                  message: 'Todas las preguntas tienen respuesta y evidencia.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(Pending p, Color color) {
    final rq = p.question;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => push(
          context,
          SectionScreen(
            visit: widget.visit,
            sectionIndex: rq.sectionIndex,
            editable: true,
            focusGroup: rq.group.id,
            focusInstance: rq.instance,
          ),
        ),
        child: Row(
          children: [
            Icon(rq.question.type.icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Falta: ${rq.contextLabel}', style: T.small.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    p.kind == PendingKind.justified ? p.justification! : '${rq.code} · ${rq.section.title}',
                    style: T.tiny,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_isSupervisor && p.kind != PendingKind.optional)
              GestureDetector(
                onTap: () => p.kind == PendingKind.justified
                    ? _store.justify(widget.visit, rq.key, null)
                    : _justify(p),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(p.kind == PendingKind.justified ? 'Quitar' : 'Justificar',
                      style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _justify(Pending p) async {
    final reason = await showTextPrompt(
      context,
      title: 'Justificar pendiente',
      message: p.question.contextLabel,
      hint: 'Ej. El cliente no dio acceso al cuarto eléctrico',
      confirm: 'Justificar',
      maxLines: 3,
      requireText: true,
    );
    if (reason != null && reason.isNotEmpty) {
      await _store.justify(widget.visit, p.question.key, reason);
    }
  }

  Future<void> _finish() async {
    final notes = await showTextPrompt(
      context,
      title: '¿Finalizar la visita?',
      message: 'Se registra la hora y ubicación de cierre. Antes de retirarte, confirma que '
          'fotos y mediciones estén completas.',
      hint: 'Notas de cierre (opcional)',
      confirm: 'Finalizar',
      cancel: 'Seguir capturando',
      maxLines: 2,
    );
    if (notes == null) return;
    setState(() => _closing = true);
    final fix = await LocationService.current();
    await _store.finishVisit(widget.visit, fix.point, notes: notes);
    if (!mounted) return;
    Navigator.pop(context);
    showAppSnack(context, 'Visita finalizada · lista para exportar',
        icon: Icons.flag_rounded, color: AppColors.success);
  }
}
