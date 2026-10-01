import 'package:flutter/foundation.dart';

import '../../ui/models/duplicate_group.dart';
import '../../ui/models/media_item.dart';
import '../../ui/models/timeline_group.dart';

import '../duplicate_detector.dart';
import '../temporal_burst_detector.dart';
import '../timeline_builder.dart';

import 'analysis_callback.dart';
import 'analysis_controller.dart';
import 'analysis_progress.dart';
import 'analysis_result.dart';
import 'analysis_stage.dart';
import 'analysis_status.dart';
import 'blur_detector.dart';
import 'face_database.dart';
import 'face_info.dart';
import 'face_recognition_engine.dart';

import 'quality_scorer.dart';
import 'best_photo_selector.dart';

class AnalysisEngine {
  final AnalysisController controller;

  final BlurDetector blurDetector;

  final QualityScorer qualityScorer;

  final BestPhotoSelector bestPhotoSelector;

  final FaceRecognitionEngine faceRecognitionEngine;

  final FaceDatabaseService faceDatabaseService;

  final TimelineBuilder timelineBuilder;

  /// الگوریتم قدیمی و دقیق pHash.
  ///
  /// این الگوریتم فقط در تحلیل دستی گروه استفاده می‌شود.
  final DuplicateDetector duplicateDetector;

  /// الگوریتم سریع تشخیص عکس‌های پشت‌سرهم.
  ///
  /// این الگوریتم در آنالیز اولیه اجرا می‌شود.
  final TemporalBurstDetector temporalBurstDetector;

  AnalysisEngine({
    required this.controller,
    TimelineBuilder? timelineBuilder,
    DuplicateDetector? duplicateDetector,
    TemporalBurstDetector? temporalBurstDetector,
    required this.blurDetector,
    required this.qualityScorer,
    required this.bestPhotoSelector,
    FaceRecognitionEngine? faceRecognitionEngine,
    FaceDatabaseService? faceDatabaseService,
  })  : faceRecognitionEngine =
            faceRecognitionEngine ?? FaceRecognitionEngine(),
        faceDatabaseService =
            faceDatabaseService ?? const FaceDatabaseService(),
       timelineBuilder = timelineBuilder ?? TimelineBuilder(),
       duplicateDetector = duplicateDetector ?? DuplicateDetector(),
       temporalBurstDetector = temporalBurstDetector ?? TemporalBurstDetector();

  List<TimelineGroup> timelineGroups = [];

  List<DuplicateGroup> duplicateGroups = [];

  List<MediaItem> mediaItems = [];

  bool _running = false;

  bool get isRunning => _running;

  AnalysisProgress? progress = const AnalysisProgress(
    stage: AnalysisStage.idle,
    current: 0,
    total: 0,
    message: '',
  );

  void _updateProgress(
    AnalysisStage stage,
    int current,
    int total,
    String? message,
    AnalysisCallback? callback,
  ) {
    progress = AnalysisProgress(
      stage: stage,
      current: current,
      total: total,
      message: message ?? AnalysisStatus.title(stage),
    );

    callback?.call(progress);
  }

  void pause() {
    controller.pause();
  }

  void resume() {
    controller.resume();
  }

  void cancel() {
    controller.cancel();
  }

  void reset() {
    controller.reset();

    _running = false;

    progress = const AnalysisProgress(
      stage: AnalysisStage.idle,
      current: 0,
      total: 0,
      message: '',
    );

    timelineGroups.clear();

    duplicateGroups.clear();

    mediaItems.clear();
  }

  // ===========================================================================
  // FACE DETECTION + RECOGNITION
  // ===========================================================================

  /// Detects only files that are missing from the portable face cache.
  ///
  /// The expensive model work is therefore not repeated when the user merely
  /// reopens a project or scans the same folder again.
  Future<void> detectFaces({
    required List<String> sourceRoots,
    required String databaseDirectory,
    AnalysisCallback? callback,
    bool forceRescan = false,
  }) async {
    if (mediaItems.isEmpty) return;

    final ownsRunLock = !_running;
    if (ownsRunLock) _running = true;

    try {
      final pending = await faceDatabaseService.applyCachedFaces(
        databaseDirectory: databaseDirectory,
        sourceRoots: sourceRoots,
        items: mediaItems,
        forceRescan: forceRescan,
      );

    if (pending.isEmpty) {
      _updateProgress(
        AnalysisStage.faces,
        mediaItems.length,
        mediaItems.length,
        'اطلاعات چهره از حافظه محلی بارگذاری شد.',
        callback,
      );
      return;
    }

    // Fail before writing any scan records if the recognition model is not
    // installed. This keeps the cache retryable after the user adds the model.
    await faceRecognitionEngine.initialize();

    final analyzed = <MediaItem, List<FaceInfo>>{};

    for (var index = 0; index < pending.length; index++) {
      if (!await controller.checkpoint()) return;

      final item = pending[index];

      _updateProgress(
        AnalysisStage.faces,
        index + 1,
        pending.length,
        'در حال تشخیص چهره ${index + 1} از ${pending.length}...',
        callback,
      );

      try {
        final faces = await faceRecognitionEngine.analyzeFile(item.path);
        analyzed[item] = faces;
      } catch (e, stackTrace) {
        // A corrupt/unsupported image must not abort the entire analysis.
        item.analysisMessage = 'خطا در تشخیص چهره: $e';
        analyzed[item] = const [];
        debugPrint('Face analysis failed: ${item.path} -> $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (controller.isCancelled) return;

    await faceDatabaseService.mergeAnalysis(
      databaseDirectory: databaseDirectory,
      sourceRoots: sourceRoots,
      analyzed: analyzed,
    );

      _updateProgress(
        AnalysisStage.faces,
        pending.length,
        pending.length,
        'تشخیص و دسته‌بندی چهره‌ها پایان یافت.',
        callback,
      );
    } finally {
      if (ownsRunLock) _running = false;
    }
  }

  // ===========================================================================
  // TIMELINE
  // ===========================================================================

  Future<void> _buildTimeline(AnalysisCallback? callback) async {
    timelineGroups = timelineBuilder.build(
      mediaItems,
      onProgress: (current, total, status) {
        _updateProgress(
          AnalysisStage.timeline,
          current,
          total,
          status,
          callback,
        );
      },
    );
  }

  // ===========================================================================
  // FAST BURST DETECTION
  // ===========================================================================

  /// تشخیص سریع عکس‌های پشت‌سرهم.
  ///
  /// این مرحله جایگزین pHash در آنالیز اولیه شده است.
  ///
  /// نکته مهم:
  /// هیچ تصویر خوانده نمی‌شود و هیچ pHash محاسبه نمی‌شود.
  /// فقط createdAt بررسی می‌شود.
  Future<void> _findTemporalBursts(
    AnalysisCallback? callback, {
    void Function(TimelineGroup group, List<DuplicateGroup> duplicates)?
    onGroupDuplicates,
  }) async {
    duplicateGroups.clear();

    for (int i = 0; i < timelineGroups.length; i++) {
      if (!await controller.checkpoint()) {
        return;
      }

      final group = timelineGroups[i];

      final result = await temporalBurstDetector.findBursts(
        group.items,
        controller: controller,
        maxGap: TemporalBurstDetector.defaultMaxGap,
        minGroupSize: TemporalBurstDetector.defaultMinGroupSize,
        onProgress: (current, total, status) {
          _updateProgress(
            AnalysisStage.duplicate,
            current,
            total,
            status,
            callback,
          );
        },
      );

      if (controller.isCancelled) {
        return;
      }

      duplicateGroups.addAll(result);

      // نتیجه همان گروه بلافاصله به UI ارسال می‌شود.
      onGroupDuplicates?.call(group, List<DuplicateGroup>.from(result));
    }

    _updateProgress(
      AnalysisStage.duplicate,
      mediaItems.length,
      mediaItems.length,
      'تشخیص عکس‌های پشت‌سرهم پایان یافت',
      callback,
    );
  }

  // ===========================================================================
  // MANUAL pHASH
  // ===========================================================================

  /// تحلیل دقیق تصاویر یک TimelineGroup با pHash.
  ///
  /// این متد فقط از طریق منوی کلیک راست گروه فراخوانی می‌شود.
  Future<List<DuplicateGroup>> analyzeGroupDuplicates(
    TimelineGroup group, {
    void Function(AnalysisProgress? progress)? onProgress,
  }) async {
    if (_running) {
      throw Exception('Analysis already running.');
    }

    _running = true;

    try {
      controller.reset();

      final result = await duplicateDetector.findDuplicates(
        group.items,
        controller: controller,
        onProgress: (current, total, status) {
          _updateProgress(
            AnalysisStage.duplicate,
            current,
            total,
            status,
            onProgress,
          );
        },
        groupIndex: 1,
        totalGroups: 1,
      );

      if (!controller.isCancelled) {
        bestPhotoSelector.sortDuplicates(result);

        bestPhotoSelector.selectDuplicateMasters(result);
      }

      return result;
    } finally {
      _running = false;

      progress = null;

      onProgress?.call(null);
    }
  }

  // ===========================================================================
  // MAIN ANALYSIS
  // ===========================================================================

  Future<AnalysisResult> run(
    List<MediaItem> items, {
    AnalysisCallback? onProgress,
    void Function(TimelineGroup group, List<DuplicateGroup> duplicates)?
    onGroupDuplicates,
    List<String>? sourceRootsForFaces,
    String? faceDatabaseDirectory,
  }) async {
    if (_running) {
      throw Exception('Analysis already running.');
    }

    _running = true;

    try {
      controller.reset();

      mediaItems = List<MediaItem>.from(items);

      timelineGroups.clear();

      duplicateGroups.clear();

      // -----------------------------------------------------------------------
      // TIMELINE
      // -----------------------------------------------------------------------

      _updateProgress(
        AnalysisStage.timeline,
        0,
        mediaItems.length,
        'در حال دسته بندی زمانی...',
        onProgress,
      );

      await _buildTimeline(onProgress);

      if (controller.isCancelled) {
        return AnalysisResult(
          cancelled: true,
          timelineGroups: timelineGroups,
          duplicateGroups: duplicateGroups,
        );
      }

      // -----------------------------------------------------------------------
      // FACE DETECTION / RECOGNITION
      // -----------------------------------------------------------------------

      if (sourceRootsForFaces != null && faceDatabaseDirectory != null) {
        await detectFaces(
          sourceRoots: sourceRootsForFaces!,
          databaseDirectory: faceDatabaseDirectory!,
          callback: onProgress,
        );

        if (controller.isCancelled) {
          return AnalysisResult(
            cancelled: true,
            timelineGroups: timelineGroups,
            duplicateGroups: duplicateGroups,
          );
        }
      }

      // -----------------------------------------------------------------------
      // TEMPORAL BURST DETECTION
      // -----------------------------------------------------------------------
      //
      // مهم:
      // اینجا دیگر DuplicateDetector و pHash اجرا نمی‌شوند.
      //
      // به جای آن فقط زمان عکس‌ها بررسی می‌شود.
      //

      _updateProgress(
        AnalysisStage.duplicate,
        0,
        mediaItems.length,
        'در حال تشخیص عکس‌های پشت‌سرهم...',
        onProgress,
      );

      await _findTemporalBursts(
        onProgress,
        onGroupDuplicates: onGroupDuplicates,
      );

      if (controller.isCancelled) {
        return AnalysisResult(
          cancelled: true,
          timelineGroups: timelineGroups,
          duplicateGroups: duplicateGroups,
        );
      }

      // -----------------------------------------------------------------------
      // QUALITY
      // -----------------------------------------------------------------------

      await _scorePhotos(onProgress);

      if (controller.isCancelled) {
        return AnalysisResult(
          cancelled: true,
          timelineGroups: timelineGroups,
          duplicateGroups: duplicateGroups,
        );
      }

      // -----------------------------------------------------------------------
      // BEST PHOTO
      // -----------------------------------------------------------------------

      await _selectBestPhotos(onProgress);

      if (controller.isCancelled) {
        return AnalysisResult(
          cancelled: true,
          timelineGroups: timelineGroups,
          duplicateGroups: duplicateGroups,
        );
      }

      // -----------------------------------------------------------------------
      // FINISHED
      // -----------------------------------------------------------------------

      _updateProgress(
        AnalysisStage.finished,
        mediaItems.length,
        mediaItems.length,
        'تحلیل پایان یافت.',
        onProgress,
      );

      progress = null;

      onProgress?.call(null);

      return AnalysisResult(
        cancelled: false,
        timelineGroups: timelineGroups,
        duplicateGroups: duplicateGroups,
      );
    } finally {
      _running = false;
    }
  }

  // ===========================================================================
  // BLUR
  // ===========================================================================

  Future<void> _detectBlur(AnalysisCallback? callback) async {
    int current = 0;

    for (final item in mediaItems) {
      if (!await controller.checkpoint()) {
        return;
      }

      current++;

      _updateProgress(
        AnalysisStage.blur,
        current,
        mediaItems.length,
        "در حال بررسی وضوح تصاویر...",
        callback,
      );

      if (item.isVideo) {
        continue;
      }

      item.blurScore = await blurDetector.score(item.path);
    }
  }

  // ===========================================================================
  // QUALITY
  // ===========================================================================

  Future<void> _scorePhotos(AnalysisCallback? callback) async {
    int current = 0;

    for (final item in mediaItems) {
      if (!await controller.checkpoint()) {
        return;
      }

      current++;

      _updateProgress(
        AnalysisStage.quality,
        current,
        mediaItems.length,
        "در حال امتیازدهی تصاویر...",
        callback,
      );

      if (item.isVideo) {
        continue;
      }

      item.score = qualityScorer.score(item);
    }
  }

  // ===========================================================================
  // BEST PHOTO
  // ===========================================================================

  Future<void> _selectBestPhotos(AnalysisCallback? callback) async {
    _updateProgress(
      AnalysisStage.bestPhoto,
      0,
      duplicateGroups.length,
      "در حال انتخاب بهترین تصاویر...",
      callback,
    );

    bestPhotoSelector.sortDuplicates(duplicateGroups);

    bestPhotoSelector.selectDuplicateMasters(duplicateGroups);

    bestPhotoSelector.selectTimelinePhotos(mediaItems);

    _updateProgress(
      AnalysisStage.bestPhoto,
      duplicateGroups.length,
      duplicateGroups.length,
      "بهترین تصاویر انتخاب شدند.",
      callback,
    );

    progress = null;
  }
}
