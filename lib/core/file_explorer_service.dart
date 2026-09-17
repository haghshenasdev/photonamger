import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class FileExplorerService {
  FileExplorerService._();

  // ============================================================
  // Windows Shell32
  // ============================================================

  static final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');

  static final int Function(Pointer<Utf16>, Pointer<Pointer<Void>>)
  _ilCreateFromPath = _shell32
      .lookupFunction<
        Int32 Function(Pointer<Utf16>, Pointer<Pointer<Void>>),
        int Function(Pointer<Utf16>, Pointer<Pointer<Void>>)
      >('SHParseDisplayName');

  static final int Function(Pointer<Void>, int, Pointer<Pointer<Void>>, int)
  _shOpenFolderAndSelectItems = _shell32
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Pointer<Void>>, Uint32),
        int Function(Pointer<Void>, int, Pointer<Pointer<Void>>, int)
      >('SHOpenFolderAndSelectItems');

  static final void Function(Pointer<Void>) _ilFree = _shell32
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('ILFree');

  // ============================================================
  // Reveal File
  // ============================================================

  static Future<bool> revealFile(String filePath) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return false;
      }

      final absolutePath = file.absolute.path;

      return using((arena) {
        final path = absolutePath.toNativeUtf16();

        // خروجی SHParseDisplayName
        final pidlPointer = arena<Pointer<Void>>();

        final parseResult = _ilCreateFromPath(path, pidlPointer);

        if (parseResult != 0) {
          return false;
        }

        final pidl = pidlPointer.value;

        if (pidl == nullptr) {
          return false;
        }

        try {
          /*
           * cidl = 0
           *
           * در این حالت pidl یک PIDL کامل است
           * و Windows Shell خودش پوشه والد را باز
           * کرده و آیتم را انتخاب می‌کند.
           */
          final result = _shOpenFolderAndSelectItems(pidl, 0, nullptr, 0);

          return result == 0;
        } finally {
          _ilFree(pidl);
        }
      });
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // Open Folder
  // ============================================================

  static Future<bool> openFolder(String folderPath) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final directory = Directory(folderPath);

      if (!await directory.exists()) {
        return false;
      }

      await Process.start('explorer.exe', [
        directory.absolute.path,
      ], mode: ProcessStartMode.detached);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  static String folderOf(String filePath) {
    return File(filePath).parent.path;
  }

  static Future<bool> revealOrOpen(String filePath) async {
    final result = await revealFile(filePath);

    if (result) {
      return true;
    }

    return openFolder(folderOf(filePath));
  }
}
