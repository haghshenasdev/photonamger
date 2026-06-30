import 'dart:io';

import '../ui/models/media_item.dart';

class MediaScanner {
  static const imageExt = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'};

  static const videoExt = {'.mp4', '.avi', '.mov', '.mkv', '.wmv'};

  Future<List<MediaItem>> scanFolder(String folderPath) async {
    final result = <MediaItem>[];

    final directory = Directory(folderPath);

    if (!directory.existsSync()) {
      return result;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      final path = entity.path.toLowerCase();

      bool isImage = imageExt.any((e) => path.endsWith(e));

      bool isVideo = videoExt.any((e) => path.endsWith(e));

      if (!isImage && !isVideo) {
        continue;
      }

      final stat = await entity.stat();

      final fileName = entity.uri.pathSegments.last;

      result.add(
        MediaItem(
          path: entity.path,
          createdAt: stat.modified,
          isVideo: isVideo,
          fileSize: stat.size,
          fileName: fileName,
        ),
      );
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return result;
  }
}
