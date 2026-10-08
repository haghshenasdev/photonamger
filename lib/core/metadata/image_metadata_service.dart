import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Sidecar metadata for tags and editable user fields. Keeps original media bytes untouched.
class ImageMetadataService {
  static const suffix = '.archino-image.json';

  static File fileFor(String imagePath) => File('$imagePath$suffix');

  static Future<Map<String, dynamic>> read(String imagePath) async {
    final f = fileFor(imagePath);
    if (!await f.exists()) return <String, dynamic>{'tags': <String>[], 'fields': <String, dynamic>{}};
    try {
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{'tags': <String>[], 'fields': <String, dynamic>{}};
  }

  static Future<void> write(String imagePath, Map<String, dynamic> data) async {
    data['imagePath'] = p.normalize(imagePath);
    data['updatedAt'] = DateTime.now().toIso8601String();
    await fileFor(imagePath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  static Future<List<String>> tags(String imagePath) async {
    final raw = (await read(imagePath))['tags'];
    if (raw is! List) return <String>[];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
  }

  static Future<void> saveTags(String imagePath, List<String> tags) async {
    final data = await read(imagePath);
    data['tags'] = tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    await write(imagePath, data);
  }

  static Future<bool> matchesTags(String imagePath, String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final data = await read(imagePath);
    final tags = data['tags'];
    return tags is List && tags.any((t) => t.toString().toLowerCase().contains(q));
  }
}
