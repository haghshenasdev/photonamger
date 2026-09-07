import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final String path;

  const VideoPreview({super.key, required this.path});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.file(File(widget.path));

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: ProgressRing());
    }

    if (_controller.value.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.error, size: 48),
            const SizedBox(height: 12),
            Text(_controller.value.errorDescription ?? 'خطا در پخش ویدئو'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),

        _controls(),
      ],
    );
  }

  Widget _controls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return Column(
      children: [
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),

        Row(
          children: [
            IconButton(
              icon: Icon(
                _controller.value.isPlaying
                    ? FluentIcons.pause
                    : FluentIcons.play,
              ),
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
            ),

            Text(
              '${_formatDuration(position)} / '
              '${_formatDuration(duration)}',
            ),

            const Spacer(),

            IconButton(
              icon: const Icon(FluentIcons.stop),
              onPressed: () {
                _controller.pause();
                _controller.seekTo(Duration.zero);

                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
