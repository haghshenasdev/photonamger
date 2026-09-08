import 'dart:io';

import '../ui/models/group_metadata.dart';
import '../ui/models/media_item.dart';
import '../ui/models/timeline_group.dart';

class TimelineBuilder {
  List<TimelineGroup> build(
    List<MediaItem> items, {
    Duration gap = const Duration(minutes: 30),
    void Function(int current, int total, String status)? onProgress,
  }) {
    if (items.isEmpty) {
      return <TimelineGroup>[];
    }

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final gapMinutes = gap.inMinutes;

    final groups = <TimelineGroup>[];

    var current = <MediaItem>[];

    current.add(items.first);

    for (int i = 1; i < items.length; i++) {
      onProgress?.call(i, items.length, 'در حال دسته‌بندی زمانی...');

      final previous = items[i - 1];

      final currentItem = items[i];

      final diff = currentItem.createdAt.difference(previous.createdAt);

      // --------------------------------------------------
      // اگر metadata پوشه تغییر کرده باشد،
      // باید مرز گروه حفظ شود.
      // --------------------------------------------------

      final metadataBoundary = _hasMetadataBoundary(previous, currentItem);

      if (diff.inMinutes > gapMinutes || metadataBoundary) {
        final group = _createGroup(groups.length + 1, current);

        groups.add(group);

        current = [];
      }

      current.add(currentItem);
    }

    if (current.isNotEmpty) {
      final group = _createGroup(groups.length + 1, current);

      groups.add(group);
    }

    onProgress?.call(items.length, items.length, 'دسته‌بندی زمانی پایان یافت');

    return groups;
  }

  bool _hasMetadataBoundary(MediaItem previous, MediaItem current) {
    final previousDirectory = previous.metadataDirectory;

    final currentDirectory = current.metadataDirectory;

    // هیچ‌کدام metadata ندارند.
    if (previousDirectory == null && currentDirectory == null) {
      return false;
    }

    // یکی metadata دارد و دیگری ندارد.
    if (previousDirectory == null || currentDirectory == null) {
      return true;
    }

    return !_samePath(previousDirectory, currentDirectory);
  }

  bool _samePath(String a, String b) {
    final first = a.replaceAll('\\', '/').toLowerCase();

    final second = b.replaceAll('\\', '/').toLowerCase();

    return first == second;
  }

  TimelineGroup _createGroup(int index, List<MediaItem> items) {
    final metadata = _resolveMetadata(items);

    return TimelineGroup(
      // --------------------------------------------------
      // اگر metadata وجود دارد،
      // نام واقعی پوشه را بعداً از metadataDirectory
      // می‌گیریم.
      //
      // فعلاً عنوان موقت:
      // --------------------------------------------------
      title: metadata != null
          ? _directoryName(_resolveMetadataDirectory(items))
          : 'گروه $index',

      start: items.first.createdAt,
      end: items.last.createdAt,

      items: List<MediaItem>.from(items),

      metadata: metadata,

      metadataDirectory: _resolveMetadataDirectory(items),
    );
  }

  GroupMetadata? _resolveMetadata(List<MediaItem> items) {
    if (items.isEmpty) {
      return null;
    }

    // چون TimelineBuilder بر اساس metadataDirectory
    // گروه‌ها را جدا کرده، معمولاً تمام آیتم‌ها
    // متعلق به یک metadata هستند.
    for (final item in items) {
      if (item.groupMetadata != null) {
        return item.groupMetadata;
      }
    }

    return null;
  }

  String? _resolveMetadataDirectory(List<MediaItem> items) {
    final directories = items
        .map((item) => item.metadataDirectory)
        .whereType<String>()
        .toSet();

    if (directories.length == 1) {
      return directories.first;
    }

    return null;
  }

  String _directoryName(String? directoryPath) {
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      return 'گروه';
    }

    return directoryPath
        .replaceAll('\\', '/')
        .split('/')
        .where((e) => e.isNotEmpty)
        .last;
  }

  List<TimelineGroup> rebuild(List<MediaItem> items) {
    return build(items);
  }

  TimelineGroup merge(List<TimelineGroup> groups) {
    if (groups.isEmpty) {
      throw ArgumentError('حداقل یک گروه برای ادغام لازم است.');
    }

    groups.sort((a, b) => a.start.compareTo(b.start));

    final items = <MediaItem>[];

    for (final group in groups) {
      items.addAll(group.items);
    }

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // --------------------------------------------------
    // اگر گروه‌ها merge شوند، metadata قبلی دیگر
    // به شکل مستقیم قابل اتکا نیست.
    //
    // فعلاً metadata را null می‌کنیم.
    // هنگام Apply metadata جدید ساخته خواهد شد.
    // --------------------------------------------------

    return TimelineGroup(
      title: 'گروه ادغام شده',
      start: items.first.createdAt,
      end: items.last.createdAt,
      items: items,
      metadata: null,
      metadataDirectory: null,
      merged: true,
    );
  }
}
