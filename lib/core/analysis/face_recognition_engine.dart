import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'face_info.dart';

class FaceRecognitionEngine {
  static const yunetAsset = 'assets/models/face_detection_yunet_2023mar.onnx';

  /// Put the official OpenCV Zoo SFace model at this path.
  static const sfaceAsset = 'assets/models/face_recognition_sface_2021dec.onnx';

  static const int detectorSize = 640;
  static const int embeddingSize = 112;

  final OnnxRuntime _runtime = OnnxRuntime();

  OrtSession? _detector;
  OrtSession? _recognizer;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _detector = await _runtime.createSessionFromAsset(yunetAsset);
    _recognizer = await _runtime.createSessionFromAsset(sfaceAsset);

    _initialized = true;
  }

  Future<void> dispose() async {
    final detector = _detector;
    final recognizer = _recognizer;

    _detector = null;
    _recognizer = null;
    _initialized = false;

    if (detector != null) await detector.close();
    if (recognizer != null) await recognizer.close();
  }

  Future<List<FaceInfo>> analyzeFile(String path) async {
    await initialize();

    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];

    // Do not send multi-megapixel images through the detector. Keeping the
    // longest side at 1600 is a good speed/accuracy compromise.
    final source = _downscale(decoded, 1600);

    final detections = await _detect(source);
    if (detections.isEmpty) return const [];

    final result = <FaceInfo>[];

    for (final detection in detections) {
      final embedding = await _embed(source, detection);
      if (embedding.isEmpty) continue;

      result.add(detection.copyWith(embedding: embedding));
    }

    return result;
  }

  img.Image _downscale(img.Image source, int maxSide) {
    final largest = math.max(source.width, source.height);
    if (largest <= maxSide) return source;

    final scale = maxSide / largest;
    return img.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  Future<List<FaceInfo>> _detect(img.Image source) async {
    final detector = _detector;
    if (detector == null) throw StateError('Face detector is not initialized.');

    // YuNet is much more stable when the source aspect ratio is preserved.
    // The previous implementation stretched every image to 640x640, which
    // changes the geometry of faces before the five landmarks are produced.
    final prepared = _prepareDetectorImage(source, detectorSize);

    final tensor = await OrtValue.fromList(prepared.input, [
      1,
      3,
      detectorSize,
      detectorSize,
    ]);

    Map<String, OrtValue> outputs = {};
    try {
      outputs = await detector.run({detector.inputNames.first: tensor});

      final cls8 = await _flat(outputs['cls_8']);
      final cls16 = await _flat(outputs['cls_16']);
      final cls32 = await _flat(outputs['cls_32']);
      final obj8 = await _flat(outputs['obj_8']);
      final obj16 = await _flat(outputs['obj_16']);
      final obj32 = await _flat(outputs['obj_32']);
      final bbox8 = await _flat(outputs['bbox_8']);
      final bbox16 = await _flat(outputs['bbox_16']);
      final bbox32 = await _flat(outputs['bbox_32']);
      final kps8 = await _flat(outputs['kps_8']);
      final kps16 = await _flat(outputs['kps_16']);
      final kps32 = await _flat(outputs['kps_32']);

      final candidates = <_Detection>[];

      _decodeScale(
        stride: 8,
        cls: cls8,
        obj: obj8,
        bbox: bbox8,
        kps: kps8,
        candidates: candidates,
      );
      _decodeScale(
        stride: 16,
        cls: cls16,
        obj: obj16,
        bbox: bbox16,
        kps: kps16,
        candidates: candidates,
      );
      _decodeScale(
        stride: 32,
        cls: cls32,
        obj: obj32,
        bbox: bbox32,
        kps: kps32,
        candidates: candidates,
      );

      candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

      final kept = <_Detection>[];
      for (final candidate in candidates) {
        var suppressed = false;
        for (final existing in kept) {
          if (_iou(candidate, existing) > 0.3) {
            suppressed = true;
            break;
          }
        }
        if (!suppressed) {
          kept.add(candidate);
          if (kept.length >= 80) break;
        }
      }

      final scale = prepared.scale;
      final padX = prepared.padX;
      final padY = prepared.padY;

      return kept.map((d) {
        double sourceX(double x) => (x - padX) / scale;
        double sourceY(double y) => (y - padY) / scale;

        final left = sourceX(d.left);
        final top = sourceY(d.top);
        final width = d.width / scale;
        final height = d.height / scale;

        final landmarks = <double>[];
        for (var i = 0; i < d.landmarks.length; i += 2) {
          landmarks.add(sourceX(d.landmarks[i]));
          landmarks.add(sourceY(d.landmarks[i + 1]));
        }

        return FaceInfo(
          left: left.clamp(0, source.width.toDouble()),
          top: top.clamp(0, source.height.toDouble()),
          width: width.clamp(0, source.width.toDouble()),
          height: height.clamp(0, source.height.toDouble()),
          landmarks: landmarks,
          confidence: d.confidence,
          faceArea: width * height,
        );
      }).toList();
    } finally {
      tensor.dispose();
    }
  }

  void _decodeScale({
    required int stride,
    required List<double> cls,
    required List<double> obj,
    required List<double> bbox,
    required List<double> kps,
    required List<_Detection> candidates,
  }) {
    final cols = detectorSize ~/ stride;
    final rows = detectorSize ~/ stride;
    final count = math.min(
      rows * cols,
      math.min(
        cls.length,
        math.min(obj.length, math.min(bbox.length ~/ 4, kps.length ~/ 10)),
      ),
    );

    for (var index = 0; index < count; index++) {
      final c = cls[index].clamp(0, 1).toDouble();
      final o = obj[index].clamp(0, 1).toDouble();
      final score = math.sqrt(c * o);

      // 0.65 is intentionally conservative: the face database is used for
      // identity clustering, so false detections are more expensive than
      // missing a very weak face.
      if (score < 0.45) continue;

      final row = index ~/ cols;
      final col = index % cols;

      final base = index * 4;
      final cx = (col + bbox[base]) * stride;
      final cy = (row + bbox[base + 1]) * stride;
      final width = math.exp(bbox[base + 2]) * stride;
      final height = math.exp(bbox[base + 3]) * stride;

      final landmarks = List<double>.filled(10, 0);
      final kbase = index * 10;
      for (var k = 0; k < 10; k += 2) {
        landmarks[k] = (col + kps[kbase + k]) * stride;
        landmarks[k + 1] = (row + kps[kbase + k + 1]) * stride;
      }

      final left = (cx - width / 2).clamp(0, detectorSize - 1).toDouble();
      final top = (cy - height / 2).clamp(0, detectorSize - 1).toDouble();
      final right = (cx + width / 2)
          .clamp(0, detectorSize.toDouble())
          .toDouble();
      final bottom = (cy + height / 2)
          .clamp(0, detectorSize.toDouble())
          .toDouble();

      if (right - left < 24 || bottom - top < 24) continue;

      candidates.add(
        _Detection(
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
          confidence: score,
          landmarks: landmarks,
        ),
      );
    }
  }

  double _iou(_Detection a, _Detection b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.left + a.width, b.left + b.width);
    final bottom = math.min(a.top + a.height, b.top + b.height);

    final w = math.max(0, right - left);
    final h = math.max(0, bottom - top);
    final intersection = w * h;
    if (intersection <= 0) return 0;

    final union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  Future<List<double>> _embed(img.Image source, FaceInfo face) async {
    final recognizer = _recognizer;

    if (recognizer == null) {
      throw StateError('Face recognizer is not initialized.');
    }

    final aligned = _align(source, face.landmarks);

    // SFace expects a 112x112 aligned face.
    //
    // The OpenCV SFace implementation uses the aligned face in BGR
    // channel order. image package stores/returns RGB pixels, therefore
    // the channel order must be converted here.
    // OpenCV's FaceRecognizerSF::feature() calls blobFromImage(...,
    // swapRB=true). OpenCV images are BGR, therefore the resulting network
    // tensor is RGB. The Dart image package is already RGB, so we must send
    // R, G, B planes here — NOT B, G, R.
    final input = List<double>.filled(3 * embeddingSize * embeddingSize, 0);

    var offsetR = 0;
    var offsetG = embeddingSize * embeddingSize;
    var offsetB = embeddingSize * embeddingSize * 2;

    for (var y = 0; y < embeddingSize; y++) {
      for (var x = 0; x < embeddingSize; x++) {
        final pixel = aligned.getPixel(x, y);

        input[offsetR++] = pixel.r.toDouble();
        input[offsetG++] = pixel.g.toDouble();
        input[offsetB++] = pixel.b.toDouble();
      }
    }

    final tensor = await OrtValue.fromList(input, [
      1,
      3,
      embeddingSize,
      embeddingSize,
    ]);

    Map<String, OrtValue> outputs = {};

    try {
      outputs = await recognizer.run({recognizer.inputNames.first: tensor});

      final outputName = recognizer.outputNames.first;
      final output = outputs[outputName];

      if (output == null) {
        throw StateError('SFace output "$outputName" was not returned.');
      }

      final raw = await _flat(output);

      if (raw.length < 8) {
        throw StateError(
          'SFace returned an invalid embedding '
          '(length=${raw.length}).',
        );
      }

      final normalized = _l2Normalize(raw);

      if (normalized.length < 8) {
        throw StateError('SFace embedding normalization failed.');
      }

      return normalized;
    } finally {
      tensor.dispose();

      for (final value in outputs.values) {
        value.dispose();
      }
    }
  }

  /// Similarity transform using the five YuNet landmarks.
  /// This is a small pure-Dart replacement for alignCrop; no OpenCV is used.
  img.Image _align(img.Image source, List<double> points) {
    if (points.length < 10) {
      final side = math.min(source.width, source.height);
      final left = (source.width - side) ~/ 2;
      final top = (source.height - side) ~/ 2;

      final crop = img.copyCrop(
        source,
        x: left,
        y: top,
        width: side,
        height: side,
      );

      return img.copyResize(
        crop,
        width: embeddingSize,
        height: embeddingSize,
        interpolation: img.Interpolation.linear,
      );
    }

    // IMPORTANT:
    // Keep YuNet landmark order exactly as returned by the detector.
    //
    // OpenCV FaceRecognizerSF.alignCrop() uses the five landmarks
    // directly from positions 4..13 of YuNet's face result.
    final src = <List<double>>[
      [points[0], points[1]],
      [points[2], points[3]],
      [points[4], points[5]],
      [points[6], points[7]],
      [points[8], points[9]],
    ];

    const dst = <List<double>>[
      [38.2946, 51.6963],
      [73.5318, 51.5014],
      [56.0252, 71.7366],
      [41.5493, 92.3655],
      [70.7299, 92.2041],
    ];

    final transform = _similarityTransform(src, dst);

    final out = img.Image(width: embeddingSize, height: embeddingSize);

    final a = transform[0];
    final b = transform[1];
    final tx = transform[2];
    final ty = transform[3];

    final denom = a * a + b * b;

    if (denom < 1e-10) {
      return img.copyResize(
        source,
        width: embeddingSize,
        height: embeddingSize,
        interpolation: img.Interpolation.linear,
      );
    }

    for (var y = 0; y < embeddingSize; y++) {
      for (var x = 0; x < embeddingSize; x++) {
        final dx = x - tx;
        final dy = y - ty;

        final sx = (a * dx + b * dy) / denom;
        final sy = (-b * dx + a * dy) / denom;

        if (sx < 0 ||
            sy < 0 ||
            sx >= source.width - 1 ||
            sy >= source.height - 1) {
          out.setPixelRgb(x, y, 0, 0, 0);
          continue;
        }

        final x0 = sx.floor();
        final y0 = sy.floor();

        final fx = sx - x0;
        final fy = sy - y0;

        final p00 = source.getPixel(x0, y0);
        final p10 = source.getPixel(x0 + 1, y0);
        final p01 = source.getPixel(x0, y0 + 1);
        final p11 = source.getPixel(x0 + 1, y0 + 1);

        final r = _bilinear(
          p00.r.toDouble(),
          p10.r.toDouble(),
          p01.r.toDouble(),
          p11.r.toDouble(),
          fx,
          fy,
        );

        final g = _bilinear(
          p00.g.toDouble(),
          p10.g.toDouble(),
          p01.g.toDouble(),
          p11.g.toDouble(),
          fx,
          fy,
        );

        final bl = _bilinear(
          p00.b.toDouble(),
          p10.b.toDouble(),
          p01.b.toDouble(),
          p11.b.toDouble(),
          fx,
          fy,
        );

        out.setPixelRgb(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          bl.round().clamp(0, 255),
        );
      }
    }

    return out;
  }

  List<double> _similarityTransform(
    List<List<double>> src,
    List<List<double>> dst,
  ) {
    var srcX = 0.0;
    var srcY = 0.0;
    var dstX = 0.0;
    var dstY = 0.0;

    for (var i = 0; i < 5; i++) {
      srcX += src[i][0];
      srcY += src[i][1];
      dstX += dst[i][0];
      dstY += dst[i][1];
    }

    srcX /= 5;
    srcY /= 5;
    dstX /= 5;
    dstY /= 5;

    var numeratorA = 0.0;
    var numeratorB = 0.0;
    var denominator = 0.0;

    for (var i = 0; i < 5; i++) {
      final x = src[i][0] - srcX;
      final y = src[i][1] - srcY;
      final X = dst[i][0] - dstX;
      final Y = dst[i][1] - dstY;

      numeratorA += x * X + y * Y;
      numeratorB += x * Y - y * X;
      denominator += x * x + y * y;
    }

    if (denominator < 1e-10) {
      return const [1, 0, 0, 1];
    }

    final a = numeratorA / denominator;
    final b = numeratorB / denominator;
    final tx = dstX - a * srcX + b * srcY;
    final ty = dstY - b * srcX - a * srcY;

    return [a, b, tx, ty];
  }

  double _bilinear(
    double p00,
    double p10,
    double p01,
    double p11,
    double fx,
    double fy,
  ) {
    final top = p00 + (p10 - p00) * fx;
    final bottom = p01 + (p11 - p01) * fx;
    return top + (bottom - top) * fy;
  }

  _DetectorInput _prepareDetectorImage(img.Image source, int size) {
    final scale = math.min(size / source.width, size / source.height);

    final resizedWidth = math.max(1, (source.width * scale).round());
    final resizedHeight = math.max(1, (source.height * scale).round());

    final resized = img.copyResize(
      source,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(width: size, height: size);

    // YuNet receives a BGR tensor, matching OpenCV's FaceDetectorYN path.
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        canvas.setPixelRgb(x, y, 0, 0, 0);
      }
    }

    final padX = ((size - resizedWidth) / 2).floor();
    final padY = ((size - resizedHeight) / 2).floor();

    for (var y = 0; y < resizedHeight; y++) {
      for (var x = 0; x < resizedWidth; x++) {
        final pixel = resized.getPixel(x, y);
        canvas.setPixelRgb(x + padX, y + padY, pixel.r, pixel.g, pixel.b);
      }
    }

    final plane = size * size;
    final output = List<double>.filled(plane * 3, 0);

    var offsetB = 0;
    var offsetG = plane;
    var offsetR = plane * 2;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final pixel = canvas.getPixel(x, y);

        output[offsetB++] = pixel.b.toDouble();
        output[offsetG++] = pixel.g.toDouble();
        output[offsetR++] = pixel.r.toDouble();
      }
    }

    return _DetectorInput(
      input: output,
      scale: scale,
      padX: padX.toDouble(),
      padY: padY.toDouble(),
    );
  }

  Future<List<double>> _flat(OrtValue? value) async {
    if (value == null) return const [];
    final raw = await value.asList();
    final result = <double>[];

    void walk(dynamic node) {
      if (node is num) {
        result.add(node.toDouble());
      } else if (node is Iterable) {
        for (final child in node) {
          walk(child);
        }
      }
    }

    walk(raw);
    return result;
  }

  List<double> _l2Normalize(List<double> values) {
    var sum = 0.0;
    for (final value in values) {
      sum += value * value;
    }

    final norm = math.sqrt(sum);
    if (norm < 1e-9) return values;

    return values.map((e) => e / norm).toList();
  }
}

class _DetectorInput {
  final List<double> input;
  final double scale;
  final double padX;
  final double padY;

  const _DetectorInput({
    required this.input,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}

class _Detection {
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
  final List<double> landmarks;

  const _Detection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    required this.landmarks,
  });
}
