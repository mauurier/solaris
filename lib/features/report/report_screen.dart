import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/formatting.dart';
import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';

/// Genera el reporte PDF de la visita en el teléfono (sin conexión) con las
/// partes que se elijan, lo muestra y lo comparte con el menú del sistema.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.visit});
  final FieldVisit visit;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

/// Un bloque de la plantilla en esta visita: "Transformador 2", "Tablero 01".
class _Block {
  const _Block(this.group, this.instance, this.name);
  final GroupDef group;
  final int instance;
  final String name;
}

class _ReportScreenState extends State<ReportScreen> {
  final _store = SurveyStore.instance;
  late final _service = ReportService(_store);
  final _options = ReportOptions();
  final _expanded = <String>{};
  File? _pdf;
  bool _working = false;
  String _progress = '';

  FieldVisit get v => widget.visit;

  /// Cambia la selección; el PDF que ya estaba deja de corresponder.
  void _change(VoidCallback f) => setState(() {
        f();
        _pdf = null;
      });

  List<_Block> _blocks(SectionDef s) {
    final engine = _store.engineFor(v);
    return [
      for (final g in s.groups)
        for (var i = 0; i < engine.instanceCount(g); i++) _Block(g, i, g.repeatable ? g.instanceName(i) : g.title),
    ];
  }

  bool get _nothingSelected {
    final t = _store.templateFor(v);
    final anyBlock = t.sections.any((s) => _blocks(s).any((b) => _options.includes(b.group, b.instance)));
    return !anyBlock && !_options.summary && !(_options.findings && _store.findingsOf(v.id).isNotEmpty);
  }

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _progress = 'Preparando…';
    });
    try {
      final bytes = await _service.build(v, options: _options.copy(), onProgress: (done, total) {
        if (mounted) setState(() => _progress = 'Preparando fotos $done de $total…');
      });
      final dir = Directory('${(await getTemporaryDirectory()).path}/reportes');
      await dir.create(recursive: true);
      final file = File('${dir.path}/${_service.fileName(v)}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _pdf = file);
      showAppSnack(context, 'Reporte generado · ${fmtBytes(bytes.length)}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
      _open();
    } catch (e, st) {
      debugPrint('Reporte: $e\n$st');
      if (mounted) {
        showAppSnack(context, 'No se pudo generar el reporte. Revisa que las fotos sigan en el teléfono e intenta de nuevo.',
            color: AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _open() {
    final pdf = _pdf;
    if (pdf == null) return;
    push(context, ReportPreviewScreen(file: pdf, title: _service.fileName(v)));
  }

  @override
  Widget build(BuildContext context) {
    final project = _store.project(v.projectId);
    final template = _store.templateFor(v);
    final findings = _store.findingsOf(v.id).length;
    final photos = _service.imagesFor(v, _options).length;
    final pdf = _pdf;

    return DetailScaffold(
      title: 'Reporte PDF',
      subtitle: '${project?.code ?? ''} · ${v.label}',
      bottomBar: pdf == null
          ? AppButton(
              _working
                  ? _progress
                  : _nothingSelected
                      ? 'Elige qué incluir'
                      : 'Generar PDF',
              icon: Icons.picture_as_pdf_rounded,
              expand: true,
              onPressed: _working || _nothingSelected ? null : _generate,
            )
          : Row(
              children: [
                Expanded(
                  child: AppButton('Ver', icon: Icons.visibility_rounded, kind: AppButtonKind.secondary,
                      expand: true, onPressed: _open),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (buttonContext) => AppButton('Compartir',
                        icon: Icons.ios_share_rounded, expand: true, onPressed: () => sharePdf(buttonContext, pdf)),
                  ),
                ),
              ],
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          if (!v.finished) ...[
            const InfoBanner('La visita sigue abierta: el reporte sale con lo capturado hasta ahora.',
                icon: Icons.edit_note_rounded),
            const SizedBox(height: 14),
          ],
          if (pdf != null) ...[
            GlassCard(
              color: AppColors.surfaceAlt,
              onTap: _open,
              child: Row(
                children: [
                  const IconBadge(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_service.fileName(v), style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('${fmtBytes(pdf.lengthSync())} · toca para verlo', style: T.tiny),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _working ? null : _generate, child: const Text('Rehacer')),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SectionLabel('Qué incluye'),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                _switchRow(Icons.description_rounded, 'Portada', 'Proyecto, cliente, sitio, equipo y fechas', true, null),
                _switchRow(Icons.summarize_rounded, 'Resumen', 'Avance, hallazgos por severidad y datos de la visita',
                    _options.summary, (x) => _change(() => _options.summary = x)),
                if (findings > 0)
                  _switchRow(Icons.report_problem_rounded, 'Hallazgos',
                      findings == 1 ? '1 hallazgo con sus fotos' : '$findings hallazgos con sus fotos',
                      _options.findings, (x) => _change(() => _options.findings = x)),
                _switchRow(Icons.photo_camera_rounded, 'Fotos',
                    _options.photos ? '$photos fotos y firmas, reducidas para que pese poco' : 'Sólo se indica cuántas hay',
                    _options.photos, (x) => _change(() => _options.photos = x)),
                _switchRow(Icons.filter_alt_rounded, 'Sólo lo respondido', 'Omite las preguntas sin respuesta',
                    _options.skipUnanswered, (x) => _change(() => _options.skipUnanswered = x)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionLabel(
            'Secciones de "${template.name}"',
            trailing: TextButton(
              onPressed: () => _change(() {
                final all = _options.excludedBlocks.isEmpty;
                _options.excludedBlocks.clear();
                if (all) {
                  for (final s in template.sections) {
                    for (final b in _blocks(s)) {
                      _options.excludedBlocks.add(ReportOptions.blockKey(b.group, b.instance));
                    }
                  }
                }
              }),
              child: Text(_options.excludedBlocks.isEmpty ? 'Quitar todas' : 'Incluir todas'),
            ),
          ),
          for (var i = 0; i < template.sections.length; i++) _sectionCard(i, template.sections[i]),
          const SizedBox(height: 6),
          const Text('Videos y documentos se listan por nombre; completos van en el ZIP.', style: T.tiny),
        ],
      ),
    );
  }

  Widget _sectionCard(int index, SectionDef s) {
    final blocks = _blocks(s);
    final included = blocks.where((b) => _options.includes(b.group, b.instance)).length;
    final open = _expanded.contains(s.id);
    final state = included == 0
        ? false
        : included == blocks.length
            ? true
            : null;
    final progress = _store.engineFor(v).sectionProgress(s);

    void setAll(bool on) => _change(() {
          for (final b in blocks) {
            final key = ReportOptions.blockKey(b.group, b.instance);
            on ? _options.excludedBlocks.remove(key) : _options.excludedBlocks.add(key);
          }
        });

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: blocks.length > 1 ? () => setState(() => open ? _expanded.remove(s.id) : _expanded.add(s.id)) : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: state,
                      tristate: true,
                      onChanged: blocks.isEmpty ? null : (_) => setAll(state != true),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${index + 1}. ${s.title}', style: T.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${progress.answered}/${progress.total} respondidas'
                            '${blocks.length > 1 ? ' · $included de ${blocks.length} bloques' : ''}',
                            style: T.tiny,
                          ),
                        ],
                      ),
                    ),
                    if (blocks.length > 1)
                      Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            if (open && blocks.length > 1) ...[
              const Divider(height: 1, color: AppColors.border),
              for (final b in blocks)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.only(left: 28, right: 12),
                  value: _options.includes(b.group, b.instance),
                  title: Text(b.name, style: T.small.copyWith(color: AppColors.textPrimary)),
                  onChanged: (x) => _change(() {
                    final key = ReportOptions.blockKey(b.group, b.instance);
                    x == true ? _options.excludedBlocks.remove(key) : _options.excludedBlocks.add(key);
                  }),
                ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchRow(IconData icon, String title, String sub, bool value, ValueChanged<bool>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(sub, style: T.tiny),
              ],
            ),
          ),
          Transform.scale(scale: 0.78, child: Switch(value: value, onChanged: onChanged)),
        ],
      ),
    );
  }
}

/// Comparte el PDF con el menú del sistema; [buttonContext] ubica el menú en
/// iPad.
Future<void> sharePdf(BuildContext buttonContext, File pdf) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    files: [XFile(pdf.path, mimeType: 'application/pdf')],
    subject: pdf.uri.pathSegments.last,
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}

/// El PDF tal como quedó, página por página, dentro de la app.
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key, required this.file, required this.title});
  final File file;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Vista previa',
      subtitle: title,
      actions: [
        Builder(
          builder: (buttonContext) =>
              HeaderIconButton(Icons.ios_share_rounded, onTap: () => sharePdf(buttonContext, file)),
        ),
      ],
      child: PdfPreview(
        build: (_) => file.readAsBytes(),
        useActions: false,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: title,
        maxPageWidth: 700,
        scrollViewDecoration: const BoxDecoration(color: Colors.transparent),
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (_, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('No se pudo mostrar el PDF. Puedes compartirlo y abrirlo con otra app.\n\n$error',
                style: T.small, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
