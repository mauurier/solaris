import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'video_record_screen.dart';

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '04 Videos',
      subtitle: '${Mock.videos.length} archivos · 429 MB',
      bottomBar: AppButton(
        'Grabar video',
        icon: Icons.videocam_rounded,
        expand: true,
        onPressed: () => push(context, const VideoRecordScreen(), fullscreenDialog: true),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const SectionLabel('Tipos requeridos por la plantilla'),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                NavRow(
                  dense: true,
                  title: 'Recorrido general',
                  subtitle: 'Desde punto de interconexión hacia instalaciones',
                  icon: Icons.directions_walk_rounded,
                  iconColor: AppColors.teal,
                  trailing: const StatusPill('Completo', color: AppColors.success, dense: true),
                ),
                const Divider(indent: 14, endIndent: 14),
                NavRow(
                  dense: true,
                  title: 'Vuelo de dron',
                  subtitle: 'Video aéreo del sitio y cubierta',
                  icon: Icons.flight_rounded,
                  iconColor: AppColors.blue,
                  trailing: const StatusPill('Completo', color: AppColors.success, dense: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Videos capturados'),
          ...Mock.videos.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VideoCard(video: v),
              )),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => showAppSnack(context, 'Reproductor no disponible en el prototipo',
          icon: Icons.play_circle_outline_rounded),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: PhotoThumb(
                    seed: video.title.hashCode,
                    radius: 0,
                    icon: Icons.videocam_rounded,
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(video.duration,
                      style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: StatusPill(
                  video.type,
                  color: video.type.contains('dron') ? AppColors.blue : AppColors.teal,
                  dense: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(video.title, style: T.h3)),
                    Icon(
                      video.uploaded ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                      size: 16,
                      color: video.uploaded ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(video.description, style: T.tiny),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _meta(Icons.schedule_rounded, video.time),
                    const SizedBox(width: 14),
                    _meta(Icons.sd_storage_rounded, video.size),
                    const SizedBox(width: 14),
                    _meta(Icons.place_rounded, 'GPS'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) => Row(
        children: [
          Icon(i, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(t, style: T.tiny),
        ],
      );
}
