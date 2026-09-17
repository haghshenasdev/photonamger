import 'dart:io';

import 'package:fgphoto/core/project/project_operation.dart';
import 'package:fgphoto/core/metadata/metadata_service.dart';
import 'package:fgphoto/core/apply/folder_builder.dart';
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

  double get percent => total <= 0 ? 0 : current / total;
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

  /// قبل از شروع انتقال، تمام عملیات را با مقصد مشخص در پروژه ثبت می‌کند.
  ///
  /// این مرحله مهم است: اگر برق بعد از آن قطع شود، برنامه می‌داند دقیقاً
  /// چه فایل‌هایی قرار بوده به کجا منتقل شوند.
  Future<int> prepareOperations({
    required List<TimelineGroup> groups,
    required List<DuplicateGroup> duplicateGroups,
    required ApplySettings settings,
    required List<ProjectOperation> operations,
    void Function(ProjectOperation operation)? onOperationChanged,
  }) async {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(_key(group.primary.path));
      for (final item in group.items) {
        duplicateFiles.add(_key(item.path));
      }
    }

    final reservedDestinations = <String>{
      for (final operation in operations) _key(operation.destinationPath),
    };

    int planned = 0;

    for (final timeline in groups) {
      final groupFolder = await _resolveGroupFolder(
        group: timeline,
        settings: settings,
      );

      final deleteFolder = settings.outputFolder.trim().isEmpty
          ? Directory(p.join(groupFolder.parent.path, 'For Delete'))
          : null;

      if (deleteFolder != null) {
        await deleteFolder.create(recursive: true);
      }

      for (final item in timeline.items) {
        final key = _key(item.path);
        final isDuplicate = duplicateFiles.contains(key);
        final isSelectedDuplicate = selectedDuplicateFiles.contains(key);

        final shouldKeep = isDuplicate
            ? isSelectedDuplicate
            : item.isSelected;

        // در حالت اعمال درجا، هر فایل انتخاب‌نشده یا duplicate غیرمنتخب
        // به For Delete منتقل می‌شود.
        final shouldDelete = settings.outputFolder.trim().isEmpty &&
            !shouldKeep &&
            settings.moveFiles;

        if (!shouldKeep && !shouldDelete) {
          continue;
        }

        final destinationFolder = shouldDelete
            ? deleteFolder!
            : groupFolder;

        final existing = _findOperation(
          operations,
          item.path,
          settings.moveFiles,
        );

        if (existing != null) {
          planned++;
          continue;
        }

        final destinationPath = p.join(destinationFolder.path, item.fileName);
        final finalDestination = await _createUniqueFilePath(
          destinationPath,
          reservedPaths: reservedDestinations,
        );

        reservedDestinations.add(_key(finalDestination));

        final operation = ProjectOperation(
          id: '${DateTime.now().microsecondsSinceEpoch}_${planned + 1}',
          sourcePath: item.path,
          destinationPath: finalDestination,
          type: settings.moveFiles
              ? ProjectOperationType.move
              : ProjectOperationType.copy,
        );

        // اگر فایل همین حالا در مقصد صحیح قرار دارد، هیچ انتقالی انجام نده.
        // این حالت مخصوصاً در «اعمال درجا» مهم است؛ delete کردن source وقتی
        // source و destination یکی هستند می‌تواند باعث از بین رفتن فایل شود.
        if (_key(item.path) == _key(finalDestination)) {
          operation.status = ProjectOperationStatus.completed;
          operation.completedAt = DateTime.now();
        }

        operations.add(operation);
        onOperationChanged?.call(operation);
        planned++;
      }
    }

    return planned;
  }

  /// مقصد هر گروه را تعیین می‌کند.
  ///
  /// وقتی مسیر خروجی خالی است، عملیات درجا است:
  /// - اگر گروه از قبل پوشه metadata خودش را دارد و فایل‌های گروه در همان
  ///   پوشه هستند، همان پوشه حفظ می‌شود.
  /// - اگر فایل‌ها همگی در یک پوشه باشند، همان پوشه مقصد است.
  /// - در حالت پراکنده، یک پوشه مناسب بر اساس ساختار انتخاب‌شده ساخته می‌شود.
  Future<Directory> _resolveGroupFolder({
    required TimelineGroup group,
    required ApplySettings settings,
  }) async {
    if (settings.outputFolder.trim().isNotEmpty) {
      return FolderBuilder.build(settings: settings, group: group);
    }

    final existingMetadataDirectory = group.metadataDirectory?.trim();

    if (existingMetadataDirectory != null &&
        existingMetadataDirectory.isNotEmpty) {
      final metadataDirectory = Directory(existingMetadataDirectory);

      if (await metadataDirectory.exists()) {
        final allInsideMetadata = group.items.isNotEmpty &&
            group.items.every(
              (item) => _isSameOrDirectChild(item.path, metadataDirectory.path),
            );

        if (allInsideMetadata) {
          return metadataDirectory;
        }
      }
    }

    final parentDirectories = <String>{};
    for (final item in group.items) {
      parentDirectories.add(_key(File(item.path).parent.path));
    }

    if (parentDirectories.length == 1) {
      return Directory(parentDirectories.first);
    }

    // فایل‌ها در چند پوشه هستند؛ نزدیک‌ترین والد مشترک را پیدا می‌کنیم.
    final commonParent = _commonParentPath(
      group.items.map((item) => File(item.path).parent.path).toList(),
    );

    final base = commonParent ??
        (group.items.isNotEmpty
            ? File(group.items.first.path).parent.path
            : Directory.current.path);

    final localSettings = settings.copyWith(outputFolder: base);
    return FolderBuilder.build(settings: localSettings, group: group);
  }

  bool _isSameOrDirectChild(String filePath, String directoryPath) {
    final fileParent = _key(File(filePath).parent.path);
    final directory = _key(directoryPath);
    return fileParent == directory;
  }

  String? _commonParentPath(List<String> paths) {
    if (paths.isEmpty) return null;

    final splitPaths = paths.map((path) {
      final normalized = p.normalize(p.absolute(path));
      return normalized.split(p.separator);
    }).toList();

    final first = splitPaths.first;
    int commonLength = first.length;

    for (final parts in splitPaths.skip(1)) {
      commonLength = commonLength < parts.length
          ? commonLength
          : parts.length;

      for (int i = 0; i < commonLength; i++) {
        if (_key(first[i]) != _key(parts[i])) {
          commonLength = i;
          break;
        }
      }
    }

    if (commonLength <= 0) return null;

    var result = first.take(commonLength).join(p.separator);

    // Windows drive root مثل C:\
    if (result.length == 2 && result.endsWith(':')) {
      result += p.separator;
    }

    return result;
  }

  Future<List<TransferResult>> execute({
    required List<TimelineGroup> groups,
    required List<DuplicateGroup> duplicateGroups,
    required ApplySettings settings,
    required List<ProjectOperation> operations,
    void Function(TransferProgress progress)? onProgress,
    void Function(TransferResult result)? onItemTransferred,
    void Function(ProjectOperation operation)? onOperationChanged,
    bool saveMetadata = true,
  }) async {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(_key(group.primary.path));

      for (final item in group.items) {
        duplicateFiles.add(_key(item.path));
      }
    }

    final transferOperations = operations.where((operation) {
      return operation.type ==
          (settings.moveFiles
              ? ProjectOperationType.move
              : ProjectOperationType.copy);
    }).toList();

    final itemByPath = <String, MediaItem>{};

    for (final group in groups) {
      for (final item in group.items) {
        itemByPath[_key(item.path)] = item;
      }
    }

    final total = transferOperations.length;
    int current = transferOperations.where((e) => e.isFinished).length;

    final results = <TransferResult>[];

    for (final operation in transferOperations) {
      final item = itemByPath[_key(operation.sourcePath)];

      // عملیات completed ممکن است بعد از Save انجام شده باشد و path آیتم
      // در فایل پروژه هنوز source باشد. در این حالت آن را اصلاح می‌کنیم.
      if (operation.isFinished) {
        if (item != null &&
            _key(item.path) == _key(operation.sourcePath)) {
          item.updatePath(operation.destinationPath);
        }
        continue;
      }

      if (item == null) {
        operation.status = ProjectOperationStatus.failed;
        operation.error = 'فایل مربوط به عملیات در پروژه پیدا نشد.';
        onOperationChanged?.call(operation);
        continue;
      }

      final oldPath = operation.sourcePath;
      final source = File(oldPath);
      final destination = File(operation.destinationPath);

      try {
        operation.status = ProjectOperationStatus.processing;
        operation.startedAt ??= DateTime.now();
        operation.error = null;
        onOperationChanged?.call(operation);

        final completedFromDisk = await _recoverIfAlreadyTransferred(
          source: source,
          destination: destination,
          move: operation.type == ProjectOperationType.move,
        );

        if (!completedFromDisk) {
          if (!await source.exists()) {
            throw FileSystemException(
              'فایل مبدا پیدا نشد.',
              source.path,
            );
          }

          await _transferFile(
            source: source,
            destinationPath: destination.path,
            move: operation.type == ProjectOperationType.move,
          );
        }

        operation.status = ProjectOperationStatus.completed;
        operation.completedAt = DateTime.now();
        operation.error = null;
        item.updatePath(operation.destinationPath);

        current++;

        final result = TransferResult(
          item: item,
          oldPath: oldPath,
          newPath: operation.destinationPath,
        );

        results.add(result);

        onOperationChanged?.call(operation);
        onItemTransferred?.call(result);

        onProgress?.call(
          TransferProgress(
            current: current,
            total: total,
            fileName: p.basename(operation.destinationPath),
          ),
        );
      } catch (e) {
        operation.status = ProjectOperationStatus.failed;
        operation.error = e.toString();
        onOperationChanged?.call(operation);

        // ادامه سایر فایل‌ها ممکن است منطقی باشد؛ یک فایل خراب نباید
        // کل صف را از بین ببرد.
        current++;

        onProgress?.call(
          TransferProgress(
            current: current,
            total: total,
            fileName: p.basename(operation.destinationPath),
          ),
        );
      }
    }

    if (!saveMetadata) {
      return results;
    }

    // metadata همچنان مطابق رفتار قبلی ذخیره می‌شود.
    for (final timeline in groups) {
      try {
        final folder = await _resolveGroupFolder(
          group: timeline,
          settings: settings,
        );
        await _saveGroupMetadata(timeline, folder.path);
      } catch (_) {
        // خطای metadata نباید باعث از دست رفتن وضعیت انتقال فایل‌ها شود.
      }
    }

    return results;
  }

  Future<void> saveMetadataOnly({
    required List<TimelineGroup> groups,
    required ApplySettings settings,
  }) async {
    for (final group in groups) {
      if (!group.edited) continue;

      final folder = await _resolveGroupFolder(
        group: group,
        settings: settings,
      );

      await _saveGroupMetadata(group, folder.path);
      group.edited = false;
    }
  }

  Future<bool> _recoverIfAlreadyTransferred({
    required File source,
    required File destination,
    required bool move,
  }) async {
    final destinationExists = await destination.exists();
    if (!destinationExists) return false;

    final sourceExists = await source.exists();

    if (!sourceExists) {
      // برای Move، نبودن مبدا + وجود مقصد یعنی عملیات قبلاً تمام شده.
      // برای Copy هم همین وضعیت به معنی آن است که مبدا احتمالاً توسط
      // کاربر حذف شده؛ مقصد را معتبر در نظر می‌گیریم.
      return true;
    }

    final sourceLength = await source.length();
    final destinationLength = await destination.length();

    if (sourceLength != destinationLength) {
      // مقصد با اندازه متفاوت وجود دارد. هرگز آن را حذف یا overwrite نمی‌کنیم؛
      // ممکن است در فاصله بین دو اجرای برنامه فایل دیگری در آن مسیر ساخته شده باشد.
      throw FileSystemException(
        'فایل مقصد با اندازه متفاوت از قبل وجود دارد؛ برای جلوگیری از overwrite عملیات متوقف شد.',
        destination.path,
      );
    }

    // مقصد هم‌اندازه مبدا است. برای Copy کار تمام شده.
    // برای Move، مبدا را بعد از تأیید مقصد حذف می‌کنیم.
    if (move) {
      await source.delete();
    }

    return true;
  }

  Future<void> _transferFile({
    required File source,
    required String destinationPath,
    required bool move,
  }) async {
    final destination = File(destinationPath);

    await destination.parent.create(recursive: true);

    if (move) {
      try {
        await source.rename(destinationPath);
      } on FileSystemException {
        // اگر مبدا و مقصد روی دو درایو باشند، rename ممکن است شکست بخورد.
        // در این حالت Copy -> verify -> rename temp -> delete source.
        final tempPath = '$destinationPath.part';
        final temp = File(tempPath);

        if (await temp.exists()) {
          await temp.delete();
        }

        await source.copy(tempPath);

        final sourceLength = await source.length();
        final tempLength = await temp.length();

        if (sourceLength != tempLength) {
          throw FileSystemException(
            'اندازه فایل مقصد با مبدا برابر نیست.',
            destinationPath,
          );
        }

        if (await destination.exists()) {
          throw FileSystemException(
            'فایل مقصد هنگام انتقال ایجاد شد؛ برای جلوگیری از overwrite عملیات متوقف شد.',
            destinationPath,
          );
        }

        await temp.rename(destinationPath);
        await source.delete();
      }
    } else {
      final tempPath = '$destinationPath.part';
      final temp = File(tempPath);

      if (await temp.exists()) {
        await temp.delete();
      }

      await source.copy(tempPath);

      final sourceLength = await source.length();
      final tempLength = await temp.length();

      if (sourceLength != tempLength) {
        throw FileSystemException(
          'کپی فایل کامل نشده است.',
          destinationPath,
        );
      }

      if (await destination.exists()) {
        throw FileSystemException(
          'فایل مقصد هنگام کپی ایجاد شد؛ برای جلوگیری از overwrite عملیات متوقف شد.',
          destinationPath,
        );
      }

      await temp.rename(destinationPath);
    }

    if (!await destination.exists()) {
      throw FileSystemException(
        'فایل مقصد ایجاد نشد.',
        destinationPath,
      );
    }
  }

  Future<String> _createUniqueFilePath(
    String originalPath, {
    Set<String> reservedPaths = const {},
  }) async {
    final file = File(originalPath);

    if (!await file.exists() && !reservedPaths.contains(_key(originalPath))) {
      return originalPath;
    }

    final directory = file.parent.path;
    final extension = p.extension(originalPath);
    final basename = p.basenameWithoutExtension(originalPath);

    int counter = 1;

    while (true) {
      final candidate = p.join(
        directory,
        '$basename ($counter)$extension',
      );

      if (!await File(candidate).exists() &&
          !reservedPaths.contains(_key(candidate))) {
        return candidate;
      }

      counter++;
    }
  }

  ProjectOperation? _findOperation(
    List<ProjectOperation> operations,
    String sourcePath,
    bool move,
  ) {
    final type =
        move ? ProjectOperationType.move : ProjectOperationType.copy;

    for (final operation in operations.reversed) {
      if (operation.type == type &&
          _key(operation.sourcePath) == _key(sourcePath) &&
          !operation.isFinished) {
        return operation;
      }
    }

    return null;
  }

  bool _shouldTransfer(
    MediaItem item,
    Set<String> duplicateFiles,
    Set<String> selectedDuplicateFiles,
  ) {
    if (duplicateFiles.contains(_key(item.path))) {
      return selectedDuplicateFiles.contains(_key(item.path));
    }

    return item.isSelected;
  }

  String _key(String path) {
    var value = p.normalize(p.absolute(path));
    if (Platform.isWindows) {
      value = value.toLowerCase();
    }
    return value;
  }

  Future<void> _saveGroupMetadata(
    TimelineGroup group,
    String directoryPath,
  ) async {
    final metadata = group.metadata;
    if (metadata == null) return;

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
}
