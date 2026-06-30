import 'dart:io';

import 'package:opencv_dart/opencv.dart' as cv;

class OpenCVService {
  OpenCVService._();

  static final instance = OpenCVService._();

  Future<cv.Mat?> loadImage(String path) async {
    if (!File(path).existsSync()) {
      return null;
    }

    final mat = cv.imread(path);

    if (mat.isEmpty) {
      return null;
    }

    return mat;
  }

  cv.Mat toGray(cv.Mat src) {
    return cv.cvtColor(
      src,
      cv.COLOR_BGR2GRAY,
    );
  }

  cv.VecI32 imageSize(cv.Mat mat) {
    return mat.size;
  }

  void dispose(cv.Mat mat) {
    mat.dispose();
  }
}