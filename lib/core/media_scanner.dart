import 'dart:io';

import '../ui/models/group_metadata.dart';
import '../ui/models/media_item.dart';
import 'metadata/metadata_service.dart';

class MediaScanner {
  static const imageExt = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp'};

  static const videoExt = {'.mp4', '.avi', '.mov', '.mkv', '.wmv'};

  final MetadataService metadataService;

  MediaScanner({MetadataService? metadataService})
    : metadataService = metadataService ?? const MetadataService();

  /// اسکن یک پوشه.
  ///
  /// برای حفظ سازگاری با کد فعلی پروژه.
  Future<List<MediaItem>> scanFolder(String folderPath) async {
    return scanFolders([folderPath]);
  }

  /// اسکن چند پوشه.
  Future<List<MediaItem>> scanFolders(List<String> folderPaths) async {
    final result = <MediaItem>[];

    // جلوگیری از اضافه شدن یک فایل بیشتر از یک بار.
    final scannedPaths = <String>{};

    for (final folderPath in folderPaths) {
      final directory = Directory(folderPath);

      if (!await directory.exists()) {
        continue;
      }

      // --------------------------------------------------
      // ابتدا تمام metadata ها را یک بار می‌خوانیم.
      // --------------------------------------------------

      final metadataMap = await metadataService.scan(folderPath);

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

        // ------------------------------------------------
        // جلوگیری از duplicate path
        // ------------------------------------------------

        final normalizedPath = _normalizePath(path);

        if (!scannedPaths.add(normalizedPath)) {
          continue;
        }

        // ------------------------------------------------
        // اطلاعات فایل
        // ------------------------------------------------

        FileStat stat;

        try {
          stat = await entity.stat();
        } catch (_) {
          // فایل ممکن است در حین اسکن حذف یا جابه‌جا شده باشد.
          continue;
        }

        final fileName = _getFileName(path);

        // ------------------------------------------------
        // پیدا کردن metadata نزدیک‌ترین پوشه
        // ------------------------------------------------

        final metadataMatch = _findMetadataForFile(path, metadataMap);

        result.add(
          MediaItem(
            path: path,
            createdAt: stat.modified,
            isVideo: isVideo,
            fileSize: stat.size,
            fileName: fileName,
            groupMetadata: metadataMatch?.metadata,
            metadataDirectory: metadataMatch?.directory,
          ),
        );
      }
    }

    // ----------------------------------------------------
    // مرتب‌سازی کلی
    // ----------------------------------------------------

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return result;
  }

  _MetadataMatch? _findMetadataForFile(
    String filePath,
    Map<String, GroupMetadata> metadataMap,
  ) {
    final normalizedFile = _normalizePath(filePath);

    String? bestDirectory;
    GroupMetadata? bestMetadata;

    for (final entry in metadataMap.entries) {
      final directory = entry.key;

      if (!_isInsideDirectory(normalizedFile, directory)) {
        continue;
      }

      // اگر چند metadata روی مسیر باشند،
      // نزدیک‌ترین پوشه را انتخاب می‌کنیم.
      if (bestDirectory == null || directory.length > bestDirectory.length) {
        bestDirectory = directory;
        bestMetadata = entry.value;
      }
    }

    if (bestDirectory == null || bestMetadata == null) {
      return null;
    }

    return _MetadataMatch(metadata: bestMetadata, directory: bestDirectory);
  }

  bool _isInsideDirectory(String filePath, String directoryPath) {
    if (filePath == directoryPath) {
      return true;
    }

    return filePath.startsWith('$directoryPath/');
  }

  String _normalizePath(String path) {
    var value = path.replaceAll('\\', '/').trim();

    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    if (Platform.isWindows) {
      value = value.toLowerCase();
    }

    return value;
  }

  String _getFileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }
}

class _MetadataMatch {
  final GroupMetadata metadata;
  final String directory;

  const _MetadataMatch({required this.metadata, required this.directory});
}
