import 'dart:convert';
import 'dart:io';

import 'photon_project.dart';

class ProjectRepository {
  static const String extension = 'photonamger';

  /// Save atomically while preserving a recoverable copy of the previous file.
  static Future<void> save({
    required String path,
    required PhotonProject project,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);

    project.updatedAt = DateTime.now();
    final temp = File('$path.tmp');
    final backup = File('$path.bak');

    // Write and validate the complete new project before touching the current one.
    final json = project.toPrettyJson();
    jsonDecode(json);
    await temp.writeAsString(json, flush: true);
    final written = await temp.readAsString();
    final decoded = jsonDecode(written);
    if (decoded is! Map || decoded['format'] != 'photonamger') {
      throw const FormatException('فایل موقت پروژه معتبر نیست.');
    }

    var movedCurrentToBackup = false;
    try {
      if (await file.exists()) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
        movedCurrentToBackup = true;
      }

      await temp.rename(file.path);

      // Only remove the backup after the new project is safely in place.
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      // Keep the temp file for recovery and restore the previous project if possible.
      if (movedCurrentToBackup && await backup.exists()) {
        if (await file.exists()) await file.delete();
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  static Future<PhotonProject> load(String path) async {
    final file = File(path);
    final temp = File('$path.tmp');
    final backup = File('$path.bak');
    final candidates = <File>[];
    for (final candidate in [file, temp, backup]) {
      if (await candidate.exists()) candidates.add(candidate);
    }

    // Prefer the newest valid copy, rather than always preferring a stale .tmp.
    final dated = <({File file, DateTime modified})>[];
    for (final candidate in candidates) {
      try {
        dated.add((file: candidate, modified: await candidate.lastModified()));
      } catch (_) {
        // Ignore a file that disappears while recovery is being attempted.
      }
    }
    dated.sort((a, b) => b.modified.compareTo(a.modified));

    Object? lastError;
    for (final entry in dated) {
      try {
        final decoded = jsonDecode(await entry.file.readAsString());
        if (decoded is! Map) {
          throw const FormatException('فرمت فایل پروژه معتبر نیست.');
        }
        final json = Map<String, dynamic>.from(decoded);
        if (json['format'] != null && json['format'] != 'photonamger') {
          throw const FormatException('این فایل متعلق به قالب پروژه آرشینو نیست.');
        }
        return PhotonProject.fromJson(json);
      } catch (e) {
        lastError = e;
      }
    }

    throw FormatException(
      'هیچ نسخه سالمی از فایل پروژه قابل خواندن نیست: $path\n$lastError',
    );
  }

  static Future<String?> readLastProjectPath() async {
    final file = await _lastProjectFile();
    if (!await file.exists()) return null;
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  static Future<void> rememberProjectPath(String path) async {
    final file = await _lastProjectFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(path, flush: true);
  }

  static Future<File> _lastProjectFile() async {
    String base;
    if (Platform.isWindows) {
      base = Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
    } else if (Platform.isMacOS) {
      base = Platform.environment['HOME'] ?? Directory.current.path;
    } else {
      base = Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME'] ?? Directory.current.path}/.config';
    }
    return File(
      '$base${Platform.pathSeparator}Archino${Platform.pathSeparator}last_project.txt',
    );
  }
}
