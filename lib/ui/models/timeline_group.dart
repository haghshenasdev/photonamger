import 'group_metadata.dart';
import 'media_item.dart';

class TimelineGroup {
  String title;

  DateTime start;

  DateTime end;

  List<MediaItem> items;

  /// اطلاعات اضافی گروه.
  ///
  /// این اطلاعات در فایل .photonamger.json ذخیره می‌شوند.
  GroupMetadata? metadata;

  /// آیا اطلاعات این گروه توسط کاربر تغییر کرده است؟
  ///
  /// برای تشخیص اینکه نیاز به ذخیره دارد استفاده می‌شود.
  bool edited;

  /// آیا این گروه Merge شده؟
  bool merged;

  TimelineGroup({
    required this.title,
    required this.start,
    required this.end,
    required this.items,
    this.metadata,
    this.edited = false,
    this.merged = false,
  });

  /// دسته‌بندی‌های گروه.
  List<String> get categories {
    return metadata?.categories ?? const <String>[];
  }

  /// توضیحات گروه.
  String get description {
    return metadata?.description ?? '';
  }

  /// تنظیم متادیتای گروه.
  void setMetadata(GroupMetadata value) {
    metadata = value;
    edited = true;
  }
}
