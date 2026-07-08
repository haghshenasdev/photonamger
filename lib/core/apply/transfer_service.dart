import 'dart:io';

import 'package:fgphoto/core/apply/folder_builder.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
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

  double get percent => total == 0 ? 0 : current / total;
}

class TransferService {
  Future<void> execute({
    required List<TimelineGroup> groups,
    required List<DuplicateGroup> duplicateGroups,
    required ApplySettings settings,
    void Function(TransferProgress progress)? onProgress,
  }) async {
    //------------------------------------------------------
    // عکس‌های منتخب گروه‌های تکراری
    //------------------------------------------------------

    final selectedDuplicateFiles = <String>{};

    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(group.primary.path);

      for (final item in group.items) {
        duplicateFiles.add(item.path);
      }
    }

    //------------------------------------------------------
    // تعداد فایل‌ها
    //------------------------------------------------------

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

    //------------------------------------------------------
    // انتقال
    //------------------------------------------------------

    int current = 0;

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

        final source = File(item.path);

        if (!await source.exists()) {
          continue;
        }

        final destination = p.join(
          folder.path,
          item.fileName,
        );

        if (settings.moveFiles) {
          await source.rename(destination);
        } else {
          await source.copy(destination);
        }

        current++;

        onProgress?.call(
          TransferProgress(
            current: current,
            total: total,
            fileName: item.fileName,
          ),
        );
      }
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