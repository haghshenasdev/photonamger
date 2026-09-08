import 'dart:convert';

class GroupMetadata {
  static const int currentVersion = 2;

  final int version;

  /// مسیرهای دسته‌بندی انتخاب‌شده.
  ///
  /// مثال:
  ///
  /// [
  ///   ['گرگاب', 'ملاقات'],
  ///   ['تست', 'تستی'],
  /// ]
  final List<List<String>> categories;

  final String description;

  const GroupMetadata({
    this.version = currentVersion,
    this.categories = const [],
    this.description = '',
  });

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
      'categories': categories,
      'description': description,
    };
  }

  factory GroupMetadata.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    final categories = <List<String>>[];

    if (rawCategories is List) {
      for (final rawPath in rawCategories) {
        // فرمت جدید:
        //
        // ["گرگاب", "ملاقات"]
        //
        if (rawPath is List) {
          final path = rawPath
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (path.isNotEmpty) {
            categories.add(path);
          }

          continue;
        }

        // سازگاری با نسخه قبلی:
        //
        // ["سفر", "ایران", "شمال"]
        //
        // هر مقدار را یک مسیر تک‌سطحی در نظر می‌گیریم.
        if (rawPath is String) {
          final value = rawPath.trim();

          if (value.isNotEmpty) {
            categories.add([value]);
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
