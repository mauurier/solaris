import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/visit_engine.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../capture/evidence_viewer_screen.dart';
import '../export/zip_export_screen.dart';
import '../shell/home_shell.dart';
import '../visits/new_visit_screen.dart';
import '../visits/question_field.dart';
import '../visits/visit_screen.dart';
import 'project_documents.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final SurveyProject project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _store = SurveyStore.instance;
  String _tab = 'Resumen';

  SurveyProject get p => widget.project;

  bool get _isManager {
    final r = AppState.instance.role;
    return r == UserRole.admin || r == UserRole.supervisor;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        if (_store.project(p.id) == null) return const Scaffold(body: SizedBox());
        final latest = _store.latestVisit(p.id);
        final role = AppState.instance.role;
        final isField = role == UserRole.tecnico;

        return DetailScaffold(
          title: p.name,
          subtitle: '${p.code} · ${p.client}',
          showGlow: true,
          actions: [
            if (_isManager) ...[
              HeaderIconButton(Icons.manage_accounts_rounded, onTap: _assign),
              const SizedBox(width: 8),
            ],
            HeaderIconButton(Icons.folder_zip_rounded, onTap: () => push(context, ZipExportScreen(project: p))),
          ],
          bottomBar: latest == null
              ? (_isManager
                  ? AppButton('Crear visita',
                      icon: Icons.add_rounded,
                      expand: true,
                      onPressed: () => push(context, NewVisitScreen(project: p), fullscreenDialog: true))
                  : null)
              : AppButton(
                  !latest.started
                      ? (isField ? 'Iniciar levantamiento' : 'Ver visita')
                      : latest.finished
                          ? 'Ver levantamiento'
                          : (isField ? 'Continuar levantamiento' : 'Ver avance'),
                  icon: !latest.started ? Icons.play_arrow_rounded : Icons.checklist_rounded,
                  expand: true,
                  onPressed: () => push(context, VisitScreen(visit: latest)),
                ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: SegmentedPicker(
                  options: const ['Resumen', 'Visitas', 'Documentos', 'Evidencia'],
                  selected: _tab,
                  onSelected: (v) => setState(() => _tab = v),
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  'Visitas' => _visits(),
                  'Documentos' => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      children: [
                        const Text(
                          'Documentos de partida del proyecto. Los que coinciden con una pregunta de la plantilla '
                          '(recibo CFE, unifilar, planos, CAD) cuentan como respondidos en el levantamiento.',
                          style: T.tiny,
                        ),
                        const SizedBox(height: 14),
                        ProjectDocumentsPanel(project: p, canEdit: role != UserRole.revisor),
                      ],
                    ),
                  'Evidencia' => _evidence(),
                  _ => _summary(latest),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ resumen
  Widget _summary(FieldVisit? latest) {
    final template = _store.template(p.templateId);
    final progress = _store.progressOf(p);
    final engine = latest != null && latest.started ? _store.engineFor(latest) : null;
    final docs = _store.documentsOf(p.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        GlassCard(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF161B25), Color(0xFF12161E)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ProgressRing(value: progress, size: 82, stroke: 7, color: p.status.color),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AVANCE GENERAL', style: T.overline),
                        const SizedBox(height: 8),
                        StatusPill(p.status.label, color: p.status.color, icon: p.status.icon),
                        const SizedBox(height: 10),
                        Text('Última actividad: ${fmtAgo(p.updatedAt).toLowerCase()}', style: T.tiny),
                        if (engine != null) ...[
                          const SizedBox(height: 4),
                          Text('${engine.blockingCount} pendientes obligatorios', style: T.tiny),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (engine != null) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 14),
                for (final s in engine.template.sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(s.iconData, size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LinearMeter(
                            label: s.title,
                            value: engine.sectionProgress(s).value,
                            color: engine.sectionProgress(s).complete ? AppColors.success : AppColors.accent,
                            height: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Datos del proyecto'),
        GlassCard(
          child: Column(
            children: [
              KeyValue('Clave', p.code),
              KeyValue('Cliente', p.client),
              KeyValue('Tipo', p.type),
              KeyValue('Sitio', p.site),
              if (p.address.isNotEmpty) KeyValue('Dirección', p.address),
              KeyValue('Coordenadas', p.coords?.label ?? 'Sin registrar',
                  icon: Icons.place_rounded, valueColor: p.coords == null ? AppColors.textMuted : AppColors.blue),
              const Divider(),
              KeyValue('Supervisor', p.supervisor),
              KeyValue('Técnicos', p.technicians.isEmpty ? 'Sin asignar' : p.technicians.join(', ')),
              KeyValue('Plantilla', template == null ? '—' : '${template.name} ${template.version}'),
              const Divider(),
              KeyValue('Creado', fmtDateTime(p.createdAt)),
              KeyValue('Programado', p.scheduledAt == null ? 'Sin fecha' : fmtDate(p.scheduledAt!)),
              KeyValue('Documentos', '${docs.length}'),
            ],
          ),
        ),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Descripción'),
          GlassCard(child: Text(p.description, style: T.bodyMuted)),
        ],
        if (AppState.instance.role == UserRole.admin) ...[
          const SizedBox(height: 24),
          AppButton('Eliminar proyecto',
              icon: Icons.delete_outline_rounded, kind: AppButtonKind.danger, expand: true, onPressed: _delete),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ visitas
  Widget _visits() {
    final visits = _store.visitsOf(p.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        SectionLabel(
          '${visits.length} visita${visits.length == 1 ? '' : 's'}',
          trailing: _isManager
              ? GestureDetector(
                  onTap: () => push(context, NewVisitScreen(project: p), fullscreenDialog: true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 15, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Nueva visita',
                          style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : null,
        ),
        if (visits.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Sin visitas',
            message: 'Asigna un técnico para crear la primera visita.',
          ),
        for (final v in visits) ...[VisitTile(visit: v), const SizedBox(height: 11)],
      ],
    );
  }

  // ---------------------------------------------------------------- evidencia
  Widget _evidence() {
    final all = _store.evidenceOfProject(p.id);
    final photos = all.where((e) => e.kind == EvidenceKind.photo).toList();
    int count(EvidenceKind k) => all.where((e) => e.kind == k).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        Row(
          children: [
            _stat(Icons.photo_camera_rounded, '${count(EvidenceKind.photo)}', 'fotos', AppColors.accent),
            const SizedBox(width: 10),
            _stat(Icons.videocam_rounded, '${count(EvidenceKind.video)}', 'videos', AppColors.teal),
            const SizedBox(width: 10),
            _stat(Icons.description_rounded, '${count(EvidenceKind.document)}', 'archivos', AppColors.violet),
          ],
        ),
        const SizedBox(height: 20),
        SectionLabel('Fotografías recientes · ${photos.length}'),
        if (photos.isEmpty)
          const EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Sin fotografías',
            message: 'Las fotos que se tomen en el levantamiento aparecerán aquí.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final e = photos[i];
              final rq = _resolve(e);
              return LayoutBuilder(
                builder: (_, c) => EvidenceThumb(
                  evidence: e,
                  size: c.maxWidth,
                  onTap: rq == null
                      ? null
                      : () => push(context, EvidenceViewerScreen(evidence: e, question: rq, editable: false)),
                ),
              );
            },
          ),
      ],
    );
  }

  ResolvedQuestion? _resolve(Evidence e) {
    final v = _store.visit(e.visitId);
    if (v == null) return null;
    final key = AnswerKey.parse(e.key);
    final t = _store.templateFor(v);
    for (var si = 0; si < t.sections.length; si++) {
      for (var gi = 0; gi < t.sections[si].groups.length; gi++) {
        final g = t.sections[si].groups[gi];
        if (g.id != key.groupId) continue;
        final qi = g.questions.indexWhere((q) => q.id == key.questionId);
        if (qi < 0) continue;
        return ResolvedQuestion(
          section: t.sections[si],
          sectionIndex: si,
          group: g,
          groupIndex: gi,
          question: g.questions[qi],
          questionIndex: qi,
          instance: key.instance,
        );
      }
    }
    return null;
  }

  Widget _stat(IconData icon, String n, String label, Color color) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 8),
              Text(n, style: T.h1),
              Text(label, style: T.tiny),
            ],
          ),
        ),
      );

  // --------------------------------------------------------------- acciones
  Future<void> _assign() async {
    final supervisors = Mock.users.where((u) => u.role == UserRole.supervisor && u.active).map((u) => u.name).toList();
    final techs = Mock.users.where((u) => u.role == UserRole.tecnico && u.active).map((u) => u.name).toList();
    var supervisor = p.supervisor;
    final selected = {...p.technicians};

    final saved = await showAppSheet<bool>(
      context,
      title: 'Asignación',
      subtitle: 'Supervisor y técnicos del proyecto',
      child: StatefulBuilder(
        builder: (ctx, setSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          children: [
            const FieldLabel('Supervisor', required: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in supervisors)
                  ChoicePill(label: s, selected: supervisor == s, onTap: () => setSheet(() => supervisor = s)),
              ],
            ),
            const SizedBox(height: 18),
            const FieldLabel('Técnicos', hint: 'Selección múltiple'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in techs)
                  ChoicePill(
                    label: t,
                    selected: selected.contains(t),
                    check: true,
                    onTap: () => setSheet(() => selected.contains(t) ? selected.remove(t) : selected.add(t)),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            AppButton('Guardar asignación', expand: true, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (saved != true) return;
    p.supervisor = supervisor;
    p.technicians = selected.toList();
    // Las visitas aún no iniciadas pasan al primer técnico si el suyo se quitó.
    for (final v in _store.visitsOf(p.id).where((v) => !v.started)) {
      v.supervisor = supervisor;
      if (!p.technicians.contains(v.technician) && p.technicians.isNotEmpty) v.technician = p.technicians.first;
    }
    if (_store.visitsOf(p.id).isEmpty && p.technicians.isNotEmpty) {
      await _store.createVisit(p, technician: p.technicians.first, motive: 'Levantamiento inicial');
    } else {
      await _store.updateProject(p);
      for (final v in _store.visitsOf(p.id).where((v) => !v.started)) {
        await _store.updateVisitAssignment(v);
      }
    }
    if (mounted) showAppSnack(context, 'Asignación actualizada', icon: Icons.check_circle_rounded, color: AppColors.success);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar proyecto?'),
        content: Text('Se borran del teléfono ${p.name}, sus visitas, fotos y documentos. No se puede deshacer.'),
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
    if (!mounted) return;
    Navigator.pop(context);
    await _store.deleteProject(p);
  }
}
