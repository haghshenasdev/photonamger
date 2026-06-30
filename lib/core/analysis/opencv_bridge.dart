import 'dart:ffi';

import 'dart:io';

import 'package:ffi/ffi.dart';

typedef InitNative = Int32 Function();

typedef InitDart = int Function();

typedef ReleaseNative = Void Function();

typedef ReleaseDart = void Function();

class OpenCVBridge {
  late final DetectDart detectFaces;

  static final OpenCVBridge instance = OpenCVBridge._();

  late final DynamicLibrary _library;

  late final InitDart initialize;

  late final ReleaseDart release;

  OpenCVBridge._() {
    detectFaces = _library.lookupFunction<DetectNative, DetectDart>(
      "detectFaces",
    );
    if (Platform.isWindows) {
      _library = DynamicLibrary.open("opencv_bridge.dll");
    } else {
      throw UnsupportedError("Platform");
    }

    initialize = _library.lookupFunction<InitNative, InitDart>(
      "initializeOpenCV",
    );

    release = _library.lookupFunction<ReleaseNative, ReleaseDart>(
      "releaseOpenCV",
    );
  }

  int detectImage(String path) {
    final p = path.toNativeUtf8();

    final buffer = calloc<Double>(100);

    final result = detectFaces(p, buffer, 100);

    calloc.free(buffer);

    calloc.free(p);

    return result;
  }
}

typedef DetectNative = Int32 Function(Pointer<Utf8>, Pointer<Double>, Int32);

typedef DetectDart = int Function(Pointer<Utf8>, Pointer<Double>, int);
