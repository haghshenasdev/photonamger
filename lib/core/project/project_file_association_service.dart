import 'dart:io';

/// Registers .photonamger files for opening with the current Windows app.
/// Uses HKCU, so no administrator permission is required.
class ProjectFileAssociationService {
  static const String extension = '.photonamger';
  static const String _progId = 'Archino.Project';

  static Future<void> registerForCurrentUser() async {
    if (!Platform.isWindows) return;

    final executable = Platform.resolvedExecutable;
    if (executable.isEmpty || !await File(executable).exists()) return;

    await _regAdd('Software\\Classes\\$extension', '/ve', _progId);
    await _regAdd(
      'Software\\Classes\\$_progId',
      '/ve',
      'پروژه آرشینو',
    );
    await _regAdd(
      'Software\\Classes\\$_progId\\DefaultIcon',
      '/ve',
      '"$executable",0',
    );
    await _regAdd(
      'Software\\Classes\\$_progId\\shell\\open\\command',
      '/ve',
      '"$executable" "%1"',
    );
  }

  static Future<void> _regAdd(String key, String valueFlag, String value) async {
    final result = await Process.run('reg.exe', [
      'add',
      'HKCU\\$key',
      valueFlag,
      '/d',
      value,
      '/f',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw ProcessException(
        'reg.exe',
        ['add', 'HKCU\\$key'],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }

  static String? projectPathFromArguments(List<String> arguments) {
    for (final argument in arguments) {
      final value = argument.trim().replaceAll('"', '');
      if (value.toLowerCase().endsWith(extension)) return value;
    }
    return null;
  }
}
