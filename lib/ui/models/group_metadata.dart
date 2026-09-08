import 'dart:convert';

class GroupMetadata {
  static const int currentVersion = 2;

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

  const GroupMetadata({
    this.version = currentVersion,
    this.categories = const [],
    this.description = '',
  });

  final int version;

  GroupMetadata copyWith({
    int? version,
    List<List<String>>? categories,
    String? description,
  }) {
    return GroupMetadata(
      version: version ?? this.version,
      categories: categories ?? this.categories,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'categories': categories.map((path) => List<String>.from(path)).toList(),
      'description': description,
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

    return GroupMetadata(
      version: json['version'] is int ? json['version'] as int : currentVersion,
      categories: categories,
      description: json['description']?.toString() ?? '',
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
