import 'dart:math' as math;

class FaceInfo {
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double smilingProbability;
  final double faceArea;
  final double headEulerY;
  final double headEulerZ;

  /// Bounding box in the source image.
  final double left;
  final double top;
  final double width;
  final double height;

  /// Five YuNet landmarks:
  /// right eye, left eye, nose, right mouth, left mouth.
  final List<double> landmarks;

  /// Detector confidence.
  final double confidence;

  /// SFace embedding.
  ///
  /// It is kept outside the project JSON and persisted
  /// by FaceDatabaseService.
  final List<double> embedding;

  /// Stable person id assigned by the local face database.
  ///
  /// This field intentionally remains mutable because the face
  /// can be assigned to a person after detection.
  String? personId;

  FaceInfo({
    this.leftEyeOpenProbability = 0,
    this.rightEyeOpenProbability = 0,
    this.smilingProbability = 0,
    this.faceArea = 0,
    this.headEulerY = 0,
    this.headEulerZ = 0,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.landmarks = const <double>[],
    this.confidence = 0,
    this.embedding = const <double>[],
    this.personId,
  });

  bool get eyesOpen =>
      leftEyeOpenProbability > 0.6 && rightEyeOpenProbability > 0.6;

  double get centerX => left + width / 2;

  double get centerY => top + height / 2;

  double get quality {
    final size = math.sqrt((width * height).clamp(0, double.infinity));

    final sizeScore = (size / 180).clamp(0, 1);

    return (confidence * 0.65 + sizeScore * 0.35).clamp(0, 1);
  }

  FaceInfo copyWith({
    double? leftEyeOpenProbability,
    double? rightEyeOpenProbability,
    double? smilingProbability,
    double? faceArea,
    double? headEulerY,
    double? headEulerZ,
    double? left,
    double? top,
    double? width,
    double? height,
    List<double>? landmarks,
    double? confidence,
    List<double>? embedding,
    String? personId,
  }) {
    return FaceInfo(
      leftEyeOpenProbability:
          leftEyeOpenProbability ?? this.leftEyeOpenProbability,

      rightEyeOpenProbability:
          rightEyeOpenProbability ?? this.rightEyeOpenProbability,

      smilingProbability: smilingProbability ?? this.smilingProbability,

      faceArea: faceArea ?? this.faceArea,

      headEulerY: headEulerY ?? this.headEulerY,

      headEulerZ: headEulerZ ?? this.headEulerZ,

      left: left ?? this.left,

      top: top ?? this.top,

      width: width ?? this.width,

      height: height ?? this.height,

      landmarks: landmarks ?? this.landmarks,

      confidence: confidence ?? this.confidence,

      embedding: embedding ?? this.embedding,

      personId: personId ?? this.personId,
    );
  }
}
