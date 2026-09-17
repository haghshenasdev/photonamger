import 'media_item.dart';

class DuplicateGroup {
  final List<MediaItem> items;

  /// عکس اصلی گروه
  int selectedIndex;

  /// تمام عکس‌هایی که کاربر از گروه انتخاب کرده است.
  ///
  /// selectedIndex فقط مشخص می‌کند کدام عکس Primary است.
  /// selectedIndices مشخص می‌کند کدام عکس‌ها باید نگه داشته شوند.
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

  /// عکس اصلی
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

  /// انتخاب / لغو انتخاب یک عکس
  void toggleSelection(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    if (selectedIndices.contains(index)) {
      // اجازه نمی‌دهیم همه عکس‌های گروه از انتخاب خارج شوند.
      if (selectedIndices.length <= 1) {
        return;
      }

      selectedIndices.remove(index);

      // اگر عکس اصلی لغو انتخاب شد،
      // یکی از عکس‌های انتخاب‌شده را اصلی می‌کنیم.
      if (selectedIndex == index) {
        selectedIndex = selectedIndices.first;
      }
    } else {
      selectedIndices.add(index);
    }
  }

  /// انتخاب یک عکس به عنوان عکس اصلی
  ///
  /// عکس اصلی همیشه باید در selectedIndices باشد.
  void setPrimary(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    selectedIndex = index;
    selectedIndices.add(index);
  }

  /// انتخاب فقط یک عکس
  void selectOnly(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }

    selectedIndex = index;

    selectedIndices
      ..clear()
      ..add(index);
  }

  /// بعد از Sort یا تحلیل مجدد
  /// انتخاب‌ها را روی عکس اصلی تنظیم می‌کند.
  void resetSelectionToPrimary() {
    if (items.isEmpty) {
      selectedIndex = 0;
      selectedIndices.clear();
      return;
    }

    if (selectedIndex < 0 || selectedIndex >= items.length) {
      selectedIndex = 0;
    }

    selectedIndices
      ..clear()
      ..add(selectedIndex);
  }
}
