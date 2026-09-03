import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../shell/home_shell.dart';

class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({super.key});

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  String _point = 'Tablero Principal';
  String _family = 'Tensión';
  String _instrument = 'Fluke 376 FC';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Nueva medición',
      subtitle: 'TRUPER Monterrey · VIS-001',
      bottomBar: AppButton(
        'Guardar medición',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: () {
          Navigator.pop(context);
          showAppSnack(context, 'Medición registrada con usuario, hora y ubicación',
              icon: Icons.check_circle_rounded, color: AppColors.success);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Punto de medición', required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Tablero Principal', 'Tablero 01', 'Tablero 02', 'Tablero 03', 'Transformador 01']
                .map((p) {
              final sel = p == _point;
              return GestureDetector(
                onTap: () => setState(() => _point = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.warning.withValues(alpha: 0.13) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? AppColors.warning.withValues(alpha: 0.45) : AppColors.border),
                  ),
                  child: Text(p,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? AppColors.warning : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Tipo de parámetro', required: true),
          SegmentedPicker(
            options: const ['Tensión', 'Corriente', 'Otros'],
            selected: _family,
            onSelected: (v) => setState(() => _family = v),
            activeColor: AppColors.warning,
          ),
          const SizedBox(height: 20),
          if (_family == 'Tensión') _voltageBlock(),
          if (_family == 'Corriente') _currentBlock(),
          if (_family == 'Otros') _otherBlock(),
          const SizedBox(height: 20),
          const FieldLabel('Instrumento utilizado', required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Fluke 376 FC', 'Megger DET3TC', 'FLIR E8', 'Otro'].map((p) {
              final sel = p == _instrument;
              return GestureDetector(
                onTap: () => setState(() => _instrument = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.blue.withValues(alpha: 0.13) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? AppColors.blue.withValues(alpha: 0.45) : AppColors.border),
                  ),
                  child: Text(p,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: sel ? AppColors.blue : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Observación'),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Condiciones de la medición…'),
          ),
          const SizedBox(height: 18),
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Column(
              children: [
                KeyValue('Usuario', 'Juan Pérez'),
                KeyValue('Fecha y hora', '16 Ago 2026 · 13:18'),
                KeyValue('Ubicación', '25.7834, -100.1889', icon: Icons.place_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voltageBlock() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Fase – Fase', padding: EdgeInsets.only(bottom: 10)),
          Row(
            children: [
              Expanded(child: _valueField('L1-L2', '441.2')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L2-L3', '440.8')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L1-L3', '442.0')),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Fase – Neutro', padding: EdgeInsets.only(bottom: 10)),
          Row(
            children: [
              Expanded(child: _valueField('L1-N', '254.6')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L2-N', '254.1')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L3-N', '255.0')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: SectionLabel('Fase – Tierra', padding: EdgeInsets.only(bottom: 10)),
              ),
              const StatusPill('Obligatorio', color: AppColors.danger, dense: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _valueField('L1-T', '')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L2-T', '')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L3-T', '')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currentBlock() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Corriente por fase', padding: EdgeInsets.only(bottom: 10)),
          Row(
            children: [
              Expanded(child: _valueField('L1', '312.4', unit: 'A')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L2', '298.7', unit: 'A')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('L3', '305.1', unit: 'A')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _valueField('Neutro', '18.2', unit: 'A')),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Desbalance calculado: 4.3 % (dentro de norma)',
                    style: T.tiny.copyWith(color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherBlock() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Parámetro'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Frecuencia', 'Factor de potencia', 'Potencia', 'Energía', 'Temperatura',
                    'Resistencia de tierra', 'Armónicos']
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(p, style: T.small),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _valueField('Valor', '3.8')),
              const SizedBox(width: 10),
              Expanded(child: _valueField('Unidad', 'Ω')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueField(String label, String value, {String unit = 'V'}) {
    final empty = value.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.tiny.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: T.h3.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: '—',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            fillColor: empty ? AppColors.danger.withValues(alpha: 0.06) : AppColors.surfaceHigh,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: empty ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text(unit, style: T.tiny)),
      ],
    );
  }
}
