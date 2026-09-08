import 'dart:convert';

class GroupMetadata {
  static const int currentVersion = 1;

  final int version;

  /// مسیر دسته‌بندی.
  ///
  /// مثال:
  /// ["سفر", "ایران", "شمال"]
  final List<String> categories;

  /// توضیحات گروه.
  final String description;

  const GroupMetadata({
    this.version = currentVersion,
    this.categories = const [],
    this.description = '',
  });

  GroupMetadata copyWith({
    int? version,
    List<String>? categories,
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

    final categories = <String>[];

    if (rawCategories is List) {
      for (final value in rawCategories) {
        if (value is! String) {
          continue;
        }

        final text = value.trim();

        if (text.isEmpty) {
          continue;
        }

        categories.add(text);
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
