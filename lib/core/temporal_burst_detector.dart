import 'package:fgphoto/core/analysis/analysis_controller.dart';

import '../ui/models/duplicate_group.dart';
import '../ui/models/media_item.dart';

/// تشخیص عکس‌هایی که در فاصله زمانی کوتاه و پشت سر هم گرفته شده‌اند.
///
/// این الگوریتم عمداً هیچ پردازش تصویری انجام نمی‌دهد.
/// بنابراین نسبت به pHash بسیار سریع‌تر است.
///
/// مثال:
///
/// 10:00:00
/// 10:00:04
/// 10:00:08
/// 10:00:17
///
/// چون فاصله هر دو عکس متوالی <= 10 ثانیه است،
/// یک گروه burst ساخته می‌شود.
class TemporalBurstDetector {
  /// حداکثر فاصله بین دو عکس متوالی.
  static const Duration defaultMaxGap = Duration(seconds: 10);

  /// حداقل تعداد عکس برای تشکیل گروه.
  static const int defaultMinGroupSize = 2;

  /// تشخیص گروه‌های عکس پشت‌سرهم.
  Future<List<DuplicateGroup>> findBursts(
    List<MediaItem> items, {
    required AnalysisController controller,
    Duration maxGap = defaultMaxGap,
    int minGroupSize = defaultMinGroupSize,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    if (items.isEmpty) {
      return [];
    }

    final photos = items.where((item) => !item.isVideo).toList(growable: false);

    if (photos.length < minGroupSize) {
      onProgress?.call(
        photos.length,
        photos.length,
        'عکس‌های پشت‌سرهمی پیدا نشد',
      );

      return [];
    }

    // برای اطمینان، یک کپی می‌سازیم تا ترتیب اصلی لیست UI تغییر نکند.
    final sorted = List<MediaItem>.from(photos)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final groups = <DuplicateGroup>[];

    var currentGroup = <MediaItem>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      if (!await controller.checkpoint()) {
        return [];
      }

      final current = sorted[i];
      final previous = sorted[i - 1];

      final diff = current.createdAt.difference(previous.createdAt);

      final progress = i + 1;

      onProgress?.call(
        progress,
        sorted.length,
        'در حال تشخیص عکس‌های پشت‌سرهم '
        '($progress از ${sorted.length})',
      );

      if (diff <= maxGap) {
        // عکس در ادامه burst فعلی قرار دارد.
        currentGroup.add(current);
      } else {
        // burst قبلی تمام شده است.
        _addGroupIfValid(groups, currentGroup, minGroupSize);

        // شروع burst جدید.
        currentGroup = <MediaItem>[current];
      }
    }

    // آخرین گروه.
    _addGroupIfValid(groups, currentGroup, minGroupSize);

    // گروه‌های بزرگ‌تر اول نمایش داده شوند.
    groups.sort((a, b) => b.items.length.compareTo(a.items.length));

    onProgress?.call(
      sorted.length,
      sorted.length,
      'تشخیص عکس‌های پشت‌سرهم پایان یافت',
    );

    return groups;
  }

  void _addGroupIfValid(
    List<DuplicateGroup> groups,
    List<MediaItem> items,
    int minGroupSize,
  ) {
    if (items.length < minGroupSize) {
      return;
    }

    final groupItems = List<MediaItem>.from(items)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    groups.add(DuplicateGroup(items: groupItems, selectedIndex: 0));
  }
}
