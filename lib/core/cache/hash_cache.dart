import 'dart:convert';
import 'dart:io';

class HashCacheEntry {
  final String path;
  final int fileSize;
  final int modified;
  final String hash;

  HashCacheEntry({
    required this.path,
    required this.fileSize,
    required this.modified,
    required this.hash,
  });

  factory HashCacheEntry.fromJson(Map<String, dynamic> json) {
    return HashCacheEntry(
      path: json["path"],
      fileSize: json["fileSize"],
      modified: json["modified"],
      hash: json["hash"],
    );
  }

  Map<String, dynamic> toJson() => {
        "path": path,
        "fileSize": fileSize,
        "modified": modified,
        "hash": hash,
      };
}

class HashCache {
  final Map<String, HashCacheEntry> _items = {};

  late File _file;

  Future<void> open(String folder) async {
    _file = File("$folder/.fgphoto_hash_cache.json");

    if (!await _file.exists()) {
      return;
    }

    try {
      final text = await _file.readAsString();

      final List list = jsonDecode(text);

      for (final e in list) {
        final item = HashCacheEntry.fromJson(e);

        _items[item.path] = item;
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final list = _items.values.map((e) => e.toJson()).toList();

    await _file.writeAsString(jsonEncode(list));
  }

  int? get(
    String path,
    int fileSize,
    int modified,
  ) {
    final item = _items[path];

    if (item == null) {
      return null;
    }

    if (item.fileSize != fileSize) {
      return null;
    }

    if (item.modified != modified) {
      return null;
    }

    return int.parse(item.hash);
  }

  void put(
    String path,
    int fileSize,
    int modified,
    int  hash,
  ) {
    _items[path] = HashCacheEntry(
      path: path,
      fileSize: fileSize,
      modified: modified,
      hash: hash.toString(),
    );
  }
}