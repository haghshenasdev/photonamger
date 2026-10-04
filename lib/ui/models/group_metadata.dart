import 'dart:convert';

class GroupMetadata {
  static const int currentVersion = 3;

  /// هر عنصر یک مسیر کامل دسته‌بندی است.
  ///
  /// مثال:
  ///
  /// [
  ///   ['گرگاب', 'ملاقات'],
  ///   ['تست', 'تستی'],
  ///   ['تهران', 'جلسه', 'مدیران'],
  /// ]
  final List<List<String>> categories;

  final String description;

  /// تاریخ مستقل گروه که برای نام‌گذاری خروجی و جستجوی تاریخی استفاده می‌شود.
  final DateTime? groupDate;

  const GroupMetadata({
    this.version = currentVersion,
    this.categories = const [],
    this.description = '',
    this.groupDate,
  });

  final int version;

  GroupMetadata copyWith({
    int? version,
    List<List<String>>? categories,
    String? description,
    DateTime? groupDate,
  }) {
    return GroupMetadata(
      version: version ?? this.version,
      categories: categories ?? this.categories,
      description: description ?? this.description,
      groupDate: groupDate ?? this.groupDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'categories': categories.map((path) => List<String>.from(path)).toList(),
      'description': description,
      'groupDate': groupDate?.toIso8601String(),
    };
  }

  factory GroupMetadata.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    final categories = <List<String>>[];

    if (rawCategories is List) {
      for (final value in rawCategories) {
        // فرمت جدید:
        //
        // [
        //   ["گرگاب", "ملاقات"],
        //   ["تست", "تستی"]
        // ]
        if (value is List) {
          final path = value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();

          if (path.isNotEmpty) {
            categories.add(path);
          }

          continue;
        }

        // پشتیبانی از فرمت قدیمی:
        //
        // [
        //   "گرگاب",
        //   "ملاقات"
        // ]
        //
        // هر مورد به عنوان یک مسیر تک‌سطحی در نظر گرفته می‌شود.
        if (value is String) {
          final text = value.trim();

          if (text.isNotEmpty) {
            categories.add([text]);
          }
        }
      }
    }

    DateTime? groupDate;
    final rawDate = json['groupDate']?.toString().trim();
    if (rawDate != null && rawDate.isNotEmpty) {
      groupDate = DateTime.tryParse(rawDate);
    }

    return GroupMetadata(
      version: json['version'] is int ? json['version'] as int : currentVersion,
      categories: categories,
      description: json['description']?.toString() ?? '',
      groupDate: groupDate,
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
