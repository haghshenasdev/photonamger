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

  TransferService({
    MetadataService? metadataService,
  }) : metadataService =
            metadataService ?? const MetadataService();

  // ============================================================
  // ذخیره فقط Metadata
  // ============================================================

  /// فقط اطلاعات گروه‌ها را در پوشه مقصد ذخیره می‌کند.
  ///
  /// هیچ عکس یا ویدیویی:
  /// - کپی نمی‌شود
  /// - Move نمی‌شود
  /// - حذف نمی‌شود
  /// - مسیرش تغییر نمی‌کند
  ///
  /// فقط پوشه مقصد ساخته شده و فایل:
  ///
  /// .photonamger.json
  ///
  /// داخل آن قرار می‌گیرد.
  Future<void> saveMetadataOnly({
    required List<TimelineGroup> groups,
    required ApplySettings settings,
    void Function(int current, int total)? onProgress,
  }) async {
    final editableGroups = groups.where((group) {
      return group.edited || group.metadata != null;
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
        categories: List<String>.from(group.categories),
        description: group.description,
      );

      await metadataService.save(
        directoryPath: folder.path,
        metadata: metadata,
      );

      group.edited = false;

      current++;

      onProgress?.call(
        current,
        total,
      );
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
    // ------------------------------------------------------
    // عکس‌های منتخب گروه‌های تکراری
    // ------------------------------------------------------

    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(group.primary.path);

      for (final item in group.items) {
        duplicateFiles.add(item.path);
      }
    }

    // ------------------------------------------------------
    // محاسبه تعداد فایل‌ها
    // ------------------------------------------------------

    int total = 0;

    for (final timeline in groups) {
      for (final item in timeline.items) {
        if (_shouldTransfer(
          item,
          duplicateFiles,
          selectedDuplicateFiles,
        )) {
          total++;
        }
      }
    }

    // ------------------------------------------------------
    // انتقال
    // ------------------------------------------------------

    int current = 0;

    final results = <TransferResult>[];

    for (final timeline in groups) {
      final folder = await FolderBuilder.build(
        settings: settings,
        group: timeline,
      );

      for (final item in timeline.items) {
        if (!_shouldTransfer(
          item,
          duplicateFiles,
          selectedDuplicateFiles,
        )) {
          continue;
        }

        final oldPath = item.path;

        final source = File(oldPath);

        // --------------------------------------------------
        // فایل مبدأ وجود ندارد
        // --------------------------------------------------

        if (!await source.exists()) {
          continue;
        }

        // --------------------------------------------------
        // مسیر مقصد
        // --------------------------------------------------

        final destinationPath = p.join(
          folder.path,
          item.fileName,
        );

        final destination = File(destinationPath);

        // --------------------------------------------------
        // اگر مقصد همان فایل مبدأ است
        // --------------------------------------------------

        final normalizedSource = p.normalize(
          p.absolute(oldPath),
        );

        final normalizedDestination = p.normalize(
          p.absolute(destinationPath),
        );

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

        // --------------------------------------------------
        // اگر فایل مقصد از قبل وجود دارد
        // --------------------------------------------------

        if (await destination.exists()) {
          final uniquePath =
              await _createUniqueFilePath(destinationPath);

          await _transferFile(
            source: source,
            destinationPath: uniquePath,
            move: settings.moveFiles,
          );

          final result = TransferResult(
            item: item,
            oldPath: oldPath,
            newPath: uniquePath,
          );

          results.add(result);

          item.updatePath(uniquePath);

          onItemTransferred?.call(result);

          current++;

          onProgress?.call(
            TransferProgress(
              current: current,
              total: total,
              fileName: item.fileName,
            ),
          );

          continue;
        }

        // --------------------------------------------------
        // انتقال عادی
        // --------------------------------------------------

        await _transferFile(
          source: source,
          destinationPath: destinationPath,
          move: settings.moveFiles,
        );

        final result = TransferResult(
          item: item,
          oldPath: oldPath,
          newPath: destinationPath,
        );

        results.add(result);

        item.updatePath(destinationPath);

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

      // ----------------------------------------------------
      // ذخیره Metadata بعد از انتقال گروه
      // ----------------------------------------------------

      final hasMetadata =
          timeline.categories.isNotEmpty ||
          timeline.description.trim().isNotEmpty ||
          timeline.metadata != null;

      if (hasMetadata) {
        final metadata = GroupMetadata(
          categories: List<String>.from(
            timeline.categories,
          ),
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

    await destination.parent.create(
      recursive: true,
    );

    if (move) {
      await source.rename(destinationPath);
    } else {
      await source.copy(destinationPath);
    }
  }

  // ============================================================
  // ساخت مسیر یکتا
  // ============================================================

  Future<String> _createUniqueFilePath(
    String originalPath,
  ) async {
    final file = File(originalPath);

    if (!await file.exists()) {
      return originalPath;
    }

    final directory = file.parent;

    final extension = p.extension(file.path);

    final baseName = p.basenameWithoutExtension(
      file.path,
    );

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
  // تشخیص اینکه فایل باید منتقل شود یا خیر
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