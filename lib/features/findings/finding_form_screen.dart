import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../photos/camera_capture_screen.dart';
import '../shell/home_shell.dart';

class FindingFormScreen extends StatefulWidget {
  const FindingFormScreen({super.key, this.finding});
  final Finding? finding;

  @override
  State<FindingFormScreen> createState() => _FindingFormScreenState();
}

class _FindingFormScreenState extends State<FindingFormScreen> {
  late String _category = widget.finding?.category ?? 'Eléctrico';
  late Severity _severity = widget.finding?.severity ?? Severity.media;
  late FindingStatus _status = widget.finding?.status ?? FindingStatus.abierto;

  static const _categories = [
    'Eléctrico',
    'Estructural',
    'Cubierta',
    'Seguridad',
    'Termográfico',
    'Documental',
    'Civil',
    'Otro',
  ];

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final isNew = f == null;

    return DetailScaffold(
      title: isNew ? 'Nuevo hallazgo' : f.id,
      subtitle: isNew ? 'TRUPER Monterrey · VIS-001' : f.date,
      bottomBar: AppButton(
        isNew ? 'Registrar hallazgo' : 'Guardar cambios',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: () {
          Navigator.pop(context);
          showAppSnack(context, isNew ? 'Hallazgo registrado' : 'Hallazgo actualizado',
              icon: Icons.check_circle_rounded, color: AppColors.success);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const FieldLabel('Categoría', required: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final sel = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.danger.withValues(alpha: 0.13) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? AppColors.danger.withValues(alpha: 0.45) : AppColors.border),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? AppColors.danger : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Severidad', required: true),
          Row(
            children: Severity.values.map((s) {
              final sel = s == _severity;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == Severity.critica ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _severity = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? s.color.withValues(alpha: 0.15) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? s.color.withValues(alpha: 0.5) : AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: sel ? s.color : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(s.label,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                                  color: sel ? s.color : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Descripción', required: true),
          TextField(
            controller: TextEditingController(text: f?.description ?? ''),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Describe el hallazgo…'),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Ubicación', required: true),
          TextField(
            controller: TextEditingController(text: f?.location ?? ''),
            decoration: const InputDecoration(
              hintText: 'Ej. Cuarto eléctrico · Tablero Principal',
              prefixIcon: Icon(Icons.place_rounded, size: 17),
            ),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Recomendación'),
          TextField(
            controller: TextEditingController(text: f?.recommendation ?? ''),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Acción sugerida…'),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Estado'),
          SegmentedPicker(
            options: FindingStatus.values.map((s) => s.label).toList(),
            selected: _status.label,
            onSelected: (v) => setState(() =>
                _status = FindingStatus.values.firstWhere((s) => s.label == v)),
            activeColor: _status.color,
          ),
          const SizedBox(height: 20),
          const SectionLabel('Evidencias relacionadas'),
          GlassCard(
            child: SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: (f?.evidences ?? 0) + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == (f?.evidences ?? 0)) {
                    return GestureDetector(
                      onTap: () => push(
                        context,
                        CameraCaptureScreen(
                          slotTitle: 'Evidencia del hallazgo',
                          groupCode: '3.5',
                          groupTitle: 'Generales',
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
                      width: 84, child: PhotoThumb(seed: (f?.id.hashCode ?? 5) + i));
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Column(
              children: [
                KeyValue('Usuario', f?.user ?? 'Juan Pérez'),
                KeyValue('Fecha', f?.date ?? '16 Ago 2026 · 13:22'),
                const KeyValue('Coordenadas', '25.7834, -100.1889', icon: Icons.place_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
