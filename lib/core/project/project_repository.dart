import 'dart:convert';
import 'dart:io';

import 'photon_project.dart';

class ProjectRepository {
  static const String extension = 'photonamger';

  /// ذخیره امن:
  /// ابتدا فایل .tmp نوشته می‌شود، سپس نسخه قبلی به .bak منتقل می‌شود
  /// و در نهایت tmp به فایل اصلی تبدیل می‌شود.
  static Future<void> save({
    required String path,
    required PhotonProject project,
  }) async {
    final file = File(path);
    final parent = file.parent;

    await parent.create(recursive: true);

    project.updatedAt = DateTime.now();

    final temp = File('$path.tmp');
    final backup = File('$path.bak');

    await temp.writeAsString(
      project.toPrettyJson(),
      flush: true,
    );

    if (await backup.exists()) {
      await backup.delete();
    }

    if (await file.exists()) {
      await file.rename(backup.path);
    }

    try {
      await temp.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }

      if (await backup.exists()) {
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

    // اگر برق هنگام نوشتن قطع شده باشد، tmp ممکن است آخرین نسخه کامل باشد.
    // ابتدا آن را امتحان می‌کنیم؛ اگر ناقص باشد به نسخه اصلی/پشتیبان برمی‌گردیم.
    if (await temp.exists()) candidates.add(temp);
    if (await file.exists()) candidates.add(file);
    if (await backup.exists()) candidates.add(backup);

    Object? lastError;

    for (final candidate in candidates) {
      try {
        final text = await candidate.readAsString();
        final decoded = jsonDecode(text);

        if (decoded is! Map) {
          throw const FormatException('فرمت فایل پروژه معتبر نیست.');
        }

        return PhotonProject.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw FormatException(
      'فایل پروژه قابل خواندن نیست: $path\n$lastError',
    );
  }

  static Future<String?> readLastProjectPath() async {
    final file = await _lastProjectFile();
    if (!await file.exists()) return null;

    final value = (await file.readAsString()).trim();
    if (value.isEmpty) return null;

    return value;
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
