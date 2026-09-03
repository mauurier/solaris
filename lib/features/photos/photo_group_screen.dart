import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'camera_capture_screen.dart';
import 'photo_detail_screen.dart';

class PhotoGroupScreen extends StatefulWidget {
  const PhotoGroupScreen({super.key, required this.group});
  final PhotoGroup group;

  @override
  State<PhotoGroupScreen> createState() => _PhotoGroupScreenState();
}

class _PhotoGroupScreenState extends State<PhotoGroupScreen> {
  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final pending = g.slots.where((s) => !s.captured).toList();

    return DetailScaffold(
      title: '${g.code} ${g.title}',
      subtitle: '${g.captured} de ${g.slots.length} evidencias',
      bottomBar: AppButton(
        pending.isEmpty ? 'Agregar fotografía extra' : 'Capturar siguiente pendiente',
        icon: Icons.photo_camera_rounded,
        expand: true,
        onPressed: () => _capture(pending.isEmpty ? null : pending.first),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          LinearMeter(
            label: 'Avance de la subsección',
            value: g.progress,
            color: g.requiredPending > 0 ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(height: 20),
          if (g.requiredPending > 0) ...[
            const SectionLabel('Evidencias obligatorias pendientes'),
            ...g.slots.where((s) => s.isRequired && !s.captured).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      borderColor: AppColors.danger.withValues(alpha: 0.3),
                      color: AppColors.danger.withValues(alpha: 0.05),
                      onTap: () => _capture(s),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.add_a_photo_rounded,
                                color: AppColors.danger, size: 22),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title, style: T.h3),
                                const SizedBox(height: 4),
                                Text(s.code, style: T.mono),
                              ],
                            ),
                          ),
                          const Icon(Icons.photo_camera_rounded,
                              size: 19, color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
          ],
          const SectionLabel('Todas las evidencias'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: g.slots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, i) => _slotTile(g.slots[i], i),
          ),
        ],
      ),
    );
  }

  Widget _slotTile(PhotoSlot s, int i) {
    return GestureDetector(
      onTap: () async {
        if (s.captured) {
          await push(context, PhotoDetailScreen(slot: s, group: widget.group, seed: i));
          if (mounted) setState(() {});
        } else {
          _capture(s);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PhotoThumb(seed: widget.group.code.hashCode + i, captured: s.captured),
                ),
                if (s.captured)
                  Positioned(
                    left: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(s.time,
                          style: const TextStyle(fontSize: 9.5, color: Colors.white)),
                    ),
                  ),
                Positioned(
                  right: 7,
                  top: 7,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: s.captured
                          ? AppColors.success.withValues(alpha: 0.9)
                          : (s.isRequired ? AppColors.danger : AppColors.textMuted)
                              .withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s.captured ? Icons.check_rounded : Icons.priority_high_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(s.title, style: T.small.copyWith(fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(
            children: [
              if (s.isRequired)
                const Text('Obligatoria',
                    style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600))
              else
                const Text('Opcional', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _capture(PhotoSlot? s) async {
    final ok = await push<bool>(
      context,
      CameraCaptureScreen(
        slotTitle: s?.title ?? 'Fotografía adicional',
        groupCode: widget.group.code,
        groupTitle: widget.group.title,
      ),
      fullscreenDialog: true,
    );
    if (ok == true && s != null && mounted) {
      setState(() {
        s.captured = true;
        s.time = '13:0${widget.group.captured % 9}';
      });
      showAppSnack(context, 'Evidencia guardada como ${s.code}.jpg',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    }
  }
}
