import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class FileExplorerService {
  FileExplorerService._();

  // ============================================================
  // Windows DLL
  // ============================================================

  static final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');

  static final DynamicLibrary _ole32 = DynamicLibrary.open('ole32.dll');

  // ============================================================
  // SHParseDisplayName
  //
  // HRESULT SHParseDisplayName(
  //   PCWSTR pszName,
  //   IBindCtx* pbc,
  //   PIDLIST_ABSOLUTE* ppidl,
  //   SFGAOF sfgaoIn,
  //   SFGAOF* psfgaoOut
  // );
  // ============================================================

  static final int Function(
    Pointer<Utf16>,
    Pointer<Void>,
    Pointer<Pointer<Void>>,
    int,
    Pointer<Uint32>,
  )
  _shParseDisplayName = _shell32
      .lookupFunction<
        Int32 Function(
          Pointer<Utf16>,
          Pointer<Void>,
          Pointer<Pointer<Void>>,
          Uint32,
          Pointer<Uint32>,
        ),
        int Function(
          Pointer<Utf16>,
          Pointer<Void>,
          Pointer<Pointer<Void>>,
          int,
          Pointer<Uint32>,
        )
      >('SHParseDisplayName');

  // ============================================================
  // SHOpenFolderAndSelectItems
  //
  // HRESULT SHOpenFolderAndSelectItems(
  //   PCIDLIST_ABSOLUTE pidlFolder,
  //   UINT cidl,
  //   PCUITEMID_CHILD_ARRAY apidl,
  //   DWORD dwFlags
  // );
  // ============================================================

  static final int Function(Pointer<Void>, int, Pointer<Void>, int)
  _shOpenFolderAndSelectItems = _shell32
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int, Pointer<Void>, int)
      >('SHOpenFolderAndSelectItems');

  // ============================================================
  // CoTaskMemFree
  // ============================================================

  static final void Function(Pointer<Void>) _coTaskMemFree = _ole32
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('CoTaskMemFree');

  // ============================================================
  // نمایش فایل در Windows File Explorer
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
        // مسیر فایل به UTF-16
        final nativePath = absolutePath.toNativeUtf16();

        // محل دریافت PIDL
        final pidlOut = arena<Pointer<Void>>();

        // خروجی attribute ها
        final attributesOut = arena<Uint32>();

        pidlOut.value = nullptr;
        attributesOut.value = 0;

        // تبدیل مسیر فایل به PIDL
        final parseResult = _shParseDisplayName(
          nativePath,
          nullptr,
          pidlOut,
          0,
          attributesOut,
        );

        // S_OK = 0
        if (parseResult != 0) {
          return false;
        }

        final pidl = pidlOut.value;

        if (pidl == nullptr) {
          return false;
        }

        try {
          // باز کردن Explorer و انتخاب فایل
          final result = _shOpenFolderAndSelectItems(pidl, 0, nullptr, 0);

          return result == 0;
        } finally {
          _coTaskMemFree(pidl);
        }
      });
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // باز کردن پوشه
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
  // گرفتن پوشه والد فایل
  // ============================================================

  static String folderOf(String filePath) {
    return File(filePath).parent.path;
  }

  // ============================================================
  // ابتدا فایل را نمایش بده
  // اگر نشد، پوشه را باز کن
  // ============================================================

  static Future<bool> revealOrOpen(String filePath) async {
    final revealed = await revealFile(filePath);

    if (revealed) {
      return true;
    }

    return openFolder(folderOf(filePath));
  }
}
