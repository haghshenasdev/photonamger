import 'dart:io';

import '../ui/models/media_item.dart';

class MediaScanner {
  static const imageExt = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'};

  static const videoExt = {'.mp4', '.avi', '.mov', '.mkv', '.wmv'};

  /// اسکن یک پوشه
  ///
  /// برای حفظ سازگاری با کدهای قبلی.
  Future<List<MediaItem>> scanFolder(String folderPath) async {
    return scanFolders([folderPath]);
  }

  /// اسکن چند پوشه
  ///
  /// تمام فایل‌های موجود در مسیرها را در یک لیست برمی‌گرداند.
  Future<List<MediaItem>> scanFolders(List<String> folderPaths) async {
    final result = <MediaItem>[];

    // جلوگیری از اضافه شدن یک فایل بیش از یک بار
    final scannedPaths = <String>{};

    for (final folderPath in folderPaths) {
      final directory = Directory(folderPath);

      if (!await directory.exists()) {
        continue;
      }

      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final path = entity.path;
        final lowerPath = path.toLowerCase();

        final isImage = imageExt.any(
          (extension) => lowerPath.endsWith(extension),
        );

        final isVideo = videoExt.any(
          (extension) => lowerPath.endsWith(extension),
        );

        if (!isImage && !isVideo) {
          continue;
        }

        //--------------------------------------------------
        // جلوگیری از duplicate path
        //--------------------------------------------------

        final normalizedPath = _normalizePath(path);

        if (!scannedPaths.add(normalizedPath)) {
          continue;
        }

        //--------------------------------------------------
        // اطلاعات فایل
        //--------------------------------------------------

        FileStat stat;

        try {
          stat = await entity.stat();
        } catch (_) {
          // فایل ممکن است در حین اسکن حذف یا جابه‌جا شده باشد.
          continue;
        }

        final fileName = _getFileName(path);

        result.add(
          MediaItem(
            path: path,
            createdAt: stat.modified,
            isVideo: isVideo,
            fileSize: stat.size,
            fileName: fileName,
          ),
        );
      }
    }

    //------------------------------------------------------
    // مرتب‌سازی کلی
    //------------------------------------------------------

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return result;
  }

  String _normalizePath(String path) {
    var value = path.replaceAll('\\', '/').trim();

    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    return value.toLowerCase();
  }

  String _getFileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }
}
