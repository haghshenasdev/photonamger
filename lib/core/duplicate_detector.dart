import 'dart:io';
import 'dart:math' as math;

import 'package:fgphoto/core/analysis/analysis_controller.dart';
import 'package:image/image.dart' as img;

import '../ui/models/duplicate_group.dart';
import '../ui/models/media_item.dart';

class DuplicateDetector {
  static const int similarityThreshold = 8;

  Future<List<DuplicateGroup>> findDuplicates(
    List<MediaItem> items, {
    required AnalysisController controller,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    // ---------- مرحله اول : محاسبه Hash ----------

    await _calculateHashes(items, controller, onProgress);

    if (controller.isCancelled) {
      return [];
    }

    // ---------- مرحله دوم : ساخت گروه ها ----------

    final groups = await _buildGroups(items, controller, onProgress);

    // ---------- مرتب سازی ----------

    groups.sort((a, b) => b.items.length.compareTo(a.items.length));

    onProgress?.call(
      items.length,
      items.length,
      'تشخیص تصاویر تکراری پایان یافت',
    );

    return groups;
  }

  //---------------------------------------------------------------------------
  // محاسبه Hash فقط یک بار برای هر تصویر
  //---------------------------------------------------------------------------

  Future<void> _calculateHashes(
    List<MediaItem> items,
    AnalysisController controller,
    void Function(int, int, String)? onProgress,
  ) async {
    int current = 0;

    for (final item in items) {
      if (!await controller.checkpoint()) {
        return;
      }

      current++;

      onProgress?.call(
        current,
        items.length,
        'در حال محاسبه هش تصاویر ($current از ${items.length})',
      );

      if (item.isVideo) {
        continue;
      }

      // قبلاً محاسبه شده است
      if (item.pHash != null) {
        continue;
      }

      item.pHash = await _pHash(item.path);

      item.analyzed = true;
    }
  }
  //---------------------------------------------------------------------------
  // ساخت گروه های مشابه
  //---------------------------------------------------------------------------

  Future<List<DuplicateGroup>> _buildGroups(
    List<MediaItem> items,
    AnalysisController controller,
    void Function(int, int, String)? onProgress,
  ) async {
    final groups = <DuplicateGroup>[];

    final visited = <MediaItem>{};

    // فقط تصاویری که Hash دارند
    final validItems = items
        .where((e) => !e.isVideo && e.pHash != null)
        .toList();

    int current = 0;

    for (final item in validItems) {
      if (!await controller.checkpoint()) {
        return [];
      }

      current++;

      onProgress?.call(
        current,
        validItems.length,
        'در حال مقایسه تصاویر ($current از ${validItems.length})',
      );

      if (visited.contains(item)) {
        continue;
      }

      final currentGroup = <MediaItem>[];

      currentGroup.add(item);

      visited.add(item);

      for (final other in validItems) {
        if (!await controller.checkpoint()) {
          return [];
        }

        if (identical(item, other)) {
          continue;
        }

        if (visited.contains(other)) {
          continue;
        }

        if (other.pHash == null) {
          continue;
        }

        final distance = _hammingDistance(item.pHash!, other.pHash!);

        if (distance <= similarityThreshold) {
          currentGroup.add(other);

          visited.add(other);
        }
      }

      if (currentGroup.length > 1) {
        // مرتب‌سازی گروه بر اساس تاریخ
        currentGroup.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        groups.add(DuplicateGroup(items: currentGroup, selectedIndex: 0));
      }
    }

    return groups;
  }
  //---------------------------------------------------------------------------
  // Perceptual Hash (pHash)
  //---------------------------------------------------------------------------

  Future<BigInt?> _pHash(String path) async {
    try {
      final file = File(path);

      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();

      final image = img.decodeImage(bytes);

      if (image == null) {
        return null;
      }

      final resized = img.copyResize(image, width: 32, height: 32);

      final gray = img.grayscale(resized);

      final matrix = List.generate(32, (_) => List<double>.filled(32, 0));

      for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
          matrix[y][x] = gray.getPixel(x, y).r.toDouble();
        }
      }

      final dct = _applyDCT(matrix);

      final values = <double>[];

      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          if (x == 0 && y == 0) continue;

          values.add(dct[y][x]);
        }
      }

      values.sort();

      final median = values[values.length ~/ 2];

      BigInt hash = BigInt.zero;

      int bit = 0;

      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          if (x == 0 && y == 0) continue;

          if (dct[y][x] > median) {
            hash |= (BigInt.one << bit);
          }

          bit++;
        }
      }

      return hash;
    } catch (_) {
      return null;
    }
  }

  //---------------------------------------------------------------------------
  // Discrete Cosine Transform
  //---------------------------------------------------------------------------

  List<List<double>> _applyDCT(List<List<double>> input) {
    const int n = 32;

    final output = List.generate(n, (_) => List<double>.filled(n, 0));

    for (int u = 0; u < n; u++) {
      final cu = u == 0 ? 1 / math.sqrt(2) : 1.0;

      for (int v = 0; v < n; v++) {
        final cv = v == 0 ? 1 / math.sqrt(2) : 1.0;

        double sum = 0;

        for (int x = 0; x < n; x++) {
          for (int y = 0; y < n; y++) {
            sum +=
                input[x][y] *
                math.cos(((2 * x + 1) * u * math.pi) / (2 * n)) *
                math.cos(((2 * y + 1) * v * math.pi) / (2 * n));
          }
        }

        output[u][v] = 0.25 * cu * cv * sum;
      }
    }

    return output;
  }

  //---------------------------------------------------------------------------
  // Hamming Distance
  //---------------------------------------------------------------------------

  int _hammingDistance(BigInt a, BigInt b) {
    BigInt xor = a ^ b;

    int count = 0;

    while (xor != BigInt.zero) {
      count++;

      xor &= (xor - BigInt.one);
    }

    return count;
  }
}
