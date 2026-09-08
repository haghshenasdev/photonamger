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

  Future<List<MediaItem>> scanFolder(String folderPath) async {
    return scanFolders([folderPath]);
  }

  Future<List<MediaItem>> scanFolders(List<String> folderPaths) async {
    final result = <MediaItem>[];

    final scannedPaths = <String>{};

    for (final folderPath in folderPaths) {
      final directory = Directory(folderPath);

      if (!await directory.exists()) {
        continue;
      }

      await _scanDirectory(directory, result, scannedPaths);
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return result;
  }

  Future<void> _scanDirectory(
    Directory directory,
    List<MediaItem> result,
    Set<String> scannedPaths,
  ) async {
    GroupMetadata? directoryMetadata;

    // ------------------------------------------------------
    // اگر این پوشه metadata دارد، آن را بخوان.
    // ------------------------------------------------------

    try {
      directoryMetadata = await metadataService.load(directory.path);
    } catch (_) {
      directoryMetadata = null;
    }

    final metadataDirectory = directoryMetadata != null ? directory.path : null;

    // ------------------------------------------------------
    // فایل‌های همین پوشه
    // ------------------------------------------------------

    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          await _processFile(
            entity,
            result,
            scannedPaths,
            metadata: directoryMetadata,
            metadataDirectory: metadataDirectory,
          );
        }
      }
    } catch (_) {
      // خطای دسترسی به یک پوشه نباید کل Scan را متوقف کند.
    }

    // ------------------------------------------------------
    // زیرپوشه‌ها
    // ------------------------------------------------------

    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is Directory) {
          await _scanDirectory(entity, result, scannedPaths);
        }
      }
    } catch (_) {
      // Ignore inaccessible folders.
    }
  }

  Future<void> _processFile(
    File file,
    List<MediaItem> result,
    Set<String> scannedPaths, {
    required GroupMetadata? metadata,
    required String? metadataDirectory,
  }) async {
    final path = file.path;

    final lowerPath = path.toLowerCase();

    final isImage = imageExt.any((extension) => lowerPath.endsWith(extension));

    final isVideo = videoExt.any((extension) => lowerPath.endsWith(extension));

    if (!isImage && !isVideo) {
      return;
    }

    final normalizedPath = _normalizePath(path);

    if (!scannedPaths.add(normalizedPath)) {
      return;
    }

    FileStat stat;

    try {
      stat = await file.stat();
    } catch (_) {
      return;
    }

    result.add(
      MediaItem(
        path: path,
        createdAt: stat.modified,
        isVideo: isVideo,
        fileSize: stat.size,
        fileName: _getFileName(path),

        metadataDirectory: metadataDirectory,
        groupMetadata: metadata,
      ),
    );
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
