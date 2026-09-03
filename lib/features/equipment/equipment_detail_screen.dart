import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../photos/camera_capture_screen.dart';
import '../shell/home_shell.dart';

class EquipmentDetailScreen extends StatelessWidget {
  const EquipmentDetailScreen({super.key, this.equipment});
  final Equipment? equipment;

  @override
  Widget build(BuildContext context) {
    final e = equipment;
    final isNew = e == null;

    return DetailScaffold(
      title: isNew ? 'Registrar equipo' : e.name,
      subtitle: isNew ? 'TRUPER Monterrey · VIS-001' : '${e.id} · ${e.category}',
      bottomBar: AppButton(
        isNew ? 'Guardar equipo' : 'Guardar cambios',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: () {
          Navigator.pop(context);
          showAppSnack(context, 'Equipo guardado',
              icon: Icons.check_circle_rounded, color: AppColors.success);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Tipo de equipo', required: true),
          SegmentedPicker(
            options: const ['Transformador', 'Tablero', 'Inversor'],
            selected: e?.category ?? 'Tablero',
            onSelected: (_) {},
            activeColor: AppColors.blue,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Identificador', required: true),
          _field(e?.name ?? '', hint: 'Ej. Tablero 04'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Fabricante', required: true),
                    _field(e?.brand ?? '', hint: 'Marca'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Modelo', required: true),
                    _field(e?.model ?? '', hint: 'Modelo'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Número de serie', required: true),
          _field(e?.serial == '—' ? '' : (e?.serial ?? ''), hint: 'Número de serie'),
          const SizedBox(height: 16),
          const FieldLabel('Capacidad / características', required: true),
          _field(e?.capacity ?? '', hint: 'Ej. 400 A · 440 V'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Tensión'),
                    _field('440', hint: 'V'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Corriente'),
                    _field('400', hint: 'A'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Ubicación', required: true),
          _field(e?.location ?? '', hint: 'Ej. Cuarto eléctrico'),
          const SizedBox(height: 18),
          const SectionLabel('Evidencia fotográfica'),
          GlassCard(
            child: Column(
              children: [
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (e?.photos ?? 0) + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == (e?.photos ?? 0)) {
                        return GestureDetector(
                          onTap: () => push(
                            context,
                            CameraCaptureScreen(
                              slotTitle: e?.name ?? 'Equipo nuevo',
                              groupCode: '3.4',
                              groupTitle: 'Tableros y Canalizaciones',
                            ),
                            fullscreenDialog: true,
                          ),
                          child: Container(
                            width: 84,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                size: 21, color: AppColors.textMuted),
                          ),
                        );
                      }
                      return SizedBox(
                        width: 84,
                        child: PhotoThumb(seed: (e?.id.hashCode ?? 3) + i),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.folder_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Las fotografías se archivan bajo 3.4 Tableros y Canalizaciones › ${e?.name ?? "nuevo equipo"}',
                        style: T.tiny,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Observaciones'),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Estado, anomalías o comentarios…'),
          ),
        ],
      ),
    );
  }

  Widget _field(String value, {required String hint}) {
    final empty = value.isEmpty;
    return TextField(
      controller: TextEditingController(text: value),
      style: T.body,
      decoration: InputDecoration(
        hintText: hint,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: empty ? AppColors.danger.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
      ),
    );
  }
}
