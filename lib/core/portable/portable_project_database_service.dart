import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../ui/models/media_item.dart';
import '../../ui/models/duplicate_group.dart';
import '../analysis/face_database.dart';
import '../metadata/category_learning_service.dart';

/// Portable project database stored at the ROOT of the selected archive disk.
///
/// It contains face identities/embeddings, category paths and the category
/// learning model. The working project remains local; Apply synchronizes this
/// database to the selected archive root.
class PortableProjectDatabaseService {
  static const String fileName = 'archino.sqlite';
  static const int schemaVersion = 2;

  const PortableProjectDatabaseService();

  String pathFor(String root) => p.join(root, fileName);

  Future<bool> exists(String root) => File(pathFor(root)).exists();

  Future<String?> findArchiveRoot(List<String> sourcePaths) async {
    for (final raw in sourcePaths) {
      var current = Directory(p.normalize(p.absolute(raw)));
      while (true) {
        if (await exists(current.path)) return current.path;
        final parent = current.parent;
        if (p.normalize(parent.path) == p.normalize(current.path)) break;
        current = parent;
      }
    }
    return null;
  }

  Future<PortableProjectSnapshot?> load(String root) async {
    final path = pathFor(root);
    if (!await File(path).exists()) return null;

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(path);
      _ensureSchema(db);

      final rows = db.select(
        'SELECT payload FROM face_database WHERE id = 1 LIMIT 1',
      );
      if (rows.isEmpty) return null;

      final raw = jsonDecode(rows.first['payload']?.toString() ?? '{}');
      if (raw is! Map) return null;

      final categoryRows = db.select(
        'SELECT path_json FROM category_paths ORDER BY sort_order, id',
      );
      final paths = <List<String>>[];

      for (final row in categoryRows) {
        try {
          final value = jsonDecode(row['path_json']?.toString() ?? '[]');
          if (value is List) {
            final path = value
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
            if (path.isNotEmpty) paths.add(path);
          }
        } catch (_) {}
      }

      CategoryLearningModel learning = const CategoryLearningModel();
      final learningRows = db.select(
        'SELECT payload FROM category_learning WHERE id = 1 LIMIT 1',
      );

      final analysisFiles = <String>{};
      final analysisRows = db.select(
        'SELECT fingerprint FROM analysis_files',
      );
      for (final row in analysisRows) {
        final fingerprint = row['fingerprint']?.toString().trim() ?? '';
        if (fingerprint.isNotEmpty) analysisFiles.add(fingerprint);
      }

      final duplicateData = <PortableDuplicateGroupData>[];
      final duplicateRows = db.select(
        'SELECT payload FROM analysis_duplicate_groups ORDER BY id',
      );
      for (final row in duplicateRows) {
        try {
          final value = jsonDecode(row['payload']?.toString() ?? '{}');
          if (value is Map) {
            duplicateData.add(
              PortableDuplicateGroupData.fromJson(
                Map<String, dynamic>.from(value),
              ),
            );
          }
        } catch (_) {}
      }

      if (learningRows.isNotEmpty) {
        try {
          final value =
              jsonDecode(learningRows.first['payload']?.toString() ?? '{}');
          if (value is Map) {
            learning = CategoryLearningModel.fromJson(
              Map<String, dynamic>.from(value),
            );
          }
        } catch (_) {}
      }

      return PortableProjectSnapshot(
        database: FaceDatabase.fromJson(Map<String, dynamic>.from(raw)),
        categoryPaths: _uniquePaths(paths),
        learningModel: learning,
        analysisFingerprints: analysisFiles,
        duplicateGroups: duplicateData,
      );
    } catch (_) {
      return null;
    } finally {
      db?.close();
    }
  }

  Future<PortableProjectSnapshot?> importIntoWorkingDatabase({
    required String root,
    required FaceDatabase workingDatabase,
    required String workingDatabaseDirectory,
    List<List<String>> currentCategoryPaths = const [],
    CategoryLearningModel currentLearningModel =
        const CategoryLearningModel(),
  }) async {
    final snapshot = await load(root);
    if (snapshot == null) return null;

    _mergeFaceDatabases(workingDatabase, snapshot.database);

    final mergedPaths = _uniquePaths([
      ...currentCategoryPaths,
      ...snapshot.categoryPaths,
    ]);

    await const FaceDatabaseService().save(
      workingDatabaseDirectory,
      workingDatabase,
    );

    return PortableProjectSnapshot(
      database: workingDatabase,
      categoryPaths: mergedPaths,
      learningModel: _mergeLearningModels(
        currentLearningModel,
        snapshot.learningModel,
      ),
      analysisFingerprints: snapshot.analysisFingerprints,
      duplicateGroups: snapshot.duplicateGroups,
    );
  }

  Future<void> syncToRoot({
    required String root,
    required FaceDatabase workingDatabase,
    required List<MediaItem> transferredItems,
    required List<List<String>> categoryPaths,
    required CategoryLearningModel learningModel,
    List<DuplicateGroup> duplicateGroups = const [],
    List<MediaItem> analyzedItems = const [],
  }) async {
    final directory = Directory(root);
    await directory.create(recursive: true);

    final existing = await load(root);

    final merged = FaceDatabase(
      persons: [],
      faces: [],
      scans: [],
      rejections: [],
    );

    if (existing != null) {
      _mergeFaceDatabases(merged, existing.database);
    }
    _mergeFaceDatabases(merged, workingDatabase);

    final transferredByFingerprint = <String, MediaItem>{};

    for (final item in transferredItems) {
      if (item.isVideo) continue;
      final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);
      if (fingerprint != 'missing') {
        transferredByFingerprint[fingerprint] = item;
      }
    }

    final rootKey = FaceDatabaseService.normalizeRootKey(root);

    for (final face in merged.faces) {
      final item = transferredByFingerprint[face.fingerprint];
      if (item == null) continue;
      face.rootKey = rootKey;
      face.relativePath = _relative(root, item.path);
    }

    for (final scan in merged.scans) {
      final item = transferredByFingerprint[scan.fingerprint];
      if (item == null) continue;
      scan.rootKey = rootKey;
      scan.relativePath = _relative(root, item.path);
    }

    for (final person in merged.persons) {
      final itemPath = _coverPathForPerson(
        merged,
        person.id,
        transferredByFingerprint,
      );
      if (itemPath != null) {
        person.coverRootKey = rootKey;
        person.coverRelativePath = _relative(root, itemPath);
        person.updatedAt = DateTime.now();
      }
    }

    final mergedCategories = _uniquePaths([
      ...(existing?.categoryPaths ?? const []),
      ...categoryPaths,
      ..._categoryPathsFromLearning(learningModel),
    ]);

    final mergedLearning = _mergeLearningModels(
      existing?.learningModel ?? const CategoryLearningModel(),
      learningModel,
    );

    final mergedAnalysisFingerprints = <String>{
      ...(existing?.analysisFingerprints ?? const <String>{}),
      ...await _fingerprintsForItems(analyzedItems),
    };

    final mergedDuplicateGroups = _mergeDuplicateGroups(
      existing?.duplicateGroups ?? const <PortableDuplicateGroupData>[],
      await _serializeDuplicateGroups(duplicateGroups),
    );

    await _writeSqlite(
      root: root,
      database: merged,
      categoryPaths: mergedCategories,
      learningModel: mergedLearning,
      analysisFingerprints: mergedAnalysisFingerprints,
      duplicateGroups: mergedDuplicateGroups,
    );
  }

  Future<void> _writeSqlite({
    required String root,
    required FaceDatabase database,
    required List<List<String>> categoryPaths,
    required CategoryLearningModel learningModel,
    required Set<String> analysisFingerprints,
    required List<PortableDuplicateGroupData> duplicateGroups,
  }) async {
    final target = pathFor(root);
    final temp = '$target.tmp';

    if (await File(temp).exists()) await File(temp).delete();

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(temp);
      _ensureSchema(db);

      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'INSERT OR REPLACE INTO face_database(id, payload) VALUES(1, ?)',
          [jsonEncode(database.toJson())],
        );

        db.execute('DELETE FROM category_paths');

        final insert = db.prepare(
          'INSERT INTO category_paths(path_json, path_key, sort_order) '
          'VALUES(?, ?, ?)',
        );

        try {
          var order = 0;
          for (final path in _uniquePaths(categoryPaths)) {
            insert.execute([
              jsonEncode(path),
              _pathKey(path),
              order++,
            ]);
          }
        } finally {
          insert.close();
        }

        db.execute(
          'INSERT OR REPLACE INTO category_learning(id, payload) VALUES(1, ?)',
          [learningModel.toPrettyJson()],
        );

        db.execute('DELETE FROM analysis_files');
        final analysisInsert = db.prepare(
          'INSERT OR IGNORE INTO analysis_files(fingerprint) VALUES(?)',
        );
        try {
          for (final fingerprint in analysisFingerprints) {
            if (fingerprint.trim().isNotEmpty) {
              analysisInsert.execute([fingerprint]);
            }
          }
        } finally {
          analysisInsert.close();
        }

        db.execute('DELETE FROM analysis_duplicate_groups');
        final duplicateInsert = db.prepare(
          'INSERT INTO analysis_duplicate_groups(payload) VALUES(?)',
        );
        try {
          for (final group in duplicateGroups) {
            duplicateInsert.execute([jsonEncode(group.toJson())]);
          }
        } finally {
          duplicateInsert.close();
        }
        db.execute(
          'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)',
          ['schema_version', '$schemaVersion'],
        );
        db.execute(
          'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)',
          ['updated_at', DateTime.now().toIso8601String()],
        );

        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db?.close();
    }

    final targetFile = File(target);
    final tempFile = File(temp);

    if (await targetFile.exists()) {
      final backup = File('$target.bak');
      if (await backup.exists()) await backup.delete();
      await targetFile.rename(backup.path);

      try {
        await tempFile.rename(target);
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await targetFile.exists()) await targetFile.delete();
        if (await backup.exists()) await backup.rename(target);
        rethrow;
      }
    } else {
      await tempFile.rename(target);
    }
  }

  void _ensureSchema(sqlite.Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS face_database (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS category_paths (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path_json TEXT NOT NULL,
        path_key TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS category_learning (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload TEXT NOT NULL
      )
    ''');


    db.execute('''
      CREATE TABLE IF NOT EXISTS analysis_files (
        fingerprint TEXT PRIMARY KEY
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS analysis_duplicate_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL
      )
    ''');
  }

  Future<Set<String>> _fingerprintsForItems(List<MediaItem> items) async {
    final result = <String>{};
    for (final item in items) {
      if (item.isVideo) continue;
      final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);
      if (fingerprint != 'missing') result.add(fingerprint);
    }
    return result;
  }

  Future<List<PortableDuplicateGroupData>> _serializeDuplicateGroups(
    List<DuplicateGroup> groups,
  ) async {
    final result = <PortableDuplicateGroupData>[];
    for (final group in groups) {
      if (group.items.length < 2) continue;
      final fingerprints = <String>[];
      for (final item in group.items) {
        if (item.isVideo) continue;
        final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);
        if (fingerprint != 'missing') fingerprints.add(fingerprint);
      }
      if (fingerprints.length < 2) continue;

      final selectedFingerprints = <String>[];
      for (final index in group.selectedIndices) {
        if (index < 0 || index >= group.items.length) continue;
        final fingerprint = await FaceDatabaseService.fingerprintOf(
          group.items[index].path,
        );
        if (fingerprint != 'missing') selectedFingerprints.add(fingerprint);
      }

      String? primaryFingerprint;
      if (group.selectedIndex >= 0 && group.selectedIndex < group.items.length) {
        final fingerprint = await FaceDatabaseService.fingerprintOf(
          group.items[group.selectedIndex].path,
        );
        if (fingerprint != 'missing') primaryFingerprint = fingerprint;
      }

      result.add(
        PortableDuplicateGroupData(
          fingerprints: fingerprints,
          primaryFingerprint: primaryFingerprint,
          selectedFingerprints: selectedFingerprints,
          bestScore: group.bestScore,
          analyzed: true,
        ),
      );
    }
    return result;
  }

  List<PortableDuplicateGroupData> _mergeDuplicateGroups(
    List<PortableDuplicateGroupData> existing,
    List<PortableDuplicateGroupData> incoming,
  ) {
    final map = <String, PortableDuplicateGroupData>{};
    for (final group in [...existing, ...incoming]) {
      final key = group.fingerprints.toSet().toList()..sort();
      final id = key.join('|');
      if (id.isEmpty) continue;
      map[id] = group;
    }
    return map.values.toList();
  }

  Future<Set<String>> bindAnalysisPaths({
    required PortableProjectSnapshot snapshot,
    required List<MediaItem> items,
  }) async {
    if (snapshot.analysisFingerprints.isEmpty) return <String>{};
    final result = <String>{};
    for (final item in items) {
      if (item.isVideo) continue;
      final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);
      if (snapshot.analysisFingerprints.contains(fingerprint)) {
        result.add(_filePathKey(item.path));
      }
    }
    return result;
  }

  Future<List<DuplicateGroup>> bindDuplicateGroups({
    required PortableProjectSnapshot snapshot,
    required List<MediaItem> items,
  }) async {
    final byFingerprint = <String, MediaItem>{};
    for (final item in items) {
      if (item.isVideo) continue;
      final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);
      if (fingerprint != 'missing') byFingerprint[fingerprint] = item;
    }

    final result = <DuplicateGroup>[];
    for (final cached in snapshot.duplicateGroups) {
      final matched = <MediaItem>[];
      for (final fingerprint in cached.fingerprints) {
        final item = byFingerprint[fingerprint];
        if (item != null) matched.add(item);
      }
      if (matched.length < 2) continue;

      final primary = cached.primaryFingerprint == null
          ? 0
          : matched.indexWhere((item) =>
              byFingerprint[cached.primaryFingerprint!] == item,
            );
      final selected = <int>{};
      for (var i = 0; i < matched.length; i++) {
        final fp = await FaceDatabaseService.fingerprintOf(matched[i].path);
        if (cached.selectedFingerprints.contains(fp)) selected.add(i);
      }

      var selectedIndex = primary >= 0 ? primary : 0;
      if (selected.isEmpty) selected.add(selectedIndex);
      if (!selected.contains(selectedIndex)) selected.add(selectedIndex);

      result.add(
        DuplicateGroup(
          items: matched,
          selectedIndex: selectedIndex,
          selectedIndices: selected,
          bestScore: cached.bestScore,
          analyzed: cached.analyzed,
        ),
      );
    }
    return result;
  }

  void _mergeFaceDatabases(FaceDatabase target, FaceDatabase incoming) {
    final persons = <String, FacePerson>{
      for (final person in target.persons)
        if (person.id.trim().isNotEmpty) person.id: person,
    };

    for (final imported in incoming.persons) {
      final id = imported.id.trim();
      if (id.isEmpty) continue;

      final existing = persons[id];
      if (existing == null) {
        final copied = FacePerson.fromJson(imported.toJson());
        target.persons.add(copied);
        persons[id] = copied;
        continue;
      }

      final importedName = imported.name.trim();
      final existingName = existing.name.trim();
      final importedReal =
          importedName.isNotEmpty && !_isGenericName(importedName);
      final existingGeneric =
          existingName.isEmpty || _isGenericName(existingName);

      if (importedReal &&
          (existingGeneric || imported.updatedAt.isAfter(existing.updatedAt))) {
        existing.name = importedName;
      }

      if (imported.updatedAt.isAfter(existing.updatedAt)) {
        existing.updatedAt = imported.updatedAt;
      }

      if (existing.coverRelativePath == null &&
          imported.coverRelativePath != null) {
        existing.coverRootKey = imported.coverRootKey;
        existing.coverRelativePath = imported.coverRelativePath;
      }
    }

    final faces = <String, StoredFace>{
      for (final face in target.faces)
        if (face.fingerprint.trim().isNotEmpty)
          '${face.fingerprint}|${face.personId}': face,
    };

    for (final imported in incoming.faces) {
      final key = '${imported.fingerprint}|${imported.personId}';
      final existing = faces[key];

      if (existing == null) {
        final copied = StoredFace.fromJson(imported.toJson());
        target.faces.add(copied);
        faces[key] = copied;
      } else if (existing.embedding.length < imported.embedding.length) {
        existing.embedding = List<double>.from(imported.embedding);
      }
    }

    final scans = <String, FaceScan>{
      for (final scan in target.scans)
        if (scan.fingerprint.trim().isNotEmpty) scan.fingerprint: scan,
    };

    for (final imported in incoming.scans) {
      if (imported.fingerprint.trim().isEmpty) continue;
      if (!scans.containsKey(imported.fingerprint)) {
        final copied = FaceScan.fromJson(imported.toJson());
        target.scans.add(copied);
        scans[copied.fingerprint] = copied;
      }
    }

    final rejections = <String, FaceRejection>{
      for (final rejection in target.rejections) rejection.key: rejection,
    };

    for (final imported in incoming.rejections) {
      if (!rejections.containsKey(imported.key)) {
        final copied = FaceRejection.fromJson(imported.toJson());
        target.rejections.add(copied);
        rejections[copied.key] = copied;
      }
    }
  }

  CategoryLearningModel _mergeLearningModels(
    CategoryLearningModel a,
    CategoryLearningModel b,
  ) {
    final jsonRules = <String, Map<String, dynamic>>{};

    for (final model in [a, b]) {
      final raw = model.toJson()['rules'];
      if (raw is! List) continue;

      for (final value in raw) {
        if (value is! Map) continue;
        final rule = Map<String, dynamic>.from(value);
        final path = _stringList(rule['path']);
        if (path.isEmpty) continue;

        final key = _pathKey(path);
        final existing = jsonRules[key];

        if (existing == null) {
          jsonRules[key] = rule;
          continue;
        }

        final oldTokens = <String, int>{};
        final newTokens = <String, int>{};

        if (existing['tokens'] is Map) {
          for (final e in (existing['tokens'] as Map).entries) {
            oldTokens[e.key.toString()] =
                int.tryParse(e.value.toString()) ?? 0;
          }
        }
        if (rule['tokens'] is Map) {
          for (final e in (rule['tokens'] as Map).entries) {
            newTokens[e.key.toString()] =
                int.tryParse(e.value.toString()) ?? 0;
          }
        }

        final mergedTokens = <String, int>{...oldTokens};
        for (final entry in newTokens.entries) {
          mergedTokens[entry.key] =
              (mergedTokens[entry.key] ?? 0) + entry.value;
        }

        existing['tokens'] = mergedTokens;
        existing['samples'] =
            (int.tryParse(existing['samples']?.toString() ?? '') ?? 0) +
                (int.tryParse(rule['samples']?.toString() ?? '') ?? 0);
      }
    }

    final sorted = jsonRules.values.toList()
      ..sort(
        (x, y) => _pathKey(_stringList(x['path']))
            .compareTo(_pathKey(_stringList(y['path']))),
      );

    return CategoryLearningModel.fromJson({
      'format': 'archino-category-rules',
      'version': CategoryLearningModel.currentVersion,
      'rules': sorted,
    });
  }

  List<List<String>> _categoryPathsFromLearning(
    CategoryLearningModel model,
  ) {
    final raw = model.toJson()['rules'];
    if (raw is! List) return const [];

    return [
      for (final value in raw)
        if (value is Map) _stringList(value['path']),
    ];
  }

  String? _coverPathForPerson(
    FaceDatabase db,
    String personId,
    Map<String, MediaItem> transferred,
  ) {
    StoredFace? best;

    for (final face in db.faces) {
      if (face.personId != personId) continue;
      if (best == null || _score(face) > _score(best)) best = face;
    }

    if (best == null) return null;
    return transferred[best.fingerprint]?.path;
  }

  double _score(StoredFace face) {
    final size = (face.width * face.height).clamp(1.0, double.infinity);
    return face.confidence * 0.65 + (math.sqrt(size) / 180.0).clamp(0.0, 1.0) * 0.35;
  }

  static bool _isGenericName(String value) {
    final name = value.trim();
    if (name.isEmpty || name == 'شخص') return true;
    return RegExp(r'^شخص\s+\d+$').hasMatch(name);
  }

  static List<List<String>> _uniquePaths(Iterable<List<String>> paths) {
    final result = <String, List<String>>{};

    for (final raw in paths) {
      final path = raw
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (path.isEmpty) continue;
      result.putIfAbsent(_pathKey(path), () => path);
    }

    return result.values.toList();
  }

  static String _pathKey(List<String> path) => path
      .map(
        (e) => e
            .trim()
            .toLowerCase()
            .replaceAll('ي', 'ی')
            .replaceAll('ى', 'ی')
            .replaceAll('ك', 'ک')
            .replaceAll(RegExp(r'\s+'), ' '),
      )
      .join('\u0000');

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _filePathKey(String path) => p.normalize(path).replaceAll('\\', '/').toLowerCase();

  String _relative(String root, String path) {
    return p
        .relative(p.normalize(path), from: p.normalize(root))
        .replaceAll('\\', '/');
  }
}

class PortableProjectSnapshot {
  final FaceDatabase database;
  final List<List<String>> categoryPaths;
  final CategoryLearningModel learningModel;
  final Set<String> analysisFingerprints;
  final List<PortableDuplicateGroupData> duplicateGroups;

  const PortableProjectSnapshot({
    required this.database,
    required this.categoryPaths,
    required this.learningModel,
    this.analysisFingerprints = const <String>{},
    this.duplicateGroups = const <PortableDuplicateGroupData>[],
  });
}

class PortableDuplicateGroupData {
  final List<String> fingerprints;
  final String? primaryFingerprint;
  final List<String> selectedFingerprints;
  final double bestScore;
  final bool analyzed;

  const PortableDuplicateGroupData({
    required this.fingerprints,
    required this.primaryFingerprint,
    required this.selectedFingerprints,
    required this.bestScore,
    required this.analyzed,
  });

  Map<String, dynamic> toJson() => {
        'fingerprints': fingerprints,
        'primaryFingerprint': primaryFingerprint,
        'selectedFingerprints': selectedFingerprints,
        'bestScore': bestScore,
        'analyzed': analyzed,
      };

  factory PortableDuplicateGroupData.fromJson(Map<String, dynamic> json) {
    return PortableDuplicateGroupData(
      fingerprints: _list(json['fingerprints']),
      primaryFingerprint: json['primaryFingerprint']?.toString(),
      selectedFingerprints: _list(json['selectedFingerprints']),
      bestScore: double.tryParse('${json['bestScore']}') ?? 0,
      analyzed: json['analyzed'] == true,
    );
  }

  static List<String> _list(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
}
