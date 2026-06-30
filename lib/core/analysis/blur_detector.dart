import 'dart:io';

import 'package:image/image.dart' as img;

class BlurDetector {
  /// خروجی بین صفر تا یک
  ///
  /// 0 = کاملاً تار
  /// 1 = کاملاً واضح
  Future<double> score(String path) async {
    try {
      final bytes = await File(path).readAsBytes();

      final image = img.decodeImage(bytes);

      if (image == null) {
        return 0;
      }

      final gray = img.grayscale(image);

      final resized = img.copyResize(gray, width: 256);

      final variance = _laplacianVariance(resized);

      const minValue = 40.0;
      const maxValue = 900.0;

      double score = (variance - minValue) / (maxValue - minValue);

      score = score.clamp(0.0, 1.0);

      return score;
    } catch (_) {
      return 0;
    }
  }

  double _laplacianVariance(img.Image image) {
    final values = <double>[];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final c = image.getPixel(x, y).r.toDouble();

        final t = image.getPixel(x, y - 1).r.toDouble();
        final b = image.getPixel(x, y + 1).r.toDouble();
        final l = image.getPixel(x - 1, y).r.toDouble();
        final r = image.getPixel(x + 1, y).r.toDouble();

        final laplacian = (4 * c) - t - b - l - r;

        values.add(laplacian);
      }
    }

    double mean = 0;

    for (final v in values) {
      mean += v;
    }

    mean /= values.length;

    double variance = 0;

    for (final v in values) {
      variance += (v - mean) * (v - mean);
    }

    variance /= values.length;

    return variance;
  }
}
