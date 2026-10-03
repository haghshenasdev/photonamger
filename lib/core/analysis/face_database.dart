import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

    // Float32 base64 keeps the portable JSON much smaller than
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

class FaceRejection {
  String fingerprint;
  String personId;
  DateTime createdAt;

  FaceRejection({
    required this.fingerprint,
    required this.personId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get key => '$fingerprint|$personId';

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint,
    'personId': personId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FaceRejection.fromJson(Map<String, dynamic> json) {
    return FaceRejection(
      fingerprint: json['fingerprint']?.toString() ?? '',
      personId: json['personId']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class FaceDatabase {
  int version = 4;

  List<FacePerson> persons;
  List<StoredFace> faces;
  List<FaceScan> scans;
  List<FaceRejection> rejections;

  FaceDatabase({
    List<FacePerson>? persons,
    List<StoredFace>? faces,
    List<FaceScan>? scans,
    List<FaceRejection>? rejections,
  }) : persons = persons ?? <FacePerson>[],
       faces = faces ?? <StoredFace>[],
       scans = scans ?? <FaceScan>[],
       rejections = rejections ?? <FaceRejection>[];

  Map<String, dynamic> toJson() => {
    'version': version,
    'archive': false,
    'persons': persons.map((e) => e.toJson()).toList(),
    'faces': faces.map((e) => e.toJson()).toList(),
    'scans': scans.map((e) => e.toJson()).toList(),
    'rejections': rejections.map((e) => e.toJson()).toList(),
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

    final rejections = <FaceRejection>[];

    final rawRejections = json['rejections'];

    if (rawRejections is List) {
      for (final raw in rawRejections) {
        if (raw is Map) {
          final rejection = FaceRejection.fromJson(
            Map<String, dynamic>.from(raw),
          );

          if (rejection.fingerprint.trim().isNotEmpty &&
              rejection.personId.trim().isNotEmpty) {
            rejections.add(rejection);
          }
        }
      }
    }

    return FaceDatabase(
      persons: persons,
      faces: faces,
      scans: scans,
      rejections: rejections,
    )..version = int.tryParse('${json['version']}') ?? 1;
  }
}

class FaceMatchResult {
  final FacePerson person;
  final double similarity;

  const FaceMatchResult({required this.person, required this.similarity});
}

class FaceDatabaseService {
  static const fileName = '.archino_faces.json';

  // SFace cosine similarity.
  static const recognitionThreshold = 0.50;
  static const exemplarThreshold = 0.56;
  static const maxExemplarsPerPerson = 8;

  const FaceDatabaseService();

  File fileFor(String baseDirectory) => File(p.join(baseDirectory, fileName));

  /// The portable archive belongs to the folder that contains the images,
  /// exactly like MetadataService.fileForDirectory().
  File portableFileForDirectory(String directoryPath) {
    return File(Directory(directoryPath).uri.resolve(fileName).toFilePath());
  }

  Future<bool> portableExists(String directoryPath) {
    return portableFileForDirectory(directoryPath).exists();
  }

  /// Reads the portable archive directly from one image directory.
  ///
  /// This intentionally does NOT use the application's central database
  /// recovery files (.bak/.tmp). The folder archive is the portable metadata
  /// belonging to that folder, just like .photonamger.json.
  Future<FaceDatabase?> loadPortableArchive(String directoryPath) async {
    final file = portableFileForDirectory(directoryPath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(content);

      if (decoded is! Map) {
        return null;
      }

      final raw = Map<String, dynamic>.from(decoded);

      if (raw['archive'] != true) {
        return null;
      }

      return FaceDatabase.fromJson(raw);
    } catch (_) {
      // A damaged portable metadata file must not stop folder scanning.
      return null;
    }
  }

  /// Saves the portable archive directly inside its owning folder.
  ///
  /// This mirrors MetadataService.save(): create the directory if necessary
  /// and write the JSON file there. No central DB path is involved.
  Future<void> savePortableArchive({
    required String directoryPath,
    required FaceDatabase archive,
  }) async {
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);

    final file = portableFileForDirectory(directoryPath);

    final json = archive.toJson()..['archive'] = true;

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      encoding: utf8,
      flush: true,
    );
  }

  Future<FaceDatabase> load(String baseDirectory) async {
    final file = fileFor(baseDirectory);

    if (!await file.exists()) {
      return FaceDatabase();
    }

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
  ///
  /// Returns the set of items that still need face inference.
  Future<List<MediaItem>> applyCachedFaces({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required List<MediaItem> items,
    bool forceRescan = false,
  }) async {
    final db = await load(databaseDirectory);

    // IMPORTANT:
    //
    // The portable archive belongs to the folder that contains the images.
    // The images may have been copied to a completely different path and
    // their filenames may also have changed because of collision handling.
    //
    // Therefore, when an archive is available, the current file fingerprint
    // must be the primary key. We pass the current MediaItems to the importer
    // so it can bind every archived face directly to the current image.
    var databaseChanged = await importPortableArchives(
      sourceRoots: sourceRoots,
      database: db,
      currentItems: items,
    );

    final pending = <MediaItem>[];

    final byKey = <String, List<StoredFace>>{};

    final byPortableKey = <String, List<StoredFace>>{};

    for (final face in db.faces) {
      final exactKey =
          '${face.rootKey}|'
          '${_normRelative(face.relativePath)}|'
          '${face.fingerprint}';

      byKey.putIfAbsent(exactKey, () => []).add(face);

      final portableKey = face.fingerprint;

      byPortableKey.putIfAbsent(portableKey, () => []).add(face);
    }

    for (final item in items) {
      item.faces = [];

      // Videos are not processed by face recognition.
      if (item.isVideo) {
        continue;
      }

      if (forceRescan) {
        pending.add(item);
        continue;
      }

      // Normally the item is under one of sourceRoots.  After an Apply,
      // however, the selected destination folder can be a new root.  Since
      // .archino_faces.json belongs to the current image directory, the
      // current file path is a valid fallback location.
      final location =
          _locate(item.path, sourceRoots) ??
          _FaceLocation(
            rootKey: _rootKey(p.dirname(item.path)),
            relativePath: p.basename(item.path),
          );

      final fingerprint = await fingerprintOf(item.path);

      if (fingerprint == 'missing') {
        pending.add(item);
        continue;
      }

      final normalizedRelative = _normRelative(location.relativePath);

      final exactKey =
          '${location.rootKey}|'
          '$normalizedRelative|'
          '$fingerprint';

      List<StoredFace>? cached = byKey[exactKey];

      if (cached == null || cached.isEmpty) {
        final portableMatches = byPortableKey[fingerprint];

        if (portableMatches != null && portableMatches.isNotEmpty) {
          // Clone StoredFace objects. Do not mutate the objects owned by the
          // database when remapping an archive face to the current location.
          cached = portableMatches
              .map(
                (face) => _copyStoredFace(
                  face,
                  rootKey: location.rootKey,
                  relativePath: location.relativePath,
                ),
              )
              .toList();

          databaseChanged = true;
          byKey[exactKey] = cached;
        }
      }

      if (cached != null && cached.isNotEmpty) {
        cached = cached
            .where((face) => !_isRejected(db, fingerprint, face.personId))
            .toList();
      }

      final hasScan = db.scans.any(
        (scan) =>
            scan.fingerprint == fingerprint ||
            (scan.rootKey == location.rootKey &&
                _normRelative(scan.relativePath) == normalizedRelative &&
                scan.fingerprint == fingerprint),
      );

      if (cached == null || cached.isEmpty) {
        if (!hasScan) {
          pending.add(item);
        }

        continue;
      }

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

    if (databaseChanged) {
      await save(databaseDirectory, db);
    }

    return pending;
  }

  /// Imports portable face manifests found inside the supplied source roots.
  Future<bool> importPortableArchives({
    required List<String> sourceRoots,
    required FaceDatabase database,
    List<MediaItem>? currentItems,
  }) async {
    if (sourceRoots.isEmpty && (currentItems == null || currentItems.isEmpty)) {
      return false;
    }

    var changed = false;

    final personsById = <String, FacePerson>{
      for (final person in database.persons)
        if (person.id.trim().isNotEmpty) person.id: person,
    };

    final knownFaceKeys = <String>{
      for (final face in database.faces)
        if (face.fingerprint.trim().isNotEmpty &&
            face.fingerprint != 'missing' &&
            face.personId.trim().isNotEmpty)
          '${face.fingerprint}|${face.personId}',
    };

    final currentItemByFingerprint = <String, MediaItem>{};

    if (currentItems != null) {
      for (final item in currentItems) {
        if (item.isVideo) continue;

        final fingerprint = await fingerprintOf(item.path);
        if (fingerprint == 'missing') continue;

        currentItemByFingerprint[fingerprint] = item;
      }
    }

    // First look exactly where .photonamger.json lives: beside every current
    // image. This is the authoritative portable location after Apply.
    final manifestDirectories = <String>{};

    if (currentItems != null) {
      for (final item in currentItems) {
        if (item.isVideo) continue;
        final directory = p.dirname(item.path).trim();
        if (directory.isNotEmpty) {
          manifestDirectories.add(p.normalize(p.absolute(directory)));
        }
      }
    }

    // Keep recursive source-root discovery for old projects and for callers
    // that import archives before MediaItems have been created.
    for (final root in sourceRoots) {
      final value = root.trim();
      if (value.isEmpty) continue;
      final normalized = p.normalize(p.absolute(value));
      if (await File(p.join(normalized, fileName)).exists()) {
        manifestDirectories.add(normalized);
      }

      final rootDirectory = Directory(normalized);
      if (!await rootDirectory.exists()) continue;

      try {
        await for (final entity in rootDirectory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && p.basename(entity.path) == fileName) {
            manifestDirectories.add(
              p.normalize(p.absolute(p.dirname(entity.path))),
            );
          }
        }
      } catch (_) {
        // One inaccessible branch must not prevent other manifests loading.
      }
    }

    for (final manifestDirectory in manifestDirectories) {
      final archive = await loadPortableArchive(manifestDirectory);
      if (archive == null) continue;

      // ------------------------------------------------------------
      // Persons
      // ------------------------------------------------------------
      for (final importedPerson in archive.persons) {
        final id = importedPerson.id.trim();
        if (id.isEmpty) continue;

        final existing = personsById[id];

        if (existing == null) {
          final copied = FacePerson(
            id: id,
            name: importedPerson.name.trim().isEmpty
                ? 'شخص'
                : importedPerson.name.trim(),
            coverRootKey: importedPerson.coverRootKey,
            coverRelativePath: importedPerson.coverRelativePath,
            createdAt: importedPerson.createdAt,
            updatedAt: importedPerson.updatedAt,
          );

          database.persons.add(copied);
          personsById[id] = copied;
          changed = true;
        } else if (importedPerson.updatedAt.isAfter(existing.updatedAt)) {
          final newName = importedPerson.name.trim();

          if (newName.isNotEmpty && newName != existing.name) {
            existing.name = newName;
          }

          if (importedPerson.coverRootKey != null &&
              importedPerson.coverRootKey!.trim().isNotEmpty) {
            existing.coverRootKey = importedPerson.coverRootKey;
          }

          if (importedPerson.coverRelativePath != null &&
              importedPerson.coverRelativePath!.trim().isNotEmpty) {
            existing.coverRelativePath = importedPerson.coverRelativePath;
          }

          existing.updatedAt = importedPerson.updatedAt;
          changed = true;
        }
      }

      // ------------------------------------------------------------
      // Scan markers
      // ------------------------------------------------------------
      for (final importedScan in archive.scans) {
        final fingerprint = importedScan.fingerprint.trim();
        if (fingerprint.isEmpty || fingerprint == 'missing') continue;

        if (database.scans.any((scan) => scan.fingerprint == fingerprint)) {
          continue;
        }

        final currentItem = currentItemByFingerprint[fingerprint];

        database.scans.add(
          FaceScan(
            rootKey: currentItem == null
                ? _rootKey(manifestDirectory)
                : _rootKey(p.dirname(currentItem.path)),
            relativePath: currentItem == null
                ? importedScan.relativePath.trim()
                : p.basename(currentItem.path),
            fingerprint: fingerprint,
          ),
        );
        changed = true;
      }

      // ------------------------------------------------------------
      // Rejections
      // ------------------------------------------------------------
      for (final importedRejection in archive.rejections) {
        final fingerprint = importedRejection.fingerprint.trim();
        final personId = importedRejection.personId.trim();

        if (fingerprint.isEmpty || personId.isEmpty) continue;
        if (!personsById.containsKey(personId)) continue;

        final exists = database.rejections.any(
          (r) => r.key == '$fingerprint|$personId',
        );

        if (!exists) {
          database.rejections.add(
            FaceRejection(
              fingerprint: fingerprint,
              personId: personId,
              createdAt: importedRejection.createdAt,
            ),
          );
          changed = true;
        }

        final before = database.faces.length;
        database.faces.removeWhere(
          (face) =>
              face.fingerprint == fingerprint && face.personId == personId,
        );
        if (before != database.faces.length) changed = true;
      }

      // ------------------------------------------------------------
      // Faces
      // ------------------------------------------------------------
      for (final importedFace in archive.faces) {
        final fingerprint = importedFace.fingerprint.trim();
        final personId = importedFace.personId.trim();

        if (fingerprint.isEmpty || fingerprint == 'missing' || personId.isEmpty) {
          continue;
        }

        // A portable archive created by an older build may contain faces but
        // no persons. Create a stable placeholder instead of silently
        // throwing the face away.
        if (!personsById.containsKey(personId)) {
          final placeholder = FacePerson(
            id: personId,
            name: 'شخص',
          );
          database.persons.add(placeholder);
          personsById[personId] = placeholder;
          changed = true;
        }

        if (_isRejected(database, fingerprint, personId)) continue;

        final faceKey = '$fingerprint|$personId';
        if (knownFaceKeys.contains(faceKey)) {
          continue;
        }

        final currentItem = currentItemByFingerprint[fingerprint];

        final copiedFace = _copyStoredFace(
          importedFace,
          rootKey: currentItem == null
              ? _rootKey(manifestDirectory)
              : _rootKey(p.dirname(currentItem.path)),
          relativePath: currentItem == null
              ? _normRelative(importedFace.relativePath)
              : p.basename(currentItem.path),
        );

        database.faces.add(copiedFace);
        knownFaceKeys.add(faceKey);
        changed = true;

        // Keep the person cover portable and tied to the current destination
        // path rather than the old machine/path.
        if (currentItem != null) {
          final person = personsById[personId];
          if (person != null) {
            final score = _faceScore(copiedFace);
            final currentCover = _coverScoreForPerson(database, personId);
            if (person.coverRelativePath == null || score >= currentCover) {
              person.coverRootKey = copiedFace.rootKey;
              person.coverRelativePath = copiedFace.relativePath;
              person.updatedAt = DateTime.now();
              changed = true;
            }
          }
        }
      }
    }

    return changed;
  }

  Future<String?> _resolvePortableFacePath(
    StoredFace face, {
    required String sourceRoot,
    required String manifestDirectory,
  }) async {
    final relative = _normRelative(face.relativePath);

    if (relative.isEmpty) return null;

    final rootCandidate = p.normalize(p.join(sourceRoot, relative));

    if (await File(rootCandidate).exists()) {
      return rootCandidate;
    }

    final localCandidate = p.normalize(p.join(manifestDirectory, relative));

    if (await File(localCandidate).exists()) {
      return localCandidate;
    }

    var current = Directory(manifestDirectory);

    while (true) {
      final candidate = p.normalize(p.join(current.path, relative));

      if (await File(candidate).exists()) {
        return candidate;
      }

      final parent = current.parent;

      if (p.normalize(parent.path) == p.normalize(current.path)) {
        break;
      }

      current = parent;
    }

    return null;
  }

  /// Writes a portable face manifest beside the images represented by
  /// the current database.
  ///
  /// Every applied directory represented by [items] receives an archive,
  /// even when an image contains no detected face. This is important because
  /// the scan marker itself tells the next computer that the image was
  /// already analyzed.
  Future<void> exportPortableArchives({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required List<MediaItem> items,
  }) async {
    if (items.isEmpty && sourceRoots.isEmpty) return;

    final database = await load(databaseDirectory);

    final personsById = <String, FacePerson>{
      for (final person in database.persons)
        if (person.id.trim().isNotEmpty) person.id: person,
    };

    final groupedFaces = <String, List<StoredFace>>{};
    final groupedRejections = <String, List<FaceRejection>>{};
    final groupedScans = <String, List<FaceScan>>{};

    final exportedFaceKeys = <String>{};
    final itemPathByFingerprint = <String, String>{};

    // ------------------------------------------------------------
    // Current MediaItems are the first source of truth.
    //
    // During Apply these objects still contain the FaceInfo results produced
    // by the analysis, while their path has already been changed to the
    // destination path. Exporting these objects avoids losing faces merely
    // because the central DB and the destination path have not been rebound
    // yet.
    // ------------------------------------------------------------
    for (final item in items) {
      if (item.isVideo) continue;

      final file = File(item.path);
      if (!await file.exists()) continue;

      final fingerprint = await fingerprintOf(item.path);
      if (fingerprint == 'missing') continue;

      final directory = p.dirname(item.path);
      final rootKey = _rootKey(directory);
      final relativePath = p.basename(item.path);

      itemPathByFingerprint[fingerprint] = item.path;

      groupedScans.putIfAbsent(directory, () => <FaceScan>[]).add(
        FaceScan(
          rootKey: rootKey,
          relativePath: relativePath,
          fingerprint: fingerprint,
        ),
      );

      // IMPORTANT: export the faces currently attached to the MediaItem.
      // This is what makes Apply portable even before a project reload.
      for (final info in item.faces) {
        final personId = info.personId?.trim() ?? '';
        if (personId.isEmpty || info.embedding.length < 8) continue;

        // MediaItem.faces is the authoritative result during Apply. Never
        // discard a detected face just because the central person list was
        // loaded from another project location.
        personsById.putIfAbsent(
          personId,
          () => FacePerson(id: personId, name: 'شخص'),
        );

        final key = '$fingerprint|$personId';
        if (exportedFaceKeys.contains(key)) continue;
        if (_isRejected(database, fingerprint, personId)) continue;

        final stored = StoredFace(
          id: _newId(),
          personId: personId,
          rootKey: rootKey,
          relativePath: relativePath,
          fingerprint: fingerprint,
          left: info.left,
          top: info.top,
          width: info.width,
          height: info.height,
          confidence: info.confidence,
          landmarks: List<double>.from(info.landmarks),
          embedding: List<double>.from(info.embedding),
        );

        groupedFaces.putIfAbsent(directory, () => <StoredFace>[]).add(stored);
        exportedFaceKeys.add(key);
      }
    }

    // ------------------------------------------------------------
    // Fallback to the central DB.
    //
    // This covers Apply after a project reload, when MediaItem.faces is empty
    // but the central face database already contains the analysis.
    // ------------------------------------------------------------
    for (final face in database.faces) {
      final fingerprint = face.fingerprint.trim();
      final personId = face.personId.trim();

      if (fingerprint.isEmpty || fingerprint == 'missing' || personId.isEmpty) {
        continue;
      }
      if (_isRejected(database, fingerprint, personId)) continue;

      // Preserve the face even if the central persons list is temporarily
      // missing this person. The person record is reconstructed below.
      personsById.putIfAbsent(
        personId,
        () => FacePerson(id: personId, name: 'شخص'),
      );

      final key = '$fingerprint|$personId';
      if (exportedFaceKeys.contains(key)) continue;

      final currentItemPath = itemPathByFingerprint[fingerprint];
      if (currentItemPath != null) {
        final directory = p.dirname(currentItemPath);
        final copied = _copyStoredFace(
          face,
          rootKey: _rootKey(directory),
          relativePath: p.basename(currentItemPath),
        );

        groupedFaces.putIfAbsent(directory, () => <StoredFace>[]).add(copied);
        exportedFaceKeys.add(key);
        continue;
      }

      // Last-resort compatibility for callers that provide source roots but
      // no current MediaItem for an old DB entry.
      final storedPath = resolveStoredPath(face, sourceRoots);
      if (!await File(storedPath).exists()) continue;

      final directory = p.dirname(storedPath);
      final copied = _copyStoredFace(
        face,
        rootKey: _rootKey(directory),
        relativePath: p.basename(storedPath),
      );

      groupedFaces.putIfAbsent(directory, () => <StoredFace>[]).add(copied);
      exportedFaceKeys.add(key);
    }

    // ------------------------------------------------------------
    // Rejections
    // ------------------------------------------------------------
    for (final rejection in database.rejections) {
      var currentItemPath = itemPathByFingerprint[rejection.fingerprint];

      if (currentItemPath == null) {
        for (final face in database.faces) {
          if (face.fingerprint != rejection.fingerprint) continue;
          final path = resolveStoredPath(face, sourceRoots);
          if (await File(path).exists()) {
            currentItemPath = path;
            break;
          }
        }
      }

      if (currentItemPath == null) continue;

      final directory = p.dirname(currentItemPath);
      groupedRejections.putIfAbsent(directory, () => <FaceRejection>[]).add(
        FaceRejection(
          fingerprint: rejection.fingerprint,
          personId: rejection.personId,
          createdAt: rejection.createdAt,
        ),
      );
    }

    final directories = <String>{
      ...groupedScans.keys,
      ...groupedFaces.keys,
      ...groupedRejections.keys,
    };

    for (final directory in directories) {
      final archiveFaces = groupedFaces[directory] ?? const <StoredFace>[];
      final archiveRejections =
          groupedRejections[directory] ?? const <FaceRejection>[];
      final archiveScans = groupedScans[directory] ?? const <FaceScan>[];

      // A person belongs to this folder if at least one of its faces or
      // rejections is represented there. This keeps the archive self-contained.
      final personIds = <String>{
        ...archiveFaces.map((face) => face.personId.trim()),
        ...archiveRejections.map((rejection) => rejection.personId.trim()),
      }..removeWhere((id) => id.isEmpty);

      final archivePersons = <FacePerson>[];

      for (final personId in personIds) {
        final person = personsById.putIfAbsent(
          personId,
          () => FacePerson(id: personId, name: 'شخص'),
        );

        // Prefer a cover face from this archive so the portable person record
        // does not point back to an old machine.
        StoredFace? bestFace;
        for (final face in archiveFaces) {
          if (face.personId != personId) continue;
          if (bestFace == null || _faceScore(face) > _faceScore(bestFace)) {
            bestFace = face;
          }
        }

        archivePersons.add(
          FacePerson(
            id: person.id,
            name: person.name,
            coverRootKey: bestFace?.rootKey ?? person.coverRootKey,
            coverRelativePath:
                bestFace?.relativePath ?? person.coverRelativePath,
            createdAt: person.createdAt,
            updatedAt: person.updatedAt,
          ),
        );
      }

      final archive = FaceDatabase(
        persons: archivePersons,
        faces: archiveFaces.map(_copyStoredFace).toList(),
        scans: archiveScans
            .map(
              (scan) => FaceScan(
                rootKey: scan.rootKey,
                relativePath: scan.relativePath,
                fingerprint: scan.fingerprint,
              ),
            )
            .toList(),
        rejections: archiveRejections
            .map(
              (rejection) => FaceRejection(
                fingerprint: rejection.fingerprint,
                personId: rejection.personId,
                createdAt: rejection.createdAt,
              ),
            )
            .toList(),
      )..version = 4;

      await savePortableArchive(directoryPath: directory, archive: archive);
    }
  }

  static StoredFace _copyStoredFace(
    StoredFace face, {
    String? rootKey,
    String? relativePath,
  }) {
    return StoredFace(
      id: face.id,
      personId: face.personId,
      rootKey: rootKey ?? face.rootKey,
      relativePath: relativePath ?? face.relativePath,
      fingerprint: face.fingerprint,
      left: face.left,
      top: face.top,
      width: face.width,
      height: face.height,
      confidence: face.confidence,
      landmarks: List<double>.from(face.landmarks),
      embedding: List<double>.from(face.embedding),
    );
  }

  double _faceScore(StoredFace face) {
    final area = math.sqrt(
      math.max(1.0, face.width * face.height),
    );
    final sizeScore = (area / 180.0).clamp(0.0, 1.0);
    return face.confidence * 0.65 + sizeScore * 0.35;
  }

  bool _isRejected(FaceDatabase database, String fingerprint, String personId) {
    if (fingerprint.trim().isEmpty || personId.trim().isEmpty) {
      return false;
    }

    return database.rejections.any(
      (rejection) =>
          rejection.fingerprint == fingerprint &&
          rejection.personId == personId,
    );
  }

  List<String> rejectedPersonIds(FaceDatabase database, String fingerprint) {
    return database.rejections
        .where((r) => r.fingerprint == fingerprint)
        .map((r) => r.personId)
        .toSet()
        .toList();
  }

  /// Marks an automatic face assignment as incorrect
  /// for this exact image.
  Future<void> rejectFaceForPerson({
    required String databaseDirectory,
    required String imagePath,
    required String personId,
    required List<String> sourceRoots,
  }) async {
    final fingerprint = await fingerprintOf(imagePath);

    if (fingerprint == 'missing') return;

    final db = await load(databaseDirectory);

    db.faces.removeWhere(
      (face) => face.fingerprint == fingerprint && face.personId == personId,
    );

    final exists = db.rejections.any(
      (rejection) => rejection.key == '$fingerprint|$personId',
    );

    if (!exists) {
      db.rejections.add(
        FaceRejection(fingerprint: fingerprint, personId: personId),
      );
    }

    await save(databaseDirectory, db);

    await _syncRejectionToPortableManifests(
      sourceRoots: sourceRoots,
      fingerprint: fingerprint,
      personId: personId,
    );
  }

  /// Removes a previous "not this person" correction.
  Future<void> clearFaceRejection({
    required String databaseDirectory,
    required String imagePath,
    required String personId,
    required List<String> sourceRoots,
  }) async {
    final fingerprint = await fingerprintOf(imagePath);

    if (fingerprint == 'missing') return;

    final db = await load(databaseDirectory);

    db.rejections.removeWhere(
      (rejection) =>
          rejection.fingerprint == fingerprint &&
          rejection.personId == personId,
    );

    await save(databaseDirectory, db);

    await _removeRejectionFromPortableManifests(
      sourceRoots: sourceRoots,
      fingerprint: fingerprint,
      personId: personId,
    );
  }

  Future<void> _syncRejectionToPortableManifests({
    required List<String> sourceRoots,
    required String fingerprint,
    required String personId,
  }) async {
    await _forEachPortableManifest(
      databaseDirectory: sourceRoots.isEmpty ? '.' : sourceRoots.first,
      sourceRoots: sourceRoots,
      action: (file, archive) async {
        final containsImage = archive.faces.any(
          (face) => face.fingerprint == fingerprint,
        );

        if (!containsImage) {
          return false;
        }

        archive.faces.removeWhere(
          (face) =>
              face.fingerprint == fingerprint && face.personId == personId,
        );

        if (!archive.persons.any((person) => person.id == personId)) {
          return false;
        }

        final exists = archive.rejections.any(
          (rejection) =>
              rejection.fingerprint == fingerprint &&
              rejection.personId == personId,
        );

        if (!exists) {
          archive.rejections.add(
            FaceRejection(fingerprint: fingerprint, personId: personId),
          );
        }

        return true;
      },
    );
  }

  Future<void> _removeRejectionFromPortableManifests({
    required List<String> sourceRoots,
    required String fingerprint,
    required String personId,
  }) async {
    await _forEachPortableManifest(
      databaseDirectory: sourceRoots.isEmpty ? '.' : sourceRoots.first,
      sourceRoots: sourceRoots,
      action: (file, archive) async {
        final before = archive.rejections.length;

        archive.rejections.removeWhere(
          (rejection) =>
              rejection.fingerprint == fingerprint &&
              rejection.personId == personId,
        );

        return before != archive.rejections.length;
      },
    );
  }

  /// Adds new faces and automatically assigns each face
  /// to the closest existing person.
  Future<void> mergeAnalysis({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required Map<MediaItem, List<FaceInfo>> analyzed,
  }) async {
    final db = await load(databaseDirectory);

    await importPortableArchives(sourceRoots: sourceRoots, database: db);

    final analysisFingerprints = <String>{};

    for (final item in analyzed.keys) {
      final fingerprint = await fingerprintOf(item.path);

      if (fingerprint != 'missing') {
        analysisFingerprints.add(fingerprint);
      }
    }

    final matchingDatabase = FaceDatabase(
      persons: db.persons,
      faces: db.faces
          .where((face) => !analysisFingerprints.contains(face.fingerprint))
          .toList(),
      scans: db.scans,
      rejections: db.rejections,
    );

    final prototypes = _buildPrototypes(matchingDatabase);

    final exemplars = _buildExemplars(matchingDatabase);

    for (final entry in analyzed.entries) {
      final item = entry.key;

      final location = _locate(item.path, sourceRoots);

      if (location == null) continue;

      final fingerprint = await fingerprintOf(item.path);

      final fileKey =
          '${location.rootKey}|'
          '${_normRelative(location.relativePath)}';

      db.faces.removeWhere(
        (face) =>
            '${face.rootKey}|'
                '${_normRelative(face.relativePath)}' ==
            fileKey,
      );

      db.scans.removeWhere(
        (scan) =>
            '${scan.rootKey}|'
                '${_normRelative(scan.relativePath)}' ==
            fileKey,
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
        if (detected.embedding.length < 8) {
          continue;
        }

        final normalized = _normalize(detected.embedding);

        final match = _findPerson(
          normalized,
          prototypes,
          exemplars,
          db,
          fingerprint: fingerprint,
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

        if (match == null) {
          prototypes[person.id] = List<double>.from(normalized);

          exemplars[person.id] = <List<double>>[List<double>.from(normalized)];
        }

        item.faces.add(
          detected.copyWith(embedding: normalized, personId: person.id),
        );

        final currentCoverScore = _coverScoreForPerson(db, person.id);

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
    List<String> sourceRoots = const <String>[],
  }) async {
    if (primaryPersonId == secondaryPersonId) {
      return;
    }

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

    if (primary == null || secondary == null) {
      return;
    }

    for (final face in db.faces) {
      if (face.personId == secondaryPersonId) {
        face.personId = primaryPersonId;
      }
    }

    for (final rejection in db.rejections) {
      if (rejection.personId == secondaryPersonId) {
        rejection.personId = primaryPersonId;
      }
    }

    final rejectionMap = <String, FaceRejection>{};

    for (final rejection in db.rejections) {
      rejectionMap[rejection.key] = rejection;
    }

    db.rejections = rejectionMap.values.toList();

    if (primary.coverRelativePath == null &&
        secondary.coverRelativePath != null) {
      primary.coverRootKey = secondary.coverRootKey;

      primary.coverRelativePath = secondary.coverRelativePath;
    }

    primary.updatedAt = DateTime.now();

    db.persons.removeWhere((person) => person.id == secondaryPersonId);

    await save(databaseDirectory, db);

    await _syncPersonToPortableManifests(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      personId: primaryPersonId,
    );

    await _removePersonFromPortableManifests(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      personId: secondaryPersonId,
    );
  }

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

        if (bPrototype == null && (bExemplars == null || bExemplars.isEmpty)) {
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

    suggestions.sort((a, b) => b.similarity.compareTo(a.similarity));

    if (suggestions.length > maxResults) {
      return suggestions.sublist(0, maxResults);
    }

    return suggestions;
  }

  Future<void> renamePerson({
    required String databaseDirectory,
    required String personId,
    required String name,
    List<String> sourceRoots = const <String>[],
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

    await _syncPersonToPortableManifests(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      personId: personId,
    );
  }

  Future<void> _syncPersonToPortableManifests({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required String personId,
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

    await _forEachPortableManifest(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      action: (file, archive) async {
        var changed = false;

        for (final item in archive.persons) {
          if (item.id != personId) {
            continue;
          }

          if (item.name != person!.name ||
              item.updatedAt.isBefore(person.updatedAt)) {
            item.name = person.name;
            item.updatedAt = person.updatedAt;
            item.coverRootKey = person.coverRootKey;
            item.coverRelativePath = person.coverRelativePath;

            changed = true;
          }
        }

        return changed;
      },
    );
  }

  Future<void> _removePersonFromPortableManifests({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required String personId,
  }) async {
    await _forEachPortableManifest(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      action: (file, archive) async {
        var changed = false;

        final beforePersons = archive.persons.length;

        archive.persons.removeWhere((p) => p.id == personId);

        if (archive.persons.length != beforePersons) {
          changed = true;
        }

        final beforeFaces = archive.faces.length;

        archive.faces.removeWhere((f) => f.personId == personId);

        if (archive.faces.length != beforeFaces) {
          changed = true;
        }

        final beforeRejections = archive.rejections.length;

        archive.rejections.removeWhere((r) => r.personId == personId);

        if (archive.rejections.length != beforeRejections) {
          changed = true;
        }

        return changed;
      },
    );
  }

  Future<void> _forEachPortableManifest({
    required String databaseDirectory,
    required List<String> sourceRoots,
    required Future<bool> Function(File file, FaceDatabase archive) action,
  }) async {
    final roots = <String>{databaseDirectory, ...sourceRoots};

    final processed = <String>{};

    for (final root in roots) {
      final directory = Directory(root);

      if (!await directory.exists()) {
        continue;
      }

      try {
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File || p.basename(entity.path) != fileName) {
            continue;
          }

          final path = p.normalize(entity.path);

          if (!processed.add(path)) {
            continue;
          }

          try {
            final decoded = jsonDecode(await entity.readAsString());

            if (decoded is! Map || decoded['archive'] != true) {
              continue;
            }

            final archive = FaceDatabase.fromJson(
              Map<String, dynamic>.from(decoded),
            );

            final changed = await action(entity, archive);

            if (!changed) continue;

            final json = archive.toJson()..['archive'] = true;

            final temp = File('${entity.path}.tmp');

            await temp.writeAsString(
              const JsonEncoder.withIndent('  ').convert(json),
              encoding: utf8,
              flush: true,
            );

            if (await entity.exists()) {
              await entity.delete();
            }

            await temp.rename(entity.path);
          } catch (_) {
            // Ignore invalid manifest.
          }
        }
      } catch (_) {
        // Ignore inaccessible root.
      }
    }
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
      final file = File(path);

      if (!await file.exists()) {
        return 'missing';
      }

      final digest = sha256.convert(await file.readAsBytes());

      return 'sha256:${digest.toString()}';
    } catch (_) {
      return 'missing';
    }
  }

  Map<String, List<double>> _buildPrototypes(FaceDatabase db) {
    final grouped = <String, List<List<double>>>{};

    for (final face in db.faces) {
      if (face.embedding.length < 8) {
        continue;
      }

      grouped.putIfAbsent(face.personId, () => []).add(face.embedding);
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

  Map<String, List<List<double>>> _buildExemplars(FaceDatabase db) {
    final result = <String, List<List<double>>>{};

    final sorted = List<StoredFace>.from(db.faces)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final face in sorted) {
      if (face.embedding.length < 8) {
        continue;
      }

      final list = result.putIfAbsent(face.personId, () => <List<double>>[]);

      if (list.length >= maxExemplarsPerPerson) {
        continue;
      }

      list.add(_normalize(face.embedding));
    }

    return result;
  }

  FaceMatchResult? findBestPerson(FaceDatabase db, List<double> embedding) {
    if (embedding.length < 8 || db.persons.isEmpty) {
      return null;
    }

    final normalized = _normalize(embedding);

    final prototypes = _buildPrototypes(db);

    final exemplars = _buildExemplars(db);

    FacePerson? bestPerson;

    var bestScore = -1.0;
    var secondBestScore = -1.0;

    for (final person in db.persons) {
      var score = -1.0;

      final prototype = prototypes[person.id];

      if (prototype != null) {
        score = math.max(score, cosine(normalized, prototype));
      }

      final personExemplars = exemplars[person.id];

      if (personExemplars != null && personExemplars.isNotEmpty) {
        final exemplarScores =
            personExemplars
                .map((exemplar) => cosine(normalized, exemplar))
                .toList()
              ..sort((a, b) => b.compareTo(a));

        if (exemplarScores.isNotEmpty) {
          score = math.max(score, exemplarScores.first);
        }

        if (exemplarScores.length >= 2) {
          final top2 = (exemplarScores[0] + exemplarScores[1]) / 2;

          score = math.max(score, top2);
        }
      }

      if (score > bestScore) {
        secondBestScore = bestScore;

        bestScore = score;
        bestPerson = person;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestPerson == null || bestScore < recognitionThreshold) {
      return null;
    }

    if (secondBestScore >= recognitionThreshold &&
        bestScore - secondBestScore < 0.035) {
      return null;
    }

    return FaceMatchResult(person: bestPerson, similarity: bestScore);
  }

  FacePerson? _findPerson(
    List<double> embedding,
    Map<String, List<double>> prototypes,
    Map<String, List<List<double>>> exemplars,
    FaceDatabase db, {
    String? fingerprint,
  }) {
    FacePerson? bestPerson;

    var bestScore = -1.0;
    var secondBestScore = -1.0;

    for (final person in db.persons) {
      if (fingerprint != null && _isRejected(db, fingerprint, person.id)) {
        continue;
      }

      var score = -1.0;

      final prototype = prototypes[person.id];

      if (prototype != null) {
        score = math.max(score, cosine(embedding, prototype));
      }

      final personExemplars = exemplars[person.id];

      if (personExemplars != null && personExemplars.isNotEmpty) {
        final exemplarScores =
            personExemplars
                .map((exemplar) => cosine(embedding, exemplar))
                .toList()
              ..sort((a, b) => b.compareTo(a));

        if (exemplarScores.isNotEmpty) {
          score = math.max(score, exemplarScores.first);
        }

        if (exemplarScores.length >= 2) {
          final top2 = (exemplarScores[0] + exemplarScores[1]) / 2;

          score = math.max(score, top2);
        }
      }

      if (score > bestScore) {
        secondBestScore = bestScore;

        bestScore = score;
        bestPerson = person;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    if (bestPerson == null) {
      return null;
    }

    if (bestScore < recognitionThreshold) {
      return null;
    }

    if (secondBestScore >= recognitionThreshold &&
        bestScore - secondBestScore < 0.035) {
      return null;
    }

    return bestPerson;
  }

  double _coverScoreForPerson(FaceDatabase db, String personId) {
    final person = db.persons.firstWhere(
      (p) => p.id == personId,
      orElse: () => FacePerson(id: '', name: ''),
    );

    if (person.coverRelativePath == null) {
      return 0;
    }

    for (final face in db.faces) {
      if (face.personId == personId &&
          face.relativePath == person.coverRelativePath) {
        final sizeScore =
            (math.sqrt(math.max(1.0, face.width * face.height)) / 180.0).clamp(
              0.0,
              1.0,
            );

        return face.confidence * 0.65 + sizeScore * 0.35;
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

    if (norm <= 1e-9) {
      return List<double>.from(vector);
    }

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
      '${DateTime.now().microsecondsSinceEpoch}_'
      '${math.Random().nextInt(1 << 20)}';

  static String normalizeRootKey(String root) => _rootKey(root);

  static String _rootKey(String root) {
    var value = p.basename(p.normalize(root)).trim();

    if (value.isEmpty) {
      value = 'root';
    }

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
