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
    if (total <= 0) {
      return 0;
    }

    return current / total;
  }
}

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

  Future<List<TransferResult>> execute({
    required List<TimelineGroup> groups,
    required List<DuplicateGroup> duplicateGroups,
    required ApplySettings settings,
    void Function(TransferProgress progress)? onProgress,
    void Function(TransferResult result)? onItemTransferred,
  }) async {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(group.primary.path);

      for (final item in group.items) {
        duplicateFiles.add(item.path);
      }
    }

    int total = 0;

    for (final timeline in groups) {
      for (final item in timeline.items) {
        if (_shouldTransfer(item, duplicateFiles, selectedDuplicateFiles)) {
          total++;
        }
      }
    }

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

        if (!await source.exists()) {
          continue;
        }

        final destinationPath = p.join(folder.path, item.fileName);

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

        String finalDestination = destinationPath;

        if (await File(finalDestination).exists()) {
          finalDestination = await _createUniqueFilePath(destinationPath);
        }

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

      await _saveGroupMetadata(timeline, folder.path);
    }

    return results;
  }

  /// فقط metadata را ذخیره می‌کند.
  ///
  /// هیچ عکس یا ویدیویی منتقل یا کپی نمی‌شود.
  Future<void> saveMetadataOnly({
    required List<TimelineGroup> groups,
    required ApplySettings settings,
  }) async {
    for (final group in groups) {
      if (!group.edited) {
        continue;
      }

      final folder = await FolderBuilder.build(
        settings: settings,
        group: group,
      );

      await _saveGroupMetadata(group, folder.path);

      group.edited = false;
    }
  }

  Future<void> _saveGroupMetadata(
    TimelineGroup group,
    String directoryPath,
  ) async {
    final metadata = group.metadata;

    if (metadata == null) {
      return;
    }

    final normalizedCategories = metadata.categories
        .map(
          (path) => path
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        )
        .where((path) => path.isNotEmpty)
        .toList();

    final normalizedMetadata = GroupMetadata(
      version: metadata.version,
      categories: normalizedCategories,
      description: metadata.description.trim(),
    );

    await metadataService.save(
      directoryPath: directoryPath,
      metadata: normalizedMetadata,
    );
  }

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

    if (!await destination.exists()) {
      throw FileSystemException('فایل مقصد ایجاد نشد', destinationPath);
    }
  }

  Future<String> _createUniqueFilePath(String originalPath) async {
    final file = File(originalPath);

    if (!await file.exists()) {
      return originalPath;
    }

    final directory = file.parent.path;

    final extension = p.extension(originalPath);

    final basename = p.basenameWithoutExtension(originalPath);

    int counter = 1;

    while (true) {
      final candidate = p.join(directory, '$basename ($counter)$extension');

      if (!await File(candidate).exists()) {
        return candidate;
      }

      counter++;
    }
  }

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
