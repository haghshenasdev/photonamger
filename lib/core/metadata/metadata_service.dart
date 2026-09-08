import 'dart:convert';
import 'dart:io';

import '../../ui/models/group_metadata.dart';

class MetadataService {
  static const String metadataFileName = '.photonamger.json';

  const MetadataService();

  File fileForDirectory(String directoryPath) {
    return File(
      Directory(directoryPath).uri.resolve(metadataFileName).toFilePath(),
    );
  }

  Future<bool> exists(String directoryPath) async {
    return fileForDirectory(directoryPath).exists();
  }

  /// خواندن metadata یک پوشه.
  ///
  /// اگر فایل وجود نداشته باشد یا خراب باشد null برمی‌گرداند.
  Future<GroupMetadata?> load(String directoryPath) async {
    final file = fileForDirectory(directoryPath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(content);

      if (decoded is! Map) {
        return null;
      }

      return GroupMetadata.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // خراب بودن metadata نباید باعث شکست Analyze شود.
      return null;
    }
  }

  /// ذخیره metadata در پوشه.
  Future<void> save({
    required String directoryPath,
    required GroupMetadata metadata,
  }) async {
    final directory = Directory(directoryPath);

    await directory.create(recursive: true);

    final file = fileForDirectory(directoryPath);

    await file.writeAsString(metadata.toPrettyJson(), flush: true);
  }

  /// حذف metadata.
  Future<void> delete(String directoryPath) async {
    final file = fileForDirectory(directoryPath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// تمام پوشه‌های دارای metadata را پیدا می‌کند.
  ///
  /// خروجی:
  ///
  /// {
  ///   "D:/Photos/سفر شمال": GroupMetadata(...),
  ///   "D:/Photos/مراسم": GroupMetadata(...)
  /// }
  Future<Map<String, GroupMetadata>> scan(String rootPath) async {
    final result = <String, GroupMetadata>{};

    final root = Directory(rootPath);

    if (!await root.exists()) {
      return result;
    }

    await _scanDirectory(root, result);

    return result;
  }

  Future<void> _scanDirectory(
    Directory directory,
    Map<String, GroupMetadata> result,
  ) async {
    final metadata = await load(directory.path);

    if (metadata != null) {
      result[_normalizePath(directory.path)] = metadata;
    }

    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is Directory) {
          await _scanDirectory(entity, result);
        }
      }
    } catch (_) {
      // اگر دسترسی به یک زیرپوشه مشکل داشت،
      // کل Scan متوقف نشود.
    }
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
}
