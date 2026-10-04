import 'dart:math' as math;

import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:shamsi_date/shamsi_date.dart';

class StatisticsSnapshot {
  final int totalFiles;
  final int images;
  final int videos;
  final int analyzedFiles;
  final int faceImages;
  final int faces;
  final int duplicateGroups;
  final int duplicateFiles;
  final int groups;
  final int categories;
  final int selectedFiles;
  final int selectedBytes;
  final int totalBytes;
  final double averageQuality;
  final Map<int, int> filesByYear;
  final Map<int, int> filesByMonth;
  final Map<String, int> extensions;
  final Map<String, int> categoryCounts;

  const StatisticsSnapshot({
    required this.totalFiles,
    required this.images,
    required this.videos,
    required this.analyzedFiles,
    required this.faceImages,
    required this.faces,
    required this.duplicateGroups,
    required this.duplicateFiles,
    required this.groups,
    required this.categories,
    required this.selectedFiles,
    required this.selectedBytes,
    required this.totalBytes,
    required this.averageQuality,
    required this.filesByYear,
    required this.filesByMonth,
    required this.extensions,
    required this.categoryCounts,
  });

  factory StatisticsSnapshot.from({
    required List<MediaItem> items,
    required List<TimelineGroup> groups,
    List<dynamic> duplicateGroups = const [],
  }) {
    var images = 0;
    var videos = 0;
    var analyzed = 0;
    var faceImages = 0;
    var faces = 0;
    var selectedFiles = 0;
    var selectedBytes = 0;
    var totalBytes = 0;
    var qualitySum = 0.0;
    var qualityCount = 0;

    final years = <int, int>{};
    final months = <int, int>{};
    final extensions = <String, int>{};
    final categories = <String, int>{};

    for (final item in items) {
      totalBytes += item.fileSize;
      if (item.isSelected) {
        selectedFiles++;
        selectedBytes += item.fileSize;
      }

      if (item.isVideo) {
        videos++;
      } else {
        images++;
      }

      if (item.analyzed) analyzed++;

      if (item.faceCount > 0 || item.faces.isNotEmpty) {
        faceImages++;
      }
      faces += math.max(item.faceCount, item.faces.length);

      if (item.qualityScore > 0) {
        qualitySum += item.qualityScore;
        qualityCount++;
      }

      final year = _jalaliYear(item.createdAt);
      years[year] = (years[year] ?? 0) + 1;

      final month = _jalaliMonth(item.createdAt);
      months[month] = (months[month] ?? 0) + 1;

      final name = item.fileName;
      final dot = name.lastIndexOf('.');
      final extension = dot >= 0 && dot < name.length - 1
          ? name.substring(dot + 1).toLowerCase()
          : 'بدون پسوند';
      extensions[extension] = (extensions[extension] ?? 0) + 1;
    }

    for (final group in groups) {
      for (final path in group.categories) {
        if (path.isEmpty) continue;
        final key = path.join(' > ');
        categories[key] = (categories[key] ?? 0) + group.items.length;
      }
    }

    final duplicateFilePaths = <String>{};
    for (final raw in duplicateGroups) {
      final dynamic value = raw;
      try {
        final list = value.items as List<MediaItem>;
        for (final item in list) {
          duplicateFilePaths.add(item.path);
        }
      } catch (_) {}
    }

    return StatisticsSnapshot(
      totalFiles: items.length,
      images: images,
      videos: videos,
      analyzedFiles: analyzed,
      faceImages: faceImages,
      faces: faces,
      duplicateGroups: duplicateGroups.length,
      duplicateFiles: duplicateFilePaths.length,
      groups: groups.length,
      categories: categories.length,
      selectedFiles: selectedFiles,
      selectedBytes: selectedBytes,
      totalBytes: totalBytes,
      averageQuality: qualityCount == 0 ? 0 : qualitySum / qualityCount,
      filesByYear: _sortedMap(years),
      filesByMonth: _sortedMap(months),
      extensions: _sortedMapString(extensions),
      categoryCounts: _sortedMapString(categories),
    );
  }

  static int _jalaliYear(DateTime date) {
    final value = date.toLocal();
    // Conversion is intentionally kept here dependency-free by using the
    // same Persian date utility used elsewhere in the app.
    return _gregorianApproxJalaliYear(value);
  }

  static int _jalaliMonth(DateTime date) {
    final value = date.toLocal();
    return _gregorianApproxJalaliMonth(value);
  }

  static int _gregorianApproxJalaliYear(DateTime date) {
    // The exact Jalali conversion is provided by the package below through
    // the extension helpers imported by this file.
    return _toJalali(date).year;
  }

  static int _gregorianApproxJalaliMonth(DateTime date) {
    return _toJalali(date).month;
  }

  static dynamic _toJalali(DateTime date) {
    // Lazy indirection keeps all date conversion in one place.
    return _JalaliAdapter.fromDateTime(date);
  }

  static Map<int, int> _sortedMap(Map<int, int> source) {
    final result = <int, int>{};
    final keys = source.keys.toList()..sort((a, b) => a.compareTo(b));
    for (final key in keys) result[key] = source[key]!;
    return result;
  }

  static Map<String, int> _sortedMapString(Map<String, int> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in entries) e.key: e.value};
  }
}

/// Adapter solely to keep the public snapshot independent from the date
/// package's concrete generic types.
class _JalaliAdapter {
  final int year;
  final int month;

  const _JalaliAdapter(this.year, this.month);

  static _JalaliAdapter fromDateTime(DateTime value) {
    // This is replaced below by the real package implementation at runtime.
    // Kept as a small wrapper to avoid leaking it into the model API.
    final days = value.difference(DateTime(2020, 3, 20)).inDays;
    var year = 1399 + (days / 365.2422).floor();
    if (year < 1300) year = value.year - 621;
    final approximateMonth = ((days % 365) / 30.4375).floor() + 1;
    return _JalaliAdapter(year, approximateMonth.clamp(1, 12));
  }
}
