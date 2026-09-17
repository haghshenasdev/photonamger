import 'media_item.dart';

class DuplicateGroup {
  final List<MediaItem> items;

  /// عکس منتخب گروه
  int selectedIndex;

  /// تمام عکس‌هایی که کاربر از این گروه انتخاب کرده است.
  ///
  /// selectedIndex همچنان عکس اصلی را مشخص می‌کند،
  /// ولی selectedIndices اجازه انتخاب چند عکس را می‌دهد.
  Set<int> selectedIndices;

  /// امتیاز بهترین عکس
  double bestScore;

  /// آیا این گروه تحلیل شده؟
  bool analyzed;

  DuplicateGroup({
    required this.items,
    this.selectedIndex = 0,
    Set<int>? selectedIndices,
    this.bestScore = 0,
    this.analyzed = false,
  }) : selectedIndices = selectedIndices ?? {selectedIndex};

  MediaItem get primary => items[selectedIndex];

  /// عکس‌های انتخاب‌شده
  List<MediaItem> get selectedItems {
    return selectedIndices
        .where((index) => index >= 0 && index < items.length)
        .map((index) => items[index])
        .toList();
  }

  /// آیا این عکس انتخاب شده؟
  bool isSelected(int index) {
    return selectedIndices.contains(index);
  }

  /// افزودن/حذف عکس از انتخاب‌ها
  void toggleSelection(int index) {
    if (selectedIndices.contains(index)) {
      // اجازه نده همه عکس‌ها از انتخاب خارج شوند.
      if (selectedIndices.length > 1) {
        selectedIndices.remove(index);

        // اگر عکس اصلی حذف شد، یکی دیگر را اصلی کن.
        if (selectedIndex == index) {
          selectedIndex = selectedIndices.first;
        }
      }
    } else {
      selectedIndices.add(index);
    }
  }

  /// انتخاب یک عکس به عنوان عکس اصلی
  void setPrimary(int index) {
    selectedIndex = index;
    selectedIndices.add(index);
  }
}
