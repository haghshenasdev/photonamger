import 'dart:io';

import 'package:fgphoto/core/apply/folder_builder.dart';
import 'package:fgphoto/core/metadata/metadata_service.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:path/path.dart' as p;

class TransferProgress {
  final int current;
  final int total;
  final String fileName;

  const TransferProgress({
    required this.current,
    required this.total,
    required this.fileName,
  });

  double get percent {
    return total == 0 ? 0 : current / total;
  }
}

/// نتیجه انتقال یک فایل.
class TransferResult {
  final MediaItem item;

  final String oldPath;

  final String newPath;

  const TransferResult({
    required this.item,
    required this.oldPath,
    required this.newPath,
  });
}

class TransferService {
  final MetadataService metadataService;

  TransferService({MetadataService? metadataService})
    : metadataService = metadataService ?? const MetadataService();

  // ============================================================
  // ذخیره فقط Metadata
  // ============================================================

  /// فقط اطلاعات گروه‌ها را ذخیره می‌کند.
  ///
  /// هیچ عکس یا ویدیویی منتقل یا کپی نمی‌شود.
  Future<void> saveMetadataOnly({
    required List<TimelineGroup> groups,
    required ApplySettings settings,
    void Function(int current, int total)? onProgress,
  }) async {
    final editableGroups = groups.where((group) {
      return group.edited;
    }).toList();

    if (editableGroups.isEmpty) {
      return;
    }

    int current = 0;

    final total = editableGroups.length;

    for (final group in editableGroups) {
      final folder = await FolderBuilder.build(
        settings: settings,
        group: group,
      );

      final metadata = GroupMetadata(
        categories: group.categories
            .map((path) => List<String>.from(path))
            .toList(),
        description: group.description,
      );

      await metadataService.save(
        directoryPath: folder.path,
        metadata: metadata,
      );

      group.edited = false;

      current++;

      onProgress?.call(current, total);
    }
  }

  // ============================================================
  // انتقال فایل‌ها
  // ============================================================

  Future<List<TransferResult>> execute({
    required List<TimelineGroup> groups,
    required List<DuplicateGroup> duplicateGroups,
    required ApplySettings settings,
    void Function(TransferProgress progress)? onProgress,
    void Function(TransferResult result)? onItemTransferred,
  }) async {
    // ----------------------------------------------------------
    // فایل‌های گروه‌های تکراری
    // ----------------------------------------------------------

    final selectedDuplicateFiles = <String>{};

    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(group.primary.path);

      for (final item in group.items) {
        duplicateFiles.add(item.path);
      }
    }

    // ----------------------------------------------------------
    // تعداد فایل‌ها
    // ----------------------------------------------------------

    int total = 0;

    for (final timeline in groups) {
      for (final item in timeline.items) {
        if (_shouldTransfer(item, duplicateFiles, selectedDuplicateFiles)) {
          total++;
        }
      }
    }

    // ----------------------------------------------------------
    // انتقال
    // ----------------------------------------------------------

    int current = 0;

    final results = <TransferResult>[];

    for (final timeline in groups) {
      final folder = await FolderBuilder.build(
        settings: settings,
        group: timeline,
      );

      for (final item in timeline.items) {
        if (!_shouldTransfer(item, duplicateFiles, selectedDuplicateFiles)) {
          continue;
        }

        final oldPath = item.path;

        final source = File(oldPath);

        // ------------------------------------------------------
        // فایل وجود ندارد
        // ------------------------------------------------------

        if (!await source.exists()) {
          continue;
        }

        // ------------------------------------------------------
        // مسیر مقصد
        // ------------------------------------------------------

        final destinationPath = p.join(folder.path, item.fileName);

        final destination = File(destinationPath);

        // ------------------------------------------------------
        // اگر مقصد همان فایل مبدأ است
        // ------------------------------------------------------

        final normalizedSource = p.normalize(p.absolute(oldPath));

        final normalizedDestination = p.normalize(p.absolute(destinationPath));

        if (normalizedSource == normalizedDestination) {
          current++;

          final result = TransferResult(
            item: item,
            oldPath: oldPath,
            newPath: destinationPath,
          );

          results.add(result);

          onItemTransferred?.call(result);

          onProgress?.call(
            TransferProgress(
              current: current,
              total: total,
              fileName: item.fileName,
            ),
          );

          continue;
        }

        // ------------------------------------------------------
        // فایل مقصد قبلاً وجود دارد
        // ------------------------------------------------------

        String finalDestination = destinationPath;

        if (await destination.exists()) {
          finalDestination = await _createUniqueFilePath(destinationPath);
        }

        // ------------------------------------------------------
        // انتقال
        // ------------------------------------------------------

        await _transferFile(
          source: source,
          destinationPath: finalDestination,
          move: settings.moveFiles,
        );

        final result = TransferResult(
          item: item,
          oldPath: oldPath,
          newPath: finalDestination,
        );

        results.add(result);

        item.updatePath(finalDestination);

        onItemTransferred?.call(result);

        current++;

        onProgress?.call(
          TransferProgress(
            current: current,
            total: total,
            fileName: item.fileName,
          ),
        );
      }

      // --------------------------------------------------------
      // ذخیره Metadata بعد از انتقال گروه
      // --------------------------------------------------------

      if (timeline.metadata != null || timeline.edited) {
        final metadata = GroupMetadata(
          categories: timeline.categories
              .map((path) => List<String>.from(path))
              .toList(),
          description: timeline.description,
        );

        await metadataService.save(
          directoryPath: folder.path,
          metadata: metadata,
        );

        timeline.edited = false;
      }
    }

    return results;
  }

  // ============================================================
  // انتقال فایل
  // ============================================================

  Future<void> _transferFile({
    required File source,
    required String destinationPath,
    required bool move,
  }) async {
    final destination = File(destinationPath);

    await destination.parent.create(recursive: true);

    if (move) {
      await source.rename(destinationPath);
    } else {
      await source.copy(destinationPath);
    }
  }

  // ============================================================
  // مسیر یکتا
  // ============================================================

  Future<String> _createUniqueFilePath(String originalPath) async {
    final file = File(originalPath);

    if (!await file.exists()) {
      return originalPath;
    }

    final directory = file.parent;

    final extension = p.extension(file.path);

    final baseName = p.basenameWithoutExtension(file.path);

    int counter = 1;

    while (true) {
      final candidate = p.join(
        directory.path,
        '$baseName ($counter)$extension',
      );

      if (!await File(candidate).exists()) {
        return candidate;
      }

      counter++;
    }
  }

  // ============================================================
  // آیا فایل باید منتقل شود؟
  // ============================================================

  bool _shouldTransfer(
    MediaItem item,
    Set<String> duplicateFiles,
    Set<String> selectedDuplicateFiles,
  ) {
    if (duplicateFiles.contains(item.path)) {
      return selectedDuplicateFiles.contains(item.path);
    }

    return item.isSelected;
  }
}
