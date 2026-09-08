import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

class VideoThumbnail extends StatefulWidget {
  final String path;

  const VideoThumbnail({super.key, required this.path});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  static final Map<String, Uint8List?> _cache = {};

  static final Map<String, Future<Uint8List?>> _loading = {};

  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();

    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_cache.containsKey(widget.path)) {
      if (!mounted) return;

      setState(() {
        _thumbnail = _cache[widget.path];
      });

      return;
    }

    final existing = _loading[widget.path];

    if (existing != null) {
      final result = await existing;

      if (!mounted) return;

      setState(() {
        _thumbnail = result;
      });

      return;
    }

    final future = _generateThumbnail();

    _loading[widget.path] = future;

    final result = await future;

    _loading.remove(widget.path);

    _cache[widget.path] = result;

    if (!mounted) return;

    setState(() {
      _thumbnail = result;
    });
  }

  Future<Uint8List?> _generateThumbnail() async {
    try {
      return await FlutterVideoThumbnailPlus.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.jpeg,
        maxWidth: 600,
        maxHeight: 600,
        timeMs: 0,
        quality: 80,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_thumbnail != null)
          Image.memory(_thumbnail!, fit: BoxFit.cover, gaplessPlayback: true)
        else
          Container(
            color: Colors.grey[80],
            child: const Center(child: ProgressRing()),
          ),

        // لایه تیره بسیار ظریف
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),

        // علامت Play
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: const Icon(FluentIcons.play, color: Colors.white, size: 24),
          ),
        ),

        // Badge ویدئو
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.video, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text(
                  'ویدئو',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void clearCache() {
    _cache.clear();
    _loading.clear();
  }

  static void remove(String path) {
    _cache.remove(path);
    _loading.remove(path);
  }
}
