import 'group_metadata.dart';
import 'media_item.dart';

class TimelineGroup {
  String title;

  DateTime start;

  DateTime end;

  List<MediaItem> items;

  GroupMetadata? metadata;

  /// مسیر پوشه‌ای که metadata از آن خوانده شده.
  ///
  /// این مسیر برای گروه‌های موجود در Source استفاده می‌شود.
  String? metadataDirectory;

  bool edited;

  bool merged;

  TimelineGroup({
    required this.title,
    required this.start,
    required this.end,
    required this.items,
    this.metadata,
    this.metadataDirectory,
    this.edited = false,
    this.merged = false,
  });

  List<List<String>> get categories {
    return metadata?.categories ?? const [];
  }

  String get description {
    return metadata?.description ?? '';
  }

  void setMetadata(GroupMetadata value) {
    metadata = value;
    edited = true;
  }
}
