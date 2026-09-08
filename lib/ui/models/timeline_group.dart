import 'group_metadata.dart';
import 'media_item.dart';

class TimelineGroup {
  String title;

  DateTime start;

  DateTime end;

  List<MediaItem> items;

  /// Metadata ذخیره‌شده گروه.
  ///
  /// null یعنی این گروه هنوز metadata ندارد.
  GroupMetadata? metadata;

  /// مسیری که metadata از آن خوانده شده.
  String? metadataDirectory;

  /// آیا کاربر این گروه را ویرایش کرده؟
  bool edited;

  /// آیا این گروه Merge شده؟
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

  /// دسته‌بندی‌های گروه.
  List<String> get categories {
    return metadata?.categories ?? const [];
  }

  /// توضیحات گروه.
  String get description {
    return metadata?.description ?? '';
  }
}
