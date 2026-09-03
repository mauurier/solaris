import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../shell/home_shell.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  int _step = 0;
  String _client = 'TRUPER';
  String _type = 'Viabilidad FV';
  String _template = 'Levantamiento eléctrico FV v2.3';
  final _techs = <String>{'Juan Pérez'};

  static const _steps = ['Datos', 'Ubicación', 'Equipo', 'Plantilla'];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Nuevo proyecto',
      subtitle: 'Paso ${_step + 1} de ${_steps.length} · ${_steps[_step]}',
      bottomBar: Row(
        children: [
          if (_step > 0) ...[
            AppButton('Atrás',
                kind: AppButtonKind.secondary, onPressed: () => setState(() => _step--)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: AppButton(
              _step == _steps.length - 1 ? 'Crear proyecto' : 'Continuar',
              icon: _step == _steps.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
              expand: true,
              onPressed: () {
                if (_step == _steps.length - 1) {
                  Navigator.pop(context);
                  showAppSnack(context, 'Proyecto creado (prototipo)',
                      icon: Icons.check_circle_rounded, color: AppColors.success);
                } else {
                  setState(() => _step++);
                }
              },
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(
              children: List.generate(_steps.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 6),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.accent : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_step) {
                1 => _location(),
                2 => _team(),
                3 => _templateStep(),
                _ => _data(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(String key, List<Widget> children) => ListView(
        key: ValueKey(key),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: children,
      );

  Widget _data() => _wrap('data', [
        const FieldLabel('Nombre del proyecto', required: true),
        const TextField(decoration: InputDecoration(hintText: 'Ej. TRUPER Monterrey')),
        const SizedBox(height: 18),
        const FieldLabel('Cliente', required: true),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: AppColors.surfaceAlt,
          child: Column(
            children: Mock.clients.take(4).map((c) {
              final sel = c.name == _client;
              return InkWell(
                onTap: () => setState(() => _client = c.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      InitialsAvatar(c.name.substring(0, 1), size: 32,
                          color: sel ? AppColors.accent : AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: T.h3.copyWith(fontSize: 14)),
                            Text('${c.projects} proyectos · ${c.contact}', style: T.tiny),
                          ],
                        ),
                      ),
                      Icon(
                        sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 19,
                        color: sel ? AppColors.accent : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Tipo de proyecto', required: true),
        SegmentedPicker(
          options: const ['Viabilidad FV', 'Auditoría', 'Mantenim.'],
          selected: _type,
          onSelected: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Descripción'),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(hintText: 'Alcance y consideraciones del levantamiento…'),
        ),
      ]);

  Widget _location() => _wrap('loc', [
        const FieldLabel('Nombre del sitio', required: true),
        const TextField(decoration: InputDecoration(hintText: 'Ej. CEDIS Monterrey')),
        const SizedBox(height: 18),
        const FieldLabel('Dirección', required: true),
        const TextField(
          maxLines: 2,
          decoration: InputDecoration(hintText: 'Calle, número, colonia, ciudad, estado'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Coordenadas'),
        GlassCard(
          color: AppColors.surfaceAlt,
          child: Column(
            children: [
              Row(
                children: [
                  const IconBadge(Icons.my_location_rounded, color: AppColors.blue, size: 38),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('25.7834, -100.1889', style: T.h3),
                        SizedBox(height: 3),
                        Text('Precisión ±4 m · GPS activo', style: T.tiny),
                      ],
                    ),
                  ),
                  AppButton('Fijar', compact: true, kind: AppButtonKind.secondary, onPressed: () {}),
                ],
              ),
              const SizedBox(height: 14),
              const MapPlaceholder(height: 140),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Fecha programada', required: true),
        const TextField(
          decoration: InputDecoration(
            hintText: '03 Sep 2026',
            prefixIcon: Icon(Icons.calendar_today_rounded, size: 17),
          ),
        ),
      ]);

  Widget _team() => _wrap('team', [
        const FieldLabel('Supervisor', required: true),
        GlassCard(
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const InitialsAvatar('LM', size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laura Méndez', style: T.h3.copyWith(fontSize: 14)),
                    const Text('l.mendez@solaris.mx', style: T.tiny),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Técnicos asignados', required: true, hint: 'Selección múltiple'),
        ...Mock.users.where((u) => u.role.name == 'tecnico').map((u) {
          final sel = _techs.contains(u.name);
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: GlassCard(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.all(11),
              borderColor: sel ? AppColors.accent.withValues(alpha: 0.4) : null,
              onTap: () => setState(() => sel ? _techs.remove(u.name) : _techs.add(u.name)),
              child: Row(
                children: [
                  InitialsAvatar(u.initials, size: 34, color: sel ? AppColors.accent : AppColors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name, style: T.h3.copyWith(fontSize: 14)),
                        Text('${u.projects} levantamientos', style: T.tiny),
                      ],
                    ),
                  ),
                  Icon(
                    sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 20,
                    color: sel ? AppColors.accent : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          );
        }),
      ]);

  Widget _templateStep() => _wrap('tpl', [
        const FieldLabel('Plantilla de levantamiento', required: true),
        ...Mock.templates.where((t) => t.active).map((t) {
          final sel = '${t.name} ${t.version}' == _template;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              borderColor: sel ? AppColors.accent.withValues(alpha: 0.45) : null,
              color: sel ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceAlt,
              onTap: () => setState(() => _template = '${t.name} ${t.version}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(Icons.dashboard_customize_rounded,
                          color: sel ? AppColors.accent : AppColors.textMuted, size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: T.h3),
                            const SizedBox(height: 3),
                            Text('${t.version} · ${t.sections.length} secciones · ${t.type}',
                                style: T.tiny),
                          ],
                        ),
                      ),
                      Icon(
                        sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 20,
                        color: sel ? AppColors.accent : AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        GlassCard(
          color: AppColors.surfaceAlt,
          child: Row(
            children: [
              const IconBadge(Icons.folder_special_rounded, color: AppColors.violet, size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Al crear el proyecto se genera automáticamente la estructura de carpetas y la nomenclatura de archivos.',
                  style: T.tiny,
                ),
              ),
            ],
          ),
        ),
      ]);
}

/// Mapa simulado (sin dependencias externas).
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, this.height = 150, this.label = '25.7834, -100.1889'});
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0E141C),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GridPainter()),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.place_rounded, color: AppColors.blue, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: T.tiny.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Text('Mapa simulado', style: T.tiny.copyWith(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const step = 26.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final road = Paint()
      ..color = AppColors.surfaceHigh
      ..strokeWidth = 7;
    canvas.drawLine(Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.38), road);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.42, size.height), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
