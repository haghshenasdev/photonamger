import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../ui/models/timeline_group.dart';

class CategorySuggestion {
  final List<String> path;
  final double score;
  final int matchedWords;

  const CategorySuggestion({
    required this.path,
    required this.score,
    required this.matchedWords,
  });
}

class CategoryLearningModel {
  static const int currentVersion = 1;

  final List<_CategoryRule> rules;

  const CategoryLearningModel({
    this.rules = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'format': 'archino-category-rules',
      'version': currentVersion,
      'rules': rules.map((e) => e.toJson()).toList(),
    };
  }

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  factory CategoryLearningModel.fromJson(Map<String, dynamic> json) {
    final rules = <_CategoryRule>[];
    final raw = json['rules'];

    if (raw is List) {
      for (final value in raw) {
        if (value is Map) {
          final rule = _CategoryRule.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (rule.path.isNotEmpty && rule.tokens.isNotEmpty) {
            rules.add(rule);
          }
        }
      }
    }

    return CategoryLearningModel(rules: rules);
  }
}

class _CategoryRule {
  final List<String> path;
  final Map<String, int> tokens;
  final int samples;

  const _CategoryRule({
    required this.path,
    required this.tokens,
    required this.samples,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'tokens': tokens,
      'samples': samples,
    };
  }

  factory _CategoryRule.fromJson(Map<String, dynamic> json) {
    final tokens = <String, int>{};
    final rawTokens = json['tokens'];

    if (rawTokens is Map) {
      for (final entry in rawTokens.entries) {
        final key = entry.key.toString().trim();
        final value = int.tryParse(entry.value.toString()) ?? 0;

        if (key.isNotEmpty && value > 0) {
          tokens[key] = value;
        }
      }
    }

    return _CategoryRule(
      path: _stringList(json['path']),
      tokens: tokens,
      samples: math.max(
        1,
        int.tryParse(json['samples']?.toString() ?? '') ?? 1,
      ),
    );
  }
}

class CategoryLearningService {
  static const String fileName = '.archino_category_rules.json';

  const CategoryLearningService();

  Future<CategoryLearningModel> load(String directory) async {
    final file = File(
      Directory(directory).uri.resolve(fileName).toFilePath(),
    );

    if (!await file.exists()) {
      return const CategoryLearningModel();
    }

    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);

      if (decoded is Map) {
        return CategoryLearningModel.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}

    return const CategoryLearningModel();
  }

  Future<void> save(
    String directory,
    CategoryLearningModel model,
  ) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(
      Directory(directory).uri.resolve(fileName).toFilePath(),
    );

    final temp = File('${file.path}.tmp');

    await temp.writeAsString(
      model.toPrettyJson(),
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await temp.rename(file.path);
  }


  CategoryLearningModel merge(
    CategoryLearningModel first,
    CategoryLearningModel second,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final model in [first, second]) {
      final raw = model.toJson()['rules'];
      if (raw is! List) continue;

      for (final value in raw) {
        if (value is! Map) continue;
        final rule = Map<String, dynamic>.from(value);
        final path = _stringList(rule['path']);
        if (path.isEmpty) continue;

        final key = _pathKey(path);
        final existing = merged[key];
        if (existing == null) {
          merged[key] = rule;
          continue;
        }

        final tokens = <String, int>{};
        for (final source in [existing['tokens'], rule['tokens']]) {
          if (source is! Map) continue;
          for (final entry in source.entries) {
            final token = entry.key.toString();
            tokens[token] =
                (tokens[token] ?? 0) + (int.tryParse(entry.value.toString()) ?? 0);
          }
        }

        existing['tokens'] = tokens;
        existing['samples'] =
            (int.tryParse(existing['samples']?.toString() ?? '') ?? 0) +
            (int.tryParse(rule['samples']?.toString() ?? '') ?? 0);
      }
    }

    return CategoryLearningModel.fromJson({
      'format': 'archino-category-rules',
      'version': CategoryLearningModel.currentVersion,
      'rules': merged.values.toList(),
    });
  }

  CategoryLearningModel rebuild(List<TimelineGroup> groups) {
    final byPath = <String, _MutableRule>{};

    for (final group in groups) {
      final title = group.title.trim();

      if (title.isEmpty || group.categories.isEmpty) {
        continue;
      }

      final words = _tokens(title);
      if (words.isEmpty) {
        continue;
      }

      for (final rawPath in group.categories) {
        final path = rawPath
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (path.isEmpty) continue;

        final key = _pathKey(path);
        final rule = byPath.putIfAbsent(
          key,
          () => _MutableRule(path),
        );

        rule.samples++;

        for (final word in words) {
          rule.tokens[word] = (rule.tokens[word] ?? 0) + 1;
        }
      }
    }

    final rules = byPath.values
        .map(
          (rule) => _CategoryRule(
            path: rule.path,
            tokens: Map<String, int>.from(rule.tokens),
            samples: rule.samples,
          ),
        )
        .toList();

    rules.sort((a, b) {
      final pathA = a.path.join(' > ');
      final pathB = b.path.join(' > ');
      return pathA.compareTo(pathB);
    });

    return CategoryLearningModel(rules: rules);
  }

  List<CategorySuggestion> suggest(
    CategoryLearningModel model,
    String title, {
    int top = 3,
  }) {
    final words = _tokens(title);
    if (words.isEmpty || model.rules.isEmpty) {
      return const [];
    }

    final uniqueWords = words.toSet();
    final suggestions = <CategorySuggestion>[];

    for (final rule in model.rules) {
      var weighted = 0.0;
      var matched = 0;

      for (final word in uniqueWords) {
        final count = rule.tokens[word] ?? 0;
        if (count <= 0) continue;

        matched++;
        weighted += 1.0 + math.log(count + 1);
      }

      if (matched == 0) continue;

      // Normalize by rule vocabulary size so a very broad rule does not
      // automatically win just because it has many learned words.
      final denominator =
          math.sqrt(math.max(1, rule.tokens.length));

      final score = weighted / denominator;

      if (score >= 0.45) {
        suggestions.add(
          CategorySuggestion(
            path: List<String>.from(rule.path),
            score: score,
            matchedWords: matched,
          ),
        );
      }
    }

    suggestions.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;

      final matched = b.matchedWords.compareTo(a.matchedWords);
      if (matched != 0) return matched;

      return a.path.join(' > ').compareTo(
            b.path.join(' > '),
          );
    });

    final unique = <String, CategorySuggestion>{};

    for (final suggestion in suggestions) {
      unique.putIfAbsent(
        _pathKey(suggestion.path),
        () => suggestion,
      );
    }

    return unique.values.take(top).toList();
  }

  List<String> _tokens(String text) {
    var normalized = text
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .toLowerCase();

    normalized = normalized.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s]', unicode: true),
      ' ',
    );

    final stopWords = <String>{
      'از',
      'به',
      'در',
      'با',
      'برای',
      'که',
      'و',
      'یا',
      'تا',
      'اما',
      'اگر',
      'این',
      'آن',
      'را',
      'است',
      'بود',
      'شود',
      'کرد',
      'کردن',
      'نیز',
      'هم',
      'بر',
      'بین',
      'یک',
      'هیچ',
      'همه',
      'هر',
      'چند',
      'چه',
      'کجا',
      'کی',
      'ما',
      'شما',
      'او',
      'ایشان',
      'خود',
      'همین',
      'اکنون',
      'امروز',
      'فردا',
      'دیروز',
    };

    return normalized
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where(
          (e) =>
              e.length >= 3 &&
              !stopWords.contains(e) &&
              !RegExp(r'^\d+$').hasMatch(e),
        )
        .toList();
  }

  String _pathKey(List<String> path) =>
      path.map(_normalizePart).join('\u0000');

  String _normalizePart(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class _MutableRule {
  final List<String> path;
  final Map<String, int> tokens = <String, int>{};
  int samples = 0;

  _MutableRule(this.path);
}
