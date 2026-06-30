import '../../ui/models/media_item.dart';
import 'photo_score.dart';

class QualityScorer {

  PhotoScore score(MediaItem item) {

    double blur = item.blurScore;

    double faceScore = 0;

    double eyeScore = 0;

    double sizeScore = 0;

    double smileScore = 0;

    if (item.faces.isNotEmpty) {

      final faces = [...item.faces];

      faces.sort(
        (a, b) => b.faceArea.compareTo(a.faceArea),
      );

      final topFaces = faces.take(3).toList();

      faceScore = topFaces.length / 3.0;

      double eyeSum = 0;

      double sizeSum = 0;

      double smileSum = 0;

      for (final face in topFaces) {

        eyeSum +=
            (face.leftEyeOpenProbability +
                    face.rightEyeOpenProbability) /
                2;

        sizeSum += face.faceArea;

        smileSum += face.smilingProbability;
      }

      eyeScore = eyeSum / topFaces.length;

      smileScore = smileSum / topFaces.length;

      sizeScore = (sizeSum / topFaces.length) / 50000.0;

      if (sizeScore > 1) {
        sizeScore = 1;
      }
    }

    final total =
        blur * 0.45 +
        eyeScore * 0.25 +
        sizeScore * 0.15 +
        faceScore * 0.10 +
        smileScore * 0.05;

    return PhotoScore(
      total: total,
      blur: blur,
      face: faceScore,
      eyes: eyeScore,
      size: sizeScore,
      smile: smileScore,
    );
  }
}