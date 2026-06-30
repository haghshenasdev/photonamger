import 'dart:io';

import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';

import '../../ui/models/media_item.dart';
import 'face_info.dart';

class FaceDetectorService {
  cv.FaceDetectorYN? _detector;

  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    final data = await rootBundle.load(
      'assets/models/face_detection_yunet_2023mar.onnx',
    );

    final dir = await getApplicationSupportDirectory();

    final modelFile = File(
      '${dir.path}/face_detection_yunet_2023mar.onnx',
    );

    if (!modelFile.existsSync()) {
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(),
      );
    }

    _detector = cv.FaceDetectorYN.fromFile(
      modelFile.path,
      "",
      (320, 320),
      scoreThreshold: 0.8,
      nmsThreshold: 0.3,
      topK: 5000,
    );

    _initialized = true;
  }

  Future<List<FaceInfo>> detect(
    MediaItem item,
  ) async {
    await _initialize();

    final image = cv.imread(item.path);

    if (image.isEmpty) {
      image.dispose();
      return [];
    }

    _detector!.setInputSize(
      (image.cols, image.rows),
    );

    final result = _detector!.detect(image);

    final faces = <FaceInfo>[];

    for (int i = 0; i < result.rows; i++) {
      final width = result.atNum(i, 2).toDouble();

      final height = result.atNum(i, 3).toDouble();

      final score = result.atNum(i, 14).toDouble();

      if (score < 0.8) {
        continue;
      }

      faces.add(
        FaceInfo(
          faceArea: width * height,

          leftEyeOpenProbability: 1.0,

          rightEyeOpenProbability: 1.0,

          smilingProbability: 0.0,

          headEulerY: 0,

          headEulerZ: 0,
        ),
      );
    }

    result.dispose();
    image.dispose();

    return faces;
  }

  void dispose() {
    _detector?.dispose();
  }
}