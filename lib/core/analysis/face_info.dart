class FaceInfo {
  final double leftEyeOpenProbability;

  final double rightEyeOpenProbability;

  final double smilingProbability;

  final double faceArea;

  final double headEulerY;

  final double headEulerZ;

  const FaceInfo({
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.smilingProbability,
    required this.faceArea,
    required this.headEulerY,
    required this.headEulerZ,
  });

  bool get eyesOpen =>
      leftEyeOpenProbability > 0.6 &&
      rightEyeOpenProbability > 0.6;
}