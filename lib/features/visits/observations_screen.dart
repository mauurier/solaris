import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/signature_pad.dart';
import '../shell/home_shell.dart';

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> {
  final _sigKey = GlobalKey<SignaturePadState>();
  bool _signed = false;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '08 Observaciones y Firma',
      subtitle: 'Cierre de la visita VIS-001',
      bottomBar: AppButton(
        'Guardar y firmar',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: _signed
            ? () {
                Navigator.pop(context);
                showAppSnack(context, 'Observaciones y firma registradas',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              }
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Observaciones generales de la visita'),
          const TextField(
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'Resumen del levantamiento, condiciones encontradas y comentarios para el ingeniero…',
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            color: AppColors.surfaceAlt,
            onTap: () => showAppSnack(context, 'Dictado por voz: función prevista para v2',
                icon: Icons.auto_awesome_rounded),
            child: Row(
              children: [
                const IconBadge(Icons.mic_rounded, color: AppColors.blue, size: 36),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dictar observaciones', style: T.h3),
                      SizedBox(height: 3),
                      Text('Convierte tu voz en texto (v2)', style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Conclusión preliminar'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('¿El sitio es viable para instalación FV?'),
                SegmentedPicker(
                  options: const ['Viable', 'Con reservas', 'No viable'],
                  selected: 'Con reservas',
                  onSelected: (_) {},
                  activeColor: AppColors.warning,
                ),
                const SizedBox(height: 14),
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: 'Justificación técnica de la conclusión…'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionLabel(
            'Firma del técnico',
            trailing: GestureDetector(
              onTap: () {
                _sigKey.currentState?.clear();
                setState(() => _signed = false);
              },
              child: Text('Limpiar',
                  style: T.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SignaturePad(
                  key: _sigKey,
                  onChanged: (has) => setState(() => _signed = has),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _signed ? Icons.check_circle_rounded : Icons.draw_rounded,
                      size: 14,
                      color: _signed ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _signed ? 'Firmado por Juan Pérez · 16 Ago 2026' : 'Firma con el dedo',
                      style: T.tiny.copyWith(
                          color: _signed ? AppColors.success : AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
