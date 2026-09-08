import 'group_metadata.dart';
import 'media_item.dart';

class TimelineGroup {
  String title;

  DateTime start;

  DateTime end;

  List<MediaItem> items;

  /// اطلاعات ذخیره‌شده گروه.
  GroupMetadata? metadata;

  /// پوشه‌ای که metadata از آن خوانده شده است.
  String? metadataDirectory;

  /// آیا کاربر گروه را تغییر داده؟
  bool edited;

  /// آیا گروه از چند گروه ادغام شده؟
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

  /// مسیرهای دسته‌بندی گروه.
  ///
  /// مثال:
  ///
  /// [
  ///   ['گرگاب', 'ملاقات'],
  ///   ['تست', 'تستی']
  /// ]
  List<List<String>> get categories {
    return metadata?.categories ?? const [];
  }

  String get description {
    return metadata?.description ?? '';
  }
}
