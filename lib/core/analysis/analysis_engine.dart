import '../../ui/models/duplicate_group.dart';
import '../../ui/models/media_item.dart';
import '../../ui/models/timeline_group.dart';

import '../duplicate_detector.dart';
import '../timeline_builder.dart';

import 'analysis_callback.dart';
import 'analysis_controller.dart';
import 'analysis_progress.dart';
import 'analysis_result.dart';
import 'analysis_stage.dart';
import 'analysis_status.dart';
import 'blur_detector.dart';

import 'face_detector.dart';
import 'quality_scorer.dart';
import 'best_photo_selector.dart';

class AnalysisEngine {
  final AnalysisController controller;
  final BlurDetector blurDetector;
  final QualityScorer qualityScorer;
  final BestPhotoSelector bestPhotoSelector;

  final TimelineBuilder timelineBuilder;
  final FaceDetectorService faceDetector;

  final DuplicateDetector duplicateDetector;

  AnalysisEngine({
    required this.controller,
    TimelineBuilder? timelineBuilder,
    DuplicateDetector? duplicateDetector,
    required this.blurDetector,
    FaceDetectorService? faceDetector,
    required this.qualityScorer,
    required this.bestPhotoSelector,
  }) : timelineBuilder = timelineBuilder ?? TimelineBuilder(),
       faceDetector = faceDetector ?? FaceDetectorService(),

       duplicateDetector = duplicateDetector ?? DuplicateDetector();

  List<TimelineGroup> timelineGroups = [];

  List<DuplicateGroup> duplicateGroups = [];

  List<MediaItem> mediaItems = [];

  bool _running = false;

  bool get isRunning => _running;

  AnalysisProgress progress = const AnalysisProgress(
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

  Future<void> _findDuplicates(AnalysisCallback? callback) async {

    
    duplicateGroups = await duplicateDetector.findDuplicates(
      mediaItems,
      controller: controller,
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
  }

  Future<AnalysisResult> run(
    List<MediaItem> items, {
    AnalysisCallback? onProgress,
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

      _updateProgress(
        AnalysisStage.duplicate,
        0,
        mediaItems.length,
        'در حال پیدا کردن تصاویر تکراری...',
        onProgress,
      );

      await _findDuplicates(onProgress);
      // await _detectBlur(onProgress);
      // await _detectFaces(onProgress);
      await _scorePhotos(onProgress);
      await _selectBestPhotos(onProgress);

      if (controller.isCancelled) {
        return AnalysisResult(
          cancelled: true,
          timelineGroups: timelineGroups,
          duplicateGroups: duplicateGroups,
        );
      }

      _updateProgress(
        AnalysisStage.finished,
        mediaItems.length,
        mediaItems.length,
        'تحلیل پایان یافت.',
        onProgress,
      );

      // faceDetector.dispose();

      return AnalysisResult(
        cancelled: false,
        timelineGroups: timelineGroups,
        duplicateGroups: duplicateGroups,
      );
    } finally {
      _running = false;
    }
  }

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
  }
}
