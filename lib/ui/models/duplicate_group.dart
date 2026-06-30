import 'media_item.dart';

class DuplicateGroup {
  final List<MediaItem> items;

  /// عکس منتخب گروه
  int selectedIndex;

  /// امتیاز بهترین عکس
  double bestScore;

  /// آیا این گروه تحلیل شده؟
  bool analyzed;

  DuplicateGroup({
    required this.items,
    this.selectedIndex = 0,
    this.bestScore = 0,
    this.analyzed = false,
  });

  MediaItem get primary => items[selectedIndex];
  
}
