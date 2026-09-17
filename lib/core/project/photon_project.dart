import 'dart:convert';

import 'package:fgphoto/core/analysis/face_info.dart';
import 'package:fgphoto/core/analysis/photo_score.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';

import 'project_operation.dart';

class PhotonProject {
  static const int currentVersion = 1;

  String name;
  DateTime createdAt;
  DateTime updatedAt;

  List<String> sourcePaths;
  List<MediaItem> mediaItems;
  List<TimelineGroup> groups;
  List<DuplicateGroup> duplicateGroups;

  ApplySettings? applySettings;

  /// وقتی true باشد، اسکن + آنالیز کامل شده و لازم نیست دوباره اجرا شود.
  bool analysisCompleted;

  /// عملیات Copy/Move که برای Resume نگهداری می‌شوند.
  List<ProjectOperation> operations;

  PhotonProject({
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.sourcePaths,
    required this.mediaItems,
    required this.groups,
    required this.duplicateGroups,
    required this.applySettings,
    required this.analysisCompleted,
    required this.operations,
  });

  factory PhotonProject.empty(String name) {
    final now = DateTime.now();
    return PhotonProject(
      name: name,
      createdAt: now,
      updatedAt: now,
      sourcePaths: [],
      mediaItems: [],
      groups: [],
      duplicateGroups: [],
      applySettings: null,
      analysisCompleted: false,
      operations: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': 'photonamger',
      'version': currentVersion,
      'project': {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      },
      'sourcePaths': sourcePaths,
      'analysisCompleted': analysisCompleted,
      'applySettings': applySettings?.toJson(),
      'mediaItems': mediaItems.map(_mediaToJson).toList(),
      'groups': groups.map(_groupToJson).toList(),
      'duplicateGroups': duplicateGroups.map(_duplicateToJson).toList(),
      'operations': operations.map((e) => e.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory PhotonProject.fromJson(Map<String, dynamic> json) {
    final projectJson = json['project'] is Map
        ? Map<String, dynamic>.from(json['project'] as Map)
        : <String, dynamic>{};

    final media = <MediaItem>[];
    final mediaByPath = <String, MediaItem>{};

    final rawMedia = json['mediaItems'];
    if (rawMedia is List) {
      for (final raw in rawMedia) {
        if (raw is! Map) continue;
        final item = _mediaFromJson(Map<String, dynamic>.from(raw));
        media.add(item);
        mediaByPath[item.path] = item;
      }
    }

    final loadedGroups = <TimelineGroup>[];
    final rawGroups = json['groups'];
    if (rawGroups is List) {
      for (final raw in rawGroups) {
        if (raw is! Map) continue;
        final groupJson = Map<String, dynamic>.from(raw);

        final itemPaths = rawListOfStrings(groupJson['itemPaths']);
        final items = <MediaItem>[];
        for (final path in itemPaths) {
          final item = mediaByPath[path];
          if (item != null) items.add(item);
        }

        final metadata = groupJson['metadata'] is Map
            ? GroupMetadata.fromJson(
                Map<String, dynamic>.from(groupJson['metadata'] as Map),
              )
            : null;

        loadedGroups.add(
          TimelineGroup(
            title: groupJson['title']?.toString() ?? '',
            start: DateTime.tryParse(groupJson['start']?.toString() ?? '') ??
                DateTime.now(),
            end: DateTime.tryParse(groupJson['end']?.toString() ?? '') ??
                DateTime.now(),
            items: items,
            metadata: metadata,
            metadataDirectory:
                groupJson['metadataDirectory']?.toString(),
            edited: groupJson['edited'] == true,
            merged: groupJson['merged'] == true,
          ),
        );
      }
    }

    final loadedDuplicates = <DuplicateGroup>[];
    final rawDuplicates = json['duplicateGroups'];
    if (rawDuplicates is List) {
      for (final raw in rawDuplicates) {
        if (raw is! Map) continue;
        final d = Map<String, dynamic>.from(raw);
        final items = <MediaItem>[];

        for (final path in rawListOfStrings(d['itemPaths'])) {
          final item = mediaByPath[path];
          if (item != null) items.add(item);
        }

        if (items.isEmpty) continue;

        var selectedIndex =
            d['selectedIndex'] is int ? d['selectedIndex'] as int : 0;
        if (selectedIndex < 0 || selectedIndex >= items.length) {
          selectedIndex = 0;
        }

        loadedDuplicates.add(
          DuplicateGroup(
            items: items,
            selectedIndex: selectedIndex,
            bestScore: _double(d['bestScore']),
            analyzed: d['analyzed'] == true,
          ),
        );
      }
    }

    ApplySettings? settings;
    if (json['applySettings'] is Map) {
      settings = ApplySettings.fromJson(
        Map<String, dynamic>.from(json['applySettings'] as Map),
      );
    }

    final operations = <ProjectOperation>[];
    final rawOperations = json['operations'];
    if (rawOperations is List) {
      for (final raw in rawOperations) {
        if (raw is Map) {
          operations.add(
            ProjectOperation.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }

    return PhotonProject(
      name: projectJson['name']?.toString() ?? 'پروژه بدون نام',
      createdAt:
          DateTime.tryParse(projectJson['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(projectJson['updatedAt']?.toString() ?? '') ??
              DateTime.now(),
      sourcePaths: rawListOfStrings(json['sourcePaths']),
      mediaItems: media,
      groups: loadedGroups,
      duplicateGroups: loadedDuplicates,
      applySettings: settings,
      analysisCompleted: json['analysisCompleted'] == true,
      operations: operations,
    );
  }

  static Map<String, dynamic> _mediaToJson(MediaItem item) {
    return {
      'path': item.path,
      'createdAt': item.createdAt.toIso8601String(),
      'isVideo': item.isVideo,
      'fileSize': item.fileSize,
      'fileName': item.fileName,
      'metadataDirectory': item.metadataDirectory,
      'groupMetadata': item.groupMetadata?.toJson(),
      'selected': item.selected,
      'isSelected': item.isSelected,
      'analyzed': item.analyzed,
      'qualityScore': item.qualityScore,
      'sharpness': item.sharpness,
      'blurScore': item.blurScore,
      'isBlurred': item.isBlurred,
      'faceCount': item.faceCount,
      'openEyes': item.openEyes,
      'faceQuality': item.faceQuality,
      'largestFaceSize': item.largestFaceSize,
      'brightness': item.brightness,
      'contrast': item.contrast,
      'aiScore': item.aiScore,
      'pHash': item.pHash?.toString(),
      'eyesOpen': item.eyesOpen,
      'analysisMessage': item.analysisMessage,
      'faces': item.faces.map(
        (face) => {
          'leftEyeOpenProbability': face.leftEyeOpenProbability,
          'rightEyeOpenProbability': face.rightEyeOpenProbability,
          'smilingProbability': face.smilingProbability,
          'faceArea': face.faceArea,
          'headEulerY': face.headEulerY,
          'headEulerZ': face.headEulerZ,
        },
      ).toList(),
      'score': item.score == null
          ? null
          : {
              'total': item.score!.total,
              'blur': item.score!.blur,
              'face': item.score!.face,
              'eyes': item.score!.eyes,
              'size': item.score!.size,
              'smile': item.score!.smile,
            },
    };
  }

  static MediaItem _mediaFromJson(Map<String, dynamic> json) {
    final rawFaces = json['faces'];
    final faces = <FaceInfo>[];

    if (rawFaces is List) {
      for (final raw in rawFaces) {
        if (raw is! Map) continue;
        final f = Map<String, dynamic>.from(raw);
        faces.add(
          FaceInfo(
            leftEyeOpenProbability:
                _double(f['leftEyeOpenProbability']),
            rightEyeOpenProbability:
                _double(f['rightEyeOpenProbability']),
            smilingProbability: _double(f['smilingProbability']),
            faceArea: _double(f['faceArea']),
            headEulerY: _double(f['headEulerY']),
            headEulerZ: _double(f['headEulerZ']),
          ),
        );
      }
    }

    PhotoScore? score;
    if (json['score'] is Map) {
      final s = Map<String, dynamic>.from(json['score'] as Map);
      score = PhotoScore(
        total: _double(s['total']),
        blur: _double(s['blur']),
        face: _double(s['face']),
        eyes: _double(s['eyes']),
        size: _double(s['size']),
        smile: _double(s['smile']),
      );
    }

    GroupMetadata? groupMetadata;
    if (json['groupMetadata'] is Map) {
      groupMetadata = GroupMetadata.fromJson(
        Map<String, dynamic>.from(json['groupMetadata'] as Map),
      );
    }

    BigInt? pHash;
    final rawHash = json['pHash']?.toString();
    if (rawHash != null && rawHash.isNotEmpty) {
      pHash = BigInt.tryParse(rawHash);
    }

    final item = MediaItem(
      path: json['path']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      isVideo: json['isVideo'] == true,
      fileSize: json['fileSize'] is int ? json['fileSize'] as int : 0,
      fileName: json['fileName']?.toString() ?? '',
      groupMetadata: groupMetadata,
      metadataDirectory: json['metadataDirectory']?.toString(),
      isSelected: json['isSelected'] is bool
          ? json['isSelected'] as bool
          : json['selected'] != false,
      analyzed: json['analyzed'] == true,
      qualityScore: _double(json['qualityScore']),
      sharpness: _double(json['sharpness']),
      blurScore: _double(json['blurScore']),
      isBlurred: json['isBlurred'] == true,
      faceCount: _int(json['faceCount']),
      openEyes: _int(json['openEyes']),
      faceQuality: _double(json['faceQuality']),
      largestFaceSize: _double(json['largestFaceSize']),
      brightness: _double(json['brightness']),
      contrast: _double(json['contrast']),
      aiScore: _double(json['aiScore']),
      analysisMessage: json['analysisMessage']?.toString() ?? '',
    );

    item.selected = json['selected'] is bool
        ? json['selected'] as bool
        : item.isSelected;
    item.faces = faces;
    item.score = score;
    item.pHash = pHash;
    item.eyesOpen = json['eyesOpen'] == true;

    return item;
  }

  static Map<String, dynamic> _groupToJson(TimelineGroup group) {
    return {
      'title': group.title,
      'start': group.start.toIso8601String(),
      'end': group.end.toIso8601String(),
      'itemPaths': group.items.map((e) => e.path).toList(),
      'metadata': group.metadata?.toJson(),
      'metadataDirectory': group.metadataDirectory,
      'edited': group.edited,
      'merged': group.merged,
    };
  }

  static Map<String, dynamic> _duplicateToJson(DuplicateGroup group) {
    return {
      'itemPaths': group.items.map((e) => e.path).toList(),
      'selectedIndex': group.selectedIndex,
      'bestScore': group.bestScore,
      'analyzed': group.analyzed,
    };
  }

  static List<String> rawListOfStrings(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString()).toList();
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
