import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'camera_capture_screen.dart';

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({super.key, required this.slot, required this.group, required this.seed});
  final PhotoSlot slot;
  final PhotoGroup group;
  final int seed;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late final _commentCtrl = TextEditingController(text: widget.slot.comment);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slot;

    return DetailScaffold(
      title: s.title,
      subtitle: '${widget.group.code} ${widget.group.title}',
      actions: [
        HeaderIconButton(Icons.ios_share_rounded,
            onTap: () => showAppSnack(context, 'Compartir mediante apps del dispositivo')),
      ],
      bottomBar: Row(
        children: [
          Expanded(
            child: AppButton(
              'Reemplazar',
              icon: Icons.refresh_rounded,
              kind: AppButtonKind.secondary,
              expand: true,
              onPressed: () async {
                final ok = await push<bool>(
                  context,
                  CameraCaptureScreen(
                    slotTitle: s.title,
                    groupCode: widget.group.code,
                    groupTitle: widget.group.title,
                  ),
                  fullscreenDialog: true,
                );
                if (ok == true && context.mounted) {
                  showAppSnack(context, 'Fotografía reemplazada',
                      icon: Icons.check_circle_rounded, color: AppColors.success);
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            'Eliminar',
            icon: Icons.delete_outline_rounded,
            kind: AppButtonKind.danger,
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Positioned.fill(child: PhotoThumb(seed: widget.seed + 11, radius: 18)),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, size: 11, color: AppColors.success),
                        const SizedBox(width: 5),
                        Text('25.7834, -100.1889 · ${s.time}',
                            style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Metadatos de la evidencia'),
          GlassCard(
            child: Column(
              children: [
                KeyValue('Archivo', '${s.code}.jpg', valueColor: AppColors.accent),
                const Divider(),
                const KeyValue('Proyecto', 'TRUPER Monterrey'),
                const KeyValue('Visita', 'VIS-001 · 16 Ago 2026'),
                KeyValue('Sección', '03 Fotografías'),
                KeyValue('Subsección', '${widget.group.code} ${widget.group.title}'),
                KeyValue('Elemento', s.title),
                KeyValue('Tipo de evidencia', s.isRequired ? 'Obligatoria' : 'Opcional',
                    valueColor: s.isRequired ? AppColors.danger : AppColors.textSecondary),
                const Divider(),
                const KeyValue('Usuario', 'Juan Pérez'),
                KeyValue('Fecha y hora', '16 Ago 2026 · ${s.time}'),
                const KeyValue('Coordenadas', '25.7834, -100.1889', icon: Icons.place_rounded),
                const KeyValue('Tamaño', '4.1 MB · 4032 × 3024'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Comentario'),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Agrega una observación sobre esta evidencia…',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, size: 15, color: AppColors.blue),
                    const SizedBox(width: 7),
                    Text('Dictado por voz disponible en v2', style: T.tiny),
                    const Spacer(),
                    AppButton('Guardar', compact: true, onPressed: () {
                      setState(() => widget.slot.comment = _commentCtrl.text);
                      showAppSnack(context, 'Comentario guardado');
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            color: AppColors.surfaceAlt,
            child: Row(
              children: [
                const IconBadge(Icons.cloud_done_rounded, color: AppColors.success, size: 36),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sincronizada', style: T.h3),
                      SizedBox(height: 3),
                      Text('Subida hace 12 min · sin duplicados', style: T.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar fotografía'),
        content: const Text(
            'La evidencia se marcará como pendiente nuevamente. Sólo es posible antes de finalizar la visita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => widget.slot.captured = false);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
