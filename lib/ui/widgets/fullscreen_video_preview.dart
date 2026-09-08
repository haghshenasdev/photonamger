import 'dart:io';

import 'package:fgphoto/ui/widgets/video_preview.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPreview extends StatefulWidget {
  final String path;

  const FullscreenVideoPreview({
    super.key,
    required this.path,
  });

  @override
  State<FullscreenVideoPreview> createState() =>
      _FullscreenVideoPreviewState();
}

class _FullscreenVideoPreviewState
    extends State<FullscreenVideoPreview> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.file(
      File(widget.path),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await controller.initialize();

      if (!mounted) return;

      setState(() {});

      await controller.play();
    } catch (_) {
      if (!mounted) return;

      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: controller.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                    )
                  : const Center(
                      child: ProgressRing(),
                    ),
            ),
          ),

          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: const Icon(
                FluentIcons.back,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(
                FluentIcons.chrome_close,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}