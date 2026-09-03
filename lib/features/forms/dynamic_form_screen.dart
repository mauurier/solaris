import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../main.dart';
import '../photos/camera_capture_screen.dart';
import '../shell/home_shell.dart';

class DynamicFormScreen extends StatefulWidget {
  const DynamicFormScreen({super.key});

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  bool? _hasFv = true;
  bool? _hasTransformer = true;
  String _roof = 'Lámina galvanizada';
  String _building = 'Nave industrial';
  String _voltage = '440 V';
  String _tariff = 'GDMTO';
  bool _plateCaptured = false;

  double get _progress {
    var total = 12;
    var done = 10;
    if (_hasFv == true) {
      total += 5;
      done += 4;
    }
    if (_plateCaptured) done += 1;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '01 Información del Sitio',
      subtitle: 'TRUPER Monterrey · VIS-001',
      bottomBar: Row(
        children: [
          Expanded(
            child: AppButton(
              'Guardar sección',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                showAppSnack(context, 'Sección guardada · sincronización pendiente',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              },
            ),
          ),
          const SizedBox(width: 10),
          AppButton('Borrador',
              kind: AppButtonKind.secondary,
              onPressed: () => showAppSnack(context, 'Guardado local automático activo')),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          _progressHeader(),
          const SizedBox(height: 20),
          _group('1.1 Datos generales', [
            const FieldLabel('Nombre del sitio', required: true),
            _text('CEDIS Monterrey'),
            const SizedBox(height: 16),
            const FieldLabel('Tipo de inmueble', required: true),
            _choices(
              ['Nave industrial', 'Oficinas', 'Centro comercial', 'Terreno'],
              _building,
              (v) => setState(() => _building = v),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Superficie de cubierta (m²)', required: true),
            _text('12,480', suffix: 'm²', number: true),
            const SizedBox(height: 16),
            const FieldLabel('Tipo de cubierta', required: true),
            _choices(
              ['Lámina galvanizada', 'Losa de concreto', 'Panel sándwich', 'Otro'],
              _roof,
              (v) => setState(() => _roof = v),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Altura de cubierta (m)'),
            _text('9.4', suffix: 'm', number: true),
          ]),
          const SizedBox(height: 16),
          _group('1.2 Servicio eléctrico', [
            const FieldLabel('Tensión de servicio', required: true),
            SegmentedPicker(
              options: const ['220 V', '440 V', '13.8 kV', '23 kV'],
              selected: _voltage,
              onSelected: (v) => setState(() => _voltage = v),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Tarifa CFE', required: true),
            _choices(['GDMTO', 'GDMTH', 'PDBT', 'DIST'], _tariff, (v) => setState(() => _tariff = v)),
            const SizedBox(height: 16),
            const FieldLabel('Demanda contratada (kW)', required: true),
            _text('850', suffix: 'kW', number: true),
            const SizedBox(height: 16),
            const FieldLabel('Consumo promedio mensual (kWh)'),
            _text('312,400', suffix: 'kWh', number: true),
          ]),
          const SizedBox(height: 16),
          _group('1.3 Transformación', [
            _yesNo(
              '¿Existe transformador propio en sitio?',
              _hasTransformer,
              (v) => setState(() => _hasTransformer = v),
            ),
            if (_hasTransformer == true) ...[
              const SizedBox(height: 16),
              _conditionalBanner('Campos habilitados por la respuesta anterior'),
              const SizedBox(height: 14),
              const FieldLabel('Número de transformadores', required: true),
              _text('2', number: true),
              const SizedBox(height: 16),
              const FieldLabel('Capacidad total instalada (kVA)', required: true),
              _text('1,250', suffix: 'kVA', number: true),
              const SizedBox(height: 16),
              const FieldLabel('Evidencia: placa de datos', required: true),
              _photoField(),
            ],
          ]),
          const SizedBox(height: 16),
          _group('1.4 Sistema fotovoltaico', [
            _yesNo('¿Existe sistema FV instalado?', _hasFv, (v) => setState(() => _hasFv = v)),
            if (_hasFv == true) ...[
              const SizedBox(height: 16),
              _conditionalBanner('5 campos condicionales habilitados'),
              const SizedBox(height: 14),
              const FieldLabel('Número de módulos', required: true),
              _text('714', number: true),
              const SizedBox(height: 16),
              const FieldLabel('Fabricante', required: true),
              _text('Jinko Solar'),
              const SizedBox(height: 16),
              const FieldLabel('Modelo', required: true),
              _text('Tiger Neo 580W'),
              const SizedBox(height: 16),
              const FieldLabel('Potencia instalada', required: true),
              _text('414.1', suffix: 'kWp', number: true),
              const SizedBox(height: 16),
              const FieldLabel('Número de inversores', required: true),
              _text('4', number: true),
              const SizedBox(height: 16),
              const FieldLabel('Tipo de canalización'),
              _choices(const ['Charola', 'Tubería conduit', 'Ducto'], 'Charola', (_) {}),
            ] else if (_hasFv == false)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _infoBanner(
                  'Los campos de sistema FV existente se ocultan y no se solicitarán en el reporte.',
                ),
              ),
          ]),
          const SizedBox(height: 16),
          _group('1.5 Condiciones del sitio', [
            const FieldLabel('Sombreados relevantes'),
            _choices(const ['Ninguno', 'Parcial', 'Significativo'], 'Parcial', (_) {}),
            const SizedBox(height: 16),
            const FieldLabel('Observaciones'),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                  hintText: 'Notas relevantes del sitio (accesos, horarios, restricciones)…'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _progressHeader() {
    return GlassCard(
      child: Row(
        children: [
          ProgressRing(value: _progress, size: 58, stroke: 5, color: AppColors.blue),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formulario dinámico', style: T.h3),
                SizedBox(height: 4),
                Text('Los campos condicionales aparecen según tus respuestas.', style: T.tiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }

  Widget _text(String value, {String? suffix, bool number = false}) {
    return TextField(
      controller: TextEditingController(text: value),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: T.body,
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: T.small.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _choices(List<String> options, String selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = o == selected;
        return GestureDetector(
          onTap: () => onTap(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border,
              ),
            ),
            child: Text(
              o,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                color: sel ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _yesNo(String question, bool? value, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(question, style: T.body.copyWith(fontWeight: FontWeight.w500))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Obligatorio',
                  style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _yesNoButton('Sí', value == true, () => onChanged(true), AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _yesNoButton('No', value == false, () => onChanged(false), AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _yesNoButton(String label, bool sel, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.14) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              sel ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 17,
              color: sel ? color : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sel ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionalBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.call_split_rounded, size: 14, color: AppColors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: T.tiny.copyWith(color: AppColors.blue))),
        ],
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: T.tiny)),
        ],
      ),
    );
  }

  Widget _photoField() {
    return GestureDetector(
      onTap: () async {
        final ok = await Navigator.of(context).push<bool>(
          appRoute(
            const CameraCaptureScreen(
              slotTitle: 'Transformador 01 – placa de datos',
              groupCode: '3.3',
              groupTitle: 'Acometida, Medidor y Transformador',
            ),
            fullscreenDialog: true,
          ),
        );
        if (ok == true) setState(() => _plateCaptured = true);
      },
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: _plateCaptured
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.danger.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            if (_plateCaptured)
              const SizedBox(width: 68, height: 68, child: PhotoThumb(seed: 2))
            else
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: AppColors.danger, size: 24),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_plateCaptured ? 'Evidencia capturada' : 'Evidencia pendiente', style: T.h3),
                  const SizedBox(height: 4),
                  Text(
                    _plateCaptured
                        ? 'TRANSFORMADOR_PLACA_001.jpg · 11:02'
                        : 'Toca para abrir la cámara',
                    style: T.tiny,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
