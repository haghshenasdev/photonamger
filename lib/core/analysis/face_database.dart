import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../ui/models/media_item.dart';
import 'face_info.dart';

class FacePerson {
  String id;
  String name;
  String? coverRootKey;
  String? coverRelativePath;
  DateTime createdAt;
  DateTime updatedAt;

  FacePerson({
    required this.id,
    required this.name,
    this.coverRootKey,
    this.coverRelativePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coverRootKey': coverRootKey,
    'coverRelativePath': coverRelativePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FacePerson.fromJson(Map<String, dynamic> json) {
    return FacePerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'شخص',
      coverRootKey: json['coverRootKey']?.toString(),
      coverRelativePath: json['coverRelativePath']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class StoredFace {
  String id;
  String personId;
  String rootKey;
  String relativePath;
  String fingerprint;
  double left;
  double top;
  double width;
  double height;
  double confidence;
  List<double> landmarks;
  List<double> embedding;

  StoredFace({
    required this.id,
    required this.personId,
    required this.rootKey,
    required this.relativePath,
    required this.fingerprint,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    required this.landmarks,
    required this.embedding,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'personId': personId,
    'rootKey': rootKey,
    'relativePath': relativePath,
    'fingerprint': fingerprint,
    'box': [left, top, width, height],
    'confidence': confidence,
    'landmarks': landmarks,
    // Float32 base64 keeps the portable JSON much smaller than 128
    // decimal numbers per face.
    'embedding': base64UrlEncode(
      Float32List.fromList(embedding).buffer.asUint8List(),
    ),
  };

  factory StoredFace.fromJson(Map<String, dynamic> json) {
    final box = json['box'] is List
        ? (json['box'] as List).map((e) => double.tryParse('$e') ?? 0).toList()
        : const <double>[];

    final landmarks = json['landmarks'] is List
        ? (json['landmarks'] as List)
              .map((e) => double.tryParse('$e') ?? 0)
              .toList()
        : <double>[];

    List<double> embedding;
    final rawEmbedding = json['embedding'];
    if (rawEmbedding is String && rawEmbedding.isNotEmpty) {
      try {
        final bytes = base64Url.decode(rawEmbedding);
        final floats = Float32List.view(Uint8List.fromList(bytes).buffer);
        embedding = floats.map((e) => e.toDouble()).toList();
      } catch (_) {
        embedding = <double>[];
      }
    } else if (rawEmbedding is List) {
      // Backward compatibility with the first JSON format.
      embedding = rawEmbedding.map((e) => double.tryParse('$e') ?? 0).toList();
    } else {
      embedding = <double>[];
    }

    return StoredFace(
      id: json['id']?.toString() ?? '',
      personId: json['personId']?.toString() ?? '',
      rootKey: json['rootKey']?.toString() ?? '',
      relativePath: json['relativePath']?.toString() ?? '',
      fingerprint: json['fingerprint']?.toString() ?? '',
      left: box.length > 0 ? box[0] : 0,
      top: box.length > 1 ? box[1] : 0,
      width: box.length > 2 ? box[2] : 0,
      height: box.length > 3 ? box[3] : 0,
      confidence: double.tryParse('${json['confidence']}') ?? 0,
      landmarks: landmarks,
      embedding: embedding,
    );
  }
}

/// Portable face database.
///
/// The database intentionally stores paths relative to a source root, not
/// absolute file paths. The database can therefore move together with the
/// project/source folder.
class FaceScan {
  String rootKey;
  String relativePath;
  String fingerprint;

  FaceScan({
    required this.rootKey,
    required this.relativePath,
    required this.fingerprint,
  });

  Map<String, dynamic> toJson() => {
    'rootKey': rootKey,
    'relativePath': relativePath,
    'fingerprint': fingerprint,
  };

  factory FaceScan.fromJson(Map<String, dynamic> json) => FaceScan(
    rootKey: json['rootKey']?.toString() ?? '',
    relativePath: json['relativePath']?.toString() ?? '',
    fingerprint: json['fingerprint']?.toString() ?? '',
  );
}

class FaceDatabase {
  int version = 1;
  List<FacePerson> persons;
  List<StoredFace> faces;
  List<FaceScan> scans;

  FaceDatabase({
    List<FacePerson>? persons,
    List<StoredFace>? faces,
    List<FaceScan>? scans,
  }) : persons = persons ?? <FacePerson>[],
       faces = faces ?? <StoredFace>[],
       scans = scans ?? <FaceScan>[];

  Map<String, dynamic> toJson() => {
    'version': version,
    'persons': persons.map((e) => e.toJson()).toList(),
    'faces': faces.map((e) => e.toJson()).toList(),
    'scans': scans.map((e) => e.toJson()).toList(),
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory FaceDatabase.fromJson(Map<String, dynamic> json) {
    final persons = <FacePerson>[];
    final rawPersons = json['persons'];
    if (rawPersons is List) {
      for (final raw in rawPersons) {
        if (raw is Map) {
          persons.add(FacePerson.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final scans = <FaceScan>[];
    final rawScans = json['scans'];
    if (rawScans is List) {
      for (final raw in rawScans) {
        if (raw is Map) {
          scans.add(FaceScan.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    final faces = <StoredFace>[];
    final rawFaces = json['faces'];
    if (rawFaces is List) {
      for (final raw in rawFaces) {
        if (raw is Map) {
          faces.add(StoredFace.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    return FaceDatabase(persons: persons, faces: faces, scans: scans)
      ..version = int.tryParse('${json['version']}') ?? 1;
  }
}

class FaceMatchResult {
  final FacePerson person;
  final double similarity;

  const FaceMatchResult({
    required this.person,
    required this.similarity,
  });
}

class FaceDatabaseService {
  static const fileName = '.archino_faces.json';
  // SFace cosine similarity. We combine the person's prototype with a
  // small set of real historical face embeddings. This is more tolerant
  // of glasses, beard, age and pose changes than comparing only the mean.
  static const recognitionThreshold = 0.50;
  static const exemplarThreshold = 0.56;
  static const maxExemplarsPerPerson = 8;

  const FaceDatabaseService();

  File fileFor(String baseDirectory) => File(p.join(baseDirectory, fileName));

  Future<FaceDatabase> load(String baseDirectory) async {
    final file = fileFor(baseDirectory);
    if (!await file.exists()) return FaceDatabase();

    final candidates = <File>[
      if (await file.exists()) file,
      File('${file.path}.bak'),
      File('${file.path}.tmp'),
    ];

    for (final candidate in candidates) {
      if (!await candidate.exists()) continue;
      try {
        final text = await candidate.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return FaceDatabase.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Try the next recovery candidate.
      }
    }

    return FaceDatabase();
  }

  Future<void> save(String baseDirectory, FaceDatabase database) async {
    final directory = Directory(baseDirectory);
    await directory.create(recursive: true);

    final file = fileFor(baseDirectory);
    final temp = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');

    await temp.writeAsString(
      database.toPrettyJson(),
      encoding: utf8,
      flush: true,
    );

    await file.parent.create(recursive: true);

    if (await backup.exists()) {
      await backup.delete();
    }

    if (await file.exists()) {
      await file.rename(backup.path);
    }

    try {
      await temp.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      if (await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  /// Applies cached faces to scanned MediaItems.
  /// Returns the set of items that still need face inference.
  Future<List<MediaItem>> applyCachedFaces({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required List<MediaItem> items,
    bool forceRescan = false,
  }) async {
    final db = await load(databaseDirectory);

    var databaseChanged = false;

    final pending = <MediaItem>[];

    // ------------------------------------------------------------
    // Exact lookup
    //
    // root + relativePath + fingerprint
    // ------------------------------------------------------------
    final byKey = <String, List<StoredFace>>{};

    // ------------------------------------------------------------
    // Portable lookup
    //
    // filename + fingerprint
    //
    // این lookup برای زمانی است که:
    // - پوشه جابه‌جا شده
    // - Root تغییر کرده
    // - مسیر نسبی تغییر کرده
    // ------------------------------------------------------------
    final byPortableKey = <String, List<StoredFace>>{};

    for (final face in db.faces) {
      final exactKey =
          '${face.rootKey}|'
          '${_normRelative(face.relativePath)}|'
          '${face.fingerprint}';

      byKey.putIfAbsent(exactKey, () => []).add(face);

      final fileName = p.basename(_normRelative(face.relativePath));

      final portableKey = '$fileName|${face.fingerprint}';

      byPortableKey.putIfAbsent(portableKey, () => []).add(face);
    }

    // ------------------------------------------------------------
    // Process current media
    // ------------------------------------------------------------
    for (final item in items) {
      item.faces = [];

      // Videoها را فعلاً وارد Face Recognition نمی‌کنیم.
      if (item.isVideo) {
        continue;
      }

      // وقتی کاربر مستقیماً «تشخیص چهره» را می‌زند، حتی فایل‌هایی که
      // قبلاً در cache هستند باید دوباره از مدل عبور کنند.
      if (forceRescan) {
        pending.add(item);
        continue;
      }

      final location = _locate(item.path, sourceRoots);

      if (location == null) {
        pending.add(item);
        continue;
      }

      final fingerprint = await fingerprintOf(item.path);

      final normalizedRelative = _normRelative(location.relativePath);

      final exactKey =
          '${location.rootKey}|'
          '$normalizedRelative|'
          '$fingerprint';

      List<StoredFace>? cached = byKey[exactKey];

      // ==========================================================
      // Exact match پیدا نشد.
      //
      // حالا filename + fingerprint را امتحان می‌کنیم.
      // ==========================================================
      if (cached == null || cached.isEmpty) {
        final portableKey = '${p.basename(normalizedRelative)}|$fingerprint';

        final portableMatches = byPortableKey[portableKey];

        if (portableMatches != null && portableMatches.isNotEmpty) {
          cached = List<StoredFace>.from(portableMatches);

          // ------------------------------------------------------
          // اگر عکس جابه‌جا شده باشد، اطلاعات ذخیره‌شده را
          // به مسیر جدید rebase می‌کنیم.
          // ------------------------------------------------------
          for (final face in cached) {
            face.rootKey = location.rootKey;
            face.relativePath = location.relativePath;
            face.fingerprint = fingerprint;
          }

          databaseChanged = true;

          // ------------------------------------------------------
          // lookup دقیق را هم به‌روزرسانی می‌کنیم تا اگر چند بار
          // در همین session به این فایل رسیدیم، دوباره lookup
          // portable انجام نشود.
          // ------------------------------------------------------
          byKey[exactKey] = cached;
        }
      }

      // ==========================================================
      // آیا این فایل قبلاً scan شده؟
      // ==========================================================
      final hasScan = db.scans.any(
        (scan) =>
            scan.rootKey == location.rootKey &&
            _normRelative(scan.relativePath) == normalizedRelative &&
            scan.fingerprint == fingerprint,
      );

      // ==========================================================
      // هیچ اطلاعات Face نداریم
      // ==========================================================
      if (cached == null || cached.isEmpty) {
        if (!hasScan) {
          pending.add(item);
        }

        continue;
      }

      // ==========================================================
      // اگر scan فعلی وجود ندارد، آن را ثبت کن.
      // ==========================================================
      if (!hasScan) {
        db.scans.removeWhere(
          (scan) =>
              scan.fingerprint == fingerprint &&
              p.basename(_normRelative(scan.relativePath)) ==
                  p.basename(normalizedRelative),
        );

        db.scans.add(
          FaceScan(
            rootKey: location.rootKey,
            relativePath: location.relativePath,
            fingerprint: fingerprint,
          ),
        );

        databaseChanged = true;
      }

      // ==========================================================
      // انتقال StoredFace -> FaceInfo
      // ==========================================================
      item.faces = cached.map((face) {
        return FaceInfo(
          left: face.left,
          top: face.top,
          width: face.width,
          height: face.height,
          landmarks: List<double>.from(face.landmarks),
          confidence: face.confidence,
          embedding: List<double>.from(face.embedding),
          personId: face.personId,
          faceArea: face.width * face.height,
        );
      }).toList();

      item.faceCount = item.faces.length;
    }

    // ============================================================
    // Save only when something actually changed.
    // ============================================================
    if (databaseChanged) {
      await save(databaseDirectory, db);
    }

    return pending;
  }

  /// Adds new faces and automatically assigns each face to the closest
  /// existing person. A new person is created only when similarity is below
  /// the conservative threshold.
  Future<void> mergeAnalysis({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required Map<MediaItem, List<FaceInfo>> analyzed,
  }) async {
    final db = await load(databaseDirectory);

    // Build identity exemplars BEFORE replacing the files being analyzed.
    // A person is represented by a mean prototype plus a few real embeddings.
    final prototypes = _buildPrototypes(db);
    final exemplars = _buildExemplars(db);

    for (final entry in analyzed.entries) {
      final item = entry.key;
      final location = _locate(item.path, sourceRoots);
      if (location == null) continue;

      final fingerprint = await fingerprintOf(item.path);
      final fileKey =
          '${location.rootKey}|${_normRelative(location.relativePath)}';

      // This file is being re-analyzed. Remove only its previous face records.
      db.faces.removeWhere(
        (face) =>
            '${face.rootKey}|${_normRelative(face.relativePath)}' == fileKey,
      );

      db.scans.removeWhere(
        (scan) =>
            '${scan.rootKey}|${_normRelative(scan.relativePath)}' == fileKey,
      );

      db.scans.add(
        FaceScan(
          rootKey: location.rootKey,
          relativePath: location.relativePath,
          fingerprint: fingerprint,
        ),
      );

      item.faces = [];

      for (final detected in entry.value) {
        if (detected.embedding.length < 8) continue;

        final normalized = _normalize(detected.embedding);

        final match = _findPerson(
          normalized,
          prototypes,
          exemplars,
          db,
        );

        final person = match ?? _createPerson(db);

        final stored = StoredFace(
          id: _newId(),
          personId: person.id,
          rootKey: location.rootKey,
          relativePath: location.relativePath,
          fingerprint: fingerprint,
          left: detected.left,
          top: detected.top,
          width: detected.width,
          height: detected.height,
          confidence: detected.confidence,
          landmarks: List<double>.from(detected.landmarks),
          embedding: normalized,
        );

        db.faces.add(stored);

        prototypes[person.id] =
            _blend(prototypes[person.id], normalized);

        final personExemplars =
            exemplars.putIfAbsent(person.id, () => <List<double>>[]);

        if (personExemplars.length < maxExemplarsPerPerson) {
          personExemplars.add(List<double>.from(normalized));
        } else {
          // Replace the oldest representative occasionally. This keeps
          // matching fast while allowing the identity to adapt over time.
          final replaceIndex =
              db.faces.length % maxExemplarsPerPerson;
          personExemplars[replaceIndex] =
              List<double>.from(normalized);
        }

        item.faces.add(
          detected.copyWith(
            embedding: normalized,
            personId: person.id,
          ),
        );

        // Keep the clearest/largest detected face as the person's cover.
        final currentCoverScore =
            _coverScoreForPerson(db, person.id);

        if (person.coverRelativePath == null ||
            detected.quality >= currentCoverScore) {
          person.coverRootKey = location.rootKey;
          person.coverRelativePath = location.relativePath;
        }

        person.updatedAt = DateTime.now();
      }

      item.faceCount = item.faces.length;
    }

    await save(databaseDirectory, db);
  }

  Future<void> mergePersons({
    required String databaseDirectory,
    required String primaryPersonId,
    required String secondaryPersonId,
  }) async {
    if (primaryPersonId == secondaryPersonId) return;

    final db = await load(databaseDirectory);

    FacePerson? primary;
    FacePerson? secondary;

    for (final person in db.persons) {
      if (person.id == primaryPersonId) {
        primary = person;
      } else if (person.id == secondaryPersonId) {
        secondary = person;
      }
    }

    if (primary == null || secondary == null) return;

    // All historical faces belonging to the second category now belong
    // to the first one.
    for (final face in db.faces) {
      if (face.personId == secondaryPersonId) {
        face.personId = primaryPersonId;
      }
    }

    // If the primary person has no cover, inherit the secondary cover.
    if (primary.coverRelativePath == null &&
        secondary.coverRelativePath != null) {
      primary.coverRootKey = secondary.coverRootKey;
      primary.coverRelativePath = secondary.coverRelativePath;
    }

    primary.updatedAt = DateTime.now();

    db.persons.removeWhere(
      (person) => person.id == secondaryPersonId,
    );

    await save(databaseDirectory, db);
  }


  /// Finds pairs of people whose stored face embeddings are unusually close.
  ///
  /// This is intentionally a suggestion only: the application never merges
  /// these people automatically. The user must explicitly confirm a merge.
  List<FaceMergeSuggestion> findMergeSuggestions(
    FaceDatabase db, {
    double threshold = 0.57,
    int maxResults = 12,
  }) {
    if (db.persons.length < 2 || db.faces.isEmpty) {
      return const [];
    }

    final prototypes = _buildPrototypes(db);
    final exemplars = _buildExemplars(db);

    final suggestions = <FaceMergeSuggestion>[];

    for (var i = 0; i < db.persons.length; i++) {
      final a = db.persons[i];
      final aPrototype = prototypes[a.id];
      final aExemplars = exemplars[a.id];

      if (aPrototype == null && (aExemplars == null || aExemplars.isEmpty)) {
        continue;
      }

      for (var j = i + 1; j < db.persons.length; j++) {
        final b = db.persons[j];
        final bPrototype = prototypes[b.id];
        final bExemplars = exemplars[b.id];

        if (bPrototype == null &&
            (bExemplars == null || bExemplars.isEmpty)) {
          continue;
        }

        var best = -1.0;

        if (aPrototype != null && bPrototype != null) {
          best = math.max(best, cosine(aPrototype, bPrototype));
        }

        if (aPrototype != null && bExemplars != null) {
          for (final sample in bExemplars.take(4)) {
            best = math.max(best, cosine(aPrototype, sample));
          }
        }

        if (bPrototype != null && aExemplars != null) {
          for (final sample in aExemplars.take(4)) {
            best = math.max(best, cosine(bPrototype, sample));
          }
        }

        if (aExemplars != null && bExemplars != null) {
          for (final sampleA in aExemplars.take(3)) {
            for (final sampleB in bExemplars.take(3)) {
              best = math.max(best, cosine(sampleA, sampleB));
            }
          }
        }

        if (best >= threshold) {
          suggestions.add(
            FaceMergeSuggestion(
              firstPersonId: a.id,
              secondPersonId: b.id,
              similarity: best,
            ),
          );
        }
      }
    }

    suggestions.sort(
      (a, b) => b.similarity.compareTo(a.similarity),
    );

    if (suggestions.length > maxResults) {
      return suggestions.sublist(0, maxResults);
    }

    return suggestions;
  }

  Future<void> renamePerson({
    required String databaseDirectory,
    required String personId,
    required String name,
  }) async {
    final db = await load(databaseDirectory);
    FacePerson? person;
    for (final candidate in db.persons) {
      if (candidate.id == personId) {
        person = candidate;
        break;
      }
    }
    if (person == null) return;

    person.name = name.trim().isEmpty ? 'شخص' : name.trim();
    person.updatedAt = DateTime.now();
    await save(databaseDirectory, db);
  }

  Future<FaceDatabase> loadForUi(String databaseDirectory) =>
      load(databaseDirectory);

  String resolveStoredPath(StoredFace face, List<String> sourceRoots) {
    for (final root in sourceRoots) {
      if (_rootKey(root) == face.rootKey) {
        return p.join(root, face.relativePath);
      }
    }
    return p.join(
      sourceRoots.isEmpty ? '' : sourceRoots.first,
      face.relativePath,
    );
  }

  static Future<String> fingerprintOf(String path) async {
    try {
      final stat = await File(path).stat();
      return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    } catch (_) {
      return 'missing';
    }
  }

  Map<String, List<double>> _buildPrototypes(FaceDatabase db) {
    final grouped = <String, List<List<double>>>{};

    for (final face in db.faces) {
      if (face.embedding.length < 8) continue;

      grouped
          .putIfAbsent(face.personId, () => [])
          .add(face.embedding);
    }

    final result = <String, List<double>>{};

    for (final entry in grouped.entries) {
      final vectors = entry.value;
      if (vectors.isEmpty) continue;

      final dim = vectors.first.length;
      final mean = List<double>.filled(dim, 0);

      for (final vector in vectors) {
        for (var i = 0; i < dim && i < vector.length; i++) {
          mean[i] += vector[i];
        }
      }

      for (var i = 0; i < mean.length; i++) {
        mean[i] /= vectors.length;
      }

      result[entry.key] = _normalize(mean);
    }

    return result;
  }

  Map<String, List<List<double>>> _buildExemplars(
    FaceDatabase db,
  ) {
    final result = <String, List<List<double>>>{};

    // Prefer high-confidence faces. They are generally better identity
    // representatives than tiny/blurred detections.
    final sorted = List<StoredFace>.from(db.faces)
      ..sort(
        (a, b) => b.confidence.compareTo(a.confidence),
      );

    for (final face in sorted) {
      if (face.embedding.length < 8) continue;

      final list = result.putIfAbsent(
        face.personId,
        () => <List<double>>[],
      );

      if (list.length >= maxExemplarsPerPerson) continue;

      list.add(
        _normalize(face.embedding),
      );
    }

    return result;
  }

  FaceMatchResult? findBestPerson(
    FaceDatabase db,
    List<double> embedding,
  ) {
    if (embedding.length < 8 || db.persons.isEmpty) {
      return null;
    }

    final normalized = _normalize(embedding);
    final prototypes = _buildPrototypes(db);
    final exemplars = _buildExemplars(db);

    FacePerson? bestPerson;
    var bestScore = -1.0;

    for (final person in db.persons) {
      var score = -1.0;

      final prototype = prototypes[person.id];
      if (prototype != null) {
        score = math.max(score, cosine(normalized, prototype));
      }

      final personExemplars = exemplars[person.id];
      if (personExemplars != null) {
        for (final exemplar in personExemplars) {
          score = math.max(score, cosine(normalized, exemplar));
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPerson = person;
      }
    }

    if (bestPerson == null || bestScore < recognitionThreshold) {
      return null;
    }

    return FaceMatchResult(
      person: bestPerson,
      similarity: bestScore,
    );
  }

  FacePerson? _findPerson(
    List<double> embedding,
    Map<String, List<double>> prototypes,
    Map<String, List<List<double>>> exemplars,
    FaceDatabase db,
  ) {
    FacePerson? bestPerson;
    var bestScore = -1.0;

    for (final person in db.persons) {
      var score = -1.0;

      final prototype = prototypes[person.id];
      if (prototype != null) {
        score = math.max(
          score,
          cosine(embedding, prototype),
        );
      }

      final personExemplars = exemplars[person.id];

      if (personExemplars != null) {
        for (final exemplar in personExemplars) {
          score = math.max(
            score,
            cosine(embedding, exemplar),
          );
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPerson = person;
      }
    }

    if (bestPerson == null) return null;

    // A real historical face gets a slightly more permissive threshold than
    // the mean prototype. This improves matching when the same person appears
    // with glasses, beard, different age, pose or lighting.
    if (bestScore >= exemplarThreshold) {
      return bestPerson;
    }

    if (bestScore >= recognitionThreshold) {
      return bestPerson;
    }

    return null;
  }

  double _coverScoreForPerson(
    FaceDatabase db,
    String personId,
  ) {
    final person = db.persons.firstWhere(
      (p) => p.id == personId,
      orElse: () => FacePerson(
        id: '',
        name: '',
      ),
    );

    if (person.coverRelativePath == null) {
      return 0;
    }

    for (final face in db.faces) {
      if (face.personId == personId &&
          face.relativePath == person.coverRelativePath) {
        final sizeScore = (math.sqrt(
                  math.max(1.0, face.width * face.height),
                ) /
                180.0)
            .clamp(0.0, 1.0);

        return face.confidence * 0.65 +
            sizeScore * 0.35;
      }
    }

    return 0;
  }

  FacePerson _createPerson(FaceDatabase db) {
    final index = db.persons.length + 1;
    final person = FacePerson(id: _newId(), name: 'شخص $index');
    db.persons.add(person);
    return person;
  }

  static List<double> _blend(List<double>? old, List<double> next) {
    if (old == null || old.length != next.length) {
      return List<double>.from(next);
    }

    final result = List<double>.generate(
      next.length,
      (i) => old[i] * 0.75 + next[i] * 0.25,
    );
    return _normalize(result);
  }

  static List<double> _normalize(List<double> vector) {
    var sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    final norm = math.sqrt(sum);
    if (norm <= 1e-9) return List<double>.from(vector);
    return vector.map((e) => e / norm).toList();
  }

  static double cosine(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    var dot = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}';

  static String normalizeRootKey(String root) => _rootKey(root);

  static String _rootKey(String root) {
    var value = p.basename(p.normalize(root)).trim();
    if (value.isEmpty) value = 'root';
    return Platform.isWindows ? value.toLowerCase() : value;
  }

  static String _normRelative(String value) => value
      .replaceAll('\\', '/')
      .replaceFirst(RegExp(r'^/+'), '')
      .toLowerCase();

  _FaceLocation? _locate(String filePath, List<String> roots) {
    final normalizedFile = p.normalize(filePath);

    for (final root in roots) {
      final normalizedRoot = p.normalize(root);
      final relative = p.relative(normalizedFile, from: normalizedRoot);

      if (relative == normalizedFile ||
          relative.startsWith('..${p.separator}')) {
        continue;
      }

      return _FaceLocation(rootKey: _rootKey(root), relativePath: relative);
    }

    return null;
  }
}


class FaceMergeSuggestion {
  final String firstPersonId;
  final String secondPersonId;
  final double similarity;

  const FaceMergeSuggestion({
    required this.firstPersonId,
    required this.secondPersonId,
    required this.similarity,
  });
}

class _FaceLocation {
  final String rootKey;
  final String relativePath;

  const _FaceLocation({required this.rootKey, required this.relativePath});
}
