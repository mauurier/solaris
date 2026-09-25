import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Reproductor sencillo para revisar un video antes de cerrar la visita.
class VideoView extends StatefulWidget {
  const VideoView({super.key, required this.file, this.autoplay = false});
  final File file;
  final bool autoplay;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final VideoPlayerController _c = VideoPlayerController.file(widget.file);
  String? _error;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      if (widget.autoplay) _c.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _error = 'No se pudo reproducir el video');
    });
    _c.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_tick);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: T.small);
    }
    if (!_c.value.isInitialized) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    final v = _c.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => v.isPlaying ? _c.pause() : _c.play(),
          child: AspectRatio(
            aspectRatio: v.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_c),
                if (!v.isPlaying)
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(fmtDurationClock(v.position), style: T.tiny.copyWith(color: Colors.white70)),
              Expanded(
                child: VideoProgressIndicator(
                  _c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  colors: const VideoProgressColors(playedColor: AppColors.accent),
                ),
              ),
              Text(fmtDurationClock(v.duration), style: T.tiny.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}
