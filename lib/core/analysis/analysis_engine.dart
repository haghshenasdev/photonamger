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

import 'quality_scorer.dart';
import 'best_photo_selector.dart';

class AnalysisEngine {
  final AnalysisController controller;

  final BlurDetector blurDetector;

  final QualityScorer qualityScorer;

  final BestPhotoSelector bestPhotoSelector;

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
  }) : timelineBuilder = timelineBuilder ?? TimelineBuilder(),
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
  // FACE DETECTION
  // ===========================================================================

  Future<void> _detectFaces(AnalysisCallback? callback) async {
    int current = 0;

    for (final item in mediaItems) {
      if (!await controller.checkpoint()) {
        return;
      }

      current++;

      _updateProgress(
        AnalysisStage.faces,
        current,
        mediaItems.length,
        "در حال تشخیص چهره...",
        callback,
      );

      if (item.isVideo) {
        continue;
      }

      // item.faces = await faceDetector.detect(item);
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
