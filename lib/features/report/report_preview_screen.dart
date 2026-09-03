import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../export/export_screen.dart';
import '../shell/home_shell.dart';

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({super.key, required this.project});
  final Project project;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  String _template = 'Reporte FV estándar';
  bool _generating = false;
  bool _generated = false;

  final _sections = <String, bool>{
    'Portada': true,
    'Información general': true,
    'Información eléctrica': true,
    'Información de cubierta': true,
    'Transformadores': true,
    'Tableros': true,
    'Sistema FV existente': true,
    'Mediciones': true,
    'Hallazgos': true,
    'Observaciones': true,
    'Evidencia fotográfica': true,
    'Conclusiones': true,
    'Firmas': true,
  };

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Reporte técnico',
      subtitle: '${widget.project.name} · v1.2',
      actions: [
        HeaderIconButton(Icons.ios_share_rounded,
            onTap: () => push(context, ExportScreen(project: widget.project))),
      ],
      bottomBar: AppButton(
        _generated ? 'Compartir PDF' : 'Generar reporte PDF',
        icon: _generated ? Icons.ios_share_rounded : Icons.auto_awesome_rounded,
        expand: true,
        onPressed: _generating
            ? null
            : () async {
                if (_generated) {
                  push(context, ExportScreen(project: widget.project));
                  return;
                }
                setState(() => _generating = true);
                await Future.delayed(const Duration(milliseconds: 1400));
                if (!context.mounted) return;
                setState(() {
                  _generating = false;
                  _generated = true;
                });
                showAppSnack(context, 'REPORTE_TRUPER_MTY_v1.2.pdf generado',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          _coverPreview(),
          const SizedBox(height: 20),
          const SectionLabel('Plantilla de reporte'),
          SegmentedPicker(
            options: const ['Reporte FV estándar', 'Formato cliente'],
            selected: _template,
            onSelected: (v) => setState(() => _template = v),
          ),
          const SizedBox(height: 10),
          GlassCard(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _template == 'Reporte FV estándar'
                        ? 'Portada, encabezados, pie de página y numeración corporativos.'
                        : 'Formato con logotipo y estructura definidos por el cliente TRUPER.',
                    style: T.tiny,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(
            'Secciones del reporte',
            trailing: Text('${_sections.values.where((v) => v).length} activas', style: T.tiny),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: _sections.keys.map((k) {
                final i = _sections.keys.toList().indexOf(k);
                return Column(
                  children: [
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text((i + 1).toString().padLeft(2, '0'),
                              style: T.mono.copyWith(color: AppColors.textMuted)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(k, style: T.body.copyWith(fontSize: 13.5))),
                          Transform.scale(
                            scale: 0.78,
                            child: Switch(
                              value: _sections[k]!,
                              onChanged: (v) => setState(() => _sections[k] = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Inserción automática de evidencia'),
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const IconBadge(Icons.auto_awesome_mosaic_rounded,
                        color: AppColors.accent, size: 40),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Las 22 fotografías se insertan en la sección correspondiente con su pie de foto y coordenadas.',
                        style: T.small,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                  ),
                  itemBuilder: (_, i) => PhotoThumb(seed: i + 20, radius: 8),
                ),
              ],
            ),
          ),
          if (_generating) ...[
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      const SizedBox(width: 13),
                      Expanded(child: Text('Componiendo el reporte…', style: T.h3)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const LinearMeter(label: 'Insertando evidencia fotográfica', value: 0.62),
                ],
              ),
            ),
          ],
          if (_generated) ...[
            const SizedBox(height: 20),
            GlassCard(
              borderColor: AppColors.success.withValues(alpha: 0.3),
              color: AppColors.success.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const IconBadge(Icons.picture_as_pdf_rounded, color: AppColors.success, size: 42),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REPORTE_TRUPER_MTY_v1.2.pdf', style: T.h3),
                        const SizedBox(height: 4),
                        Text('48 páginas · 22 fotografías · 8.4 MB', style: T.tiny),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverPreview() {
    return AspectRatio(
      aspectRatio: 1 / 1.32,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15191F),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMark(size: 34, radiusFactor: 0.28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('SOLARIS',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                            color: AppColors.textPrimary)),
                  ),
                  Text('v1.2', style: T.tiny),
                ],
              ),
              const SizedBox(height: 26),
              Text('REPORTE DE LEVANTAMIENTO TÉCNICO', style: T.overline),
              const SizedBox(height: 10),
              Text(widget.project.name, style: T.display.copyWith(fontSize: 25)),
              const SizedBox(height: 6),
              Text(widget.project.site, style: T.bodyMuted),
              const SizedBox(height: 22),
              Container(height: 2, width: 48, color: AppColors.accent),
              const SizedBox(height: 22),
              _coverRow('Cliente', widget.project.client),
              _coverRow('Tipo', widget.project.type),
              _coverRow('Fecha', '16 Ago 2026'),
              _coverRow('Técnico', widget.project.responsible),
              _coverRow('Supervisor', widget.project.supervisor),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 1, color: AppColors.border),
                        const SizedBox(height: 5),
                        Text('Firma del técnico', style: T.tiny),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 1, color: AppColors.border),
                        const SizedBox(height: 5),
                        Text('Firma del supervisor', style: T.tiny),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(child: Text('Página 1 de 48', style: T.tiny)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(k, style: T.tiny)),
          Expanded(
            child: Text(v, style: T.small.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
