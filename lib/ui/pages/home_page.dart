import 'dart:io';

import 'package:fgphoto/core/analysis/analysis_progress.dart';
import 'package:fgphoto/core/analysis/analysis_stage.dart';
import 'package:fgphoto/core/folder_service.dart';
import 'package:fgphoto/core/media_scanner.dart';
import 'package:fgphoto/core/timeline_builder.dart';
import 'package:fgphoto/core/utils/persian_date.dart';
import 'package:fgphoto/ui/dialogs/transfer_dialog.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fgphoto/core/apply/transfer_service.dart';

import '../widgets/folder_selector.dart';
import '../widgets/timeline_group_card.dart';
import '../widgets/media_grid.dart';
import '../widgets/duplicate_group_card.dart';
import '../widgets/apply_bar.dart';

import 'package:fgphoto/core/analysis/analysis_engine.dart';
import 'package:fgphoto/core/analysis/blur_detector.dart';
import 'package:fgphoto/core/analysis/best_photo_selector.dart';
import 'package:fgphoto/core/analysis/quality_scorer.dart';
import 'package:path/path.dart' as p;
import 'package:fgphoto/core/apply/folder_builder.dart';

import 'package:fgphoto/core/analysis/analysis_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AnalysisController analysisController = AnalysisController();
  String folderPath = "";

  String selectedFolder = '';

  List<MediaItem> mediaItems = [];

  List<TimelineGroup> groups = [];

  TimelineGroup? selectedGroup;

  List<DuplicateGroup> duplicateGroups = [];

  AnalysisProgress? progress;

  late final AnalysisEngine engine;

  @override
  void initState() {
    super.initState();

    engine = AnalysisEngine(
      controller: analysisController,
      blurDetector: BlurDetector(),
      qualityScorer: QualityScorer(),
      bestPhotoSelector: BestPhotoSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        header: const PageHeader(title: Text("مدیریت تصاویر")),
        content: Column(
          children: [
            FolderSelector(path: folderPath, onSelect: selectFolder),

            const SizedBox(height: 12),

            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 350,
                    child: TimelineGroupCard(
                      groups: groups,
                      selectedGroup: selectedGroup,
                      onResetTimeline: () {
                        resetTimeline();
                      },

                      onGroupSelected: (group) {
                        setState(() {
                          selectedGroup = group;
                        });
                      },

                      onGroupUpdated: (group) {
                        // اگر مستقیم تغییر دادی، timeline رو rebuild کن
                        setState(() {});
                      },

                      onReprocessRequested: () {
                        // مهم: وقتی زمان تغییر کرد
                        reassignGroups();
                      },

                      onGroupsMerged: (selectedGroups) {
                        mergeGroups(selectedGroups);
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(flex: 2, child: MediaGrid(items: buildGridItems())),

                  const SizedBox(width: 12),

                  SizedBox(
                    width: 350,
                    child: DuplicateGroupCard(groups: duplicateGroups),
                  ),
                ],
              ),
            ),

            ApplyBar(
              onApply: () async {
                final ApplySettings? settings = await showDialog<ApplySettings>(
                  context: context,
                  builder: (_) => TransferDialog(
                    groupCount: groups.length,
                    selectedFiles: totalSelectedFiles,
                    totalFiles: mediaItems.length,
                  ),
                );

                if (settings == null) {
                  return;
                }

                final transferService = TransferService();

                await transferService.execute(
                  groups: groups,
                  duplicateGroups: duplicateGroups,
                  settings: settings,

                  onProgress: (p) {
                    setState(() {
                      progress = AnalysisProgress(
                        stage: AnalysisStage.finished,
                        current: p.current,
                        total: p.total,
                        message: "در حال انتقال ${p.fileName}",
                      );
                    });
                  },
                );
              },

              mediaItems_length: mediaItems.length,

              progress: progress,
              onPause: pauseAnalyze,

              onResume: resumeAnalyze,

              onCancel: cancelAnalyze,
            ),
          ],
        ),
      ),
    );
  }

  int get totalSelectedFiles {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(group.primary.path);

      for (final item in group.items) {
        duplicateFiles.add(item.path);
      }
    }

    int total = 0;

    for (final timeline in groups) {
      for (final item in timeline.items) {
        if (duplicateFiles.contains(item.path)) {
          if (selectedDuplicateFiles.contains(item.path)) {
            total++;
          }
        } else {
          if (item.isSelected) {
            total++;
          }
        }
      }
    }

    return total;
  }

  Future<void> selectFolder() async {
    final path = await FolderService.pickFolder();

    if (path == null) {
      return;
    }

    final scanner = MediaScanner();

    final files = await scanner.scanFolder(path);

    final timelineBuilder = TimelineBuilder();

    final generatedGroups = timelineBuilder.build(files);

    setState(() {
      folderPath = path;

      mediaItems = files;

      groups = generatedGroups;

      selectedGroup = generatedGroups.isNotEmpty ? generatedGroups.first : null;
    });

    await analyze();
  }

  Future<void> analyze() async {
    final result = await engine.run(
      mediaItems,
      onProgress: (p) {
        setState(() {
          progress = p;
        });
      },
    );

    if (result.cancelled) {
      return;
    }

    setState(() {
      groups = result.timelineGroups;

      duplicateGroups = result.duplicateGroups;

      selectedGroup = groups.isEmpty ? null : groups.first;
    });
  }

  List<GridItem> buildGridItems() {
    if (selectedGroup == null) {
      return [];
    }

    final result = <GridItem>[];

    final groupItems = selectedGroup!.items;

    final duplicateFiles = <String>{};

    for (final dupGroup in duplicateGroups) {
      for (final item in dupGroup.items) {
        duplicateFiles.add(item.path);
      }
    }

    for (final dupGroup in duplicateGroups) {
      bool exists = dupGroup.items.any((e) => groupItems.contains(e));

      if (exists) {
        result.add(GridItem.duplicate(dupGroup));
      }
    }

    for (final item in groupItems) {
      if (duplicateFiles.contains(item.path)) {
        continue;
      }

      result.add(GridItem.media(item));
    }

    return result;
  }

  void reassignGroups() {
    if (groups.isEmpty) return;

    // مرتب کردن گروه‌ها
    groups.sort((a, b) => a.start.compareTo(b.start));

    // جلوگیری از همپوشانی بازه‌ها
    for (int i = 0; i < groups.length - 1; i++) {
      final current = groups[i];
      final next = groups[i + 1];

      if (!current.end.isBefore(next.start)) {
        next.start = current.end.add(const Duration(seconds: 1));
      }

      if (next.start.isAfter(next.end)) {
        next.end = next.start;
      }
    }

    // پاک کردن اعضای گروه‌ها
    for (final g in groups) {
      g.items.clear();
    }

    // توزیع دوباره عکس‌ها
    for (final item in mediaItems) {
      for (final group in groups) {
        if (!item.createdAt.isBefore(group.start) &&
            !item.createdAt.isAfter(group.end)) {
          group.items.add(item);
          break;
        }
      }
    }

    // حذف گروه‌های خالی
    groups.removeWhere((g) => g.items.isEmpty);

    setState(() {
      if (selectedGroup != null) {
        selectedGroup = groups.firstWhere(
          (g) => g.title == selectedGroup!.title,
          orElse: () => groups.first,
        );
      }
    });
  }

  void mergeGroups(List<TimelineGroup> selectedGroups) {
    if (selectedGroups.length < 2) return;

    // 1. مرتب‌سازی بر اساس زمان شروع
    final sorted = [...selectedGroups]
      ..sort((a, b) => a.start.compareTo(b.start));

    final mergedItemsMap = <String, MediaItem>{};

    DateTime minStart = sorted.first.start;
    DateTime maxEnd = sorted.first.end;

    TimelineGroup? previous;

    for (final group in sorted) {
      // 2. تشخیص overlap منطقی
      if (previous != null) {
        final gap = group.start.difference(previous.end).inMinutes;

        // اگر فاصله خیلی زیاد باشد، merge منطقی نیست
        if (gap > 60 * 12) {
          // بیش از 12 ساعت فاصله → هشدار منطقی
          continue;
        }
      }

      // 3. جمع‌آوری آیتم‌ها بدون duplicate
      for (final item in group.items) {
        mergedItemsMap[item.path] = item;
      }

      // 4. آپدیت بازه زمانی
      if (group.start.isBefore(minStart)) {
        minStart = group.start;
      }

      if (group.end.isAfter(maxEnd)) {
        maxEnd = group.end;
      }

      previous = group;
    }

    final mergedItems = mergedItemsMap.values.toList();

    // 6. ساخت گروه جدید
    final mergedGroup = TimelineGroup(
      title: 'Merged (${selectedGroups.length})',
      start: minStart,
      end: maxEnd,
      items: mergedItems,
    );

    // 7. حذف گروه‌های merge شده
    final remainingGroups = groups
        .where((g) => !selectedGroups.contains(g))
        .toList();

    remainingGroups.add(mergedGroup);

    setState(() {
      groups = remainingGroups;
      selectedGroup = mergedGroup;
    });
  }

  void resetTimeline() {
    final builder = TimelineBuilder();

    final generatedGroups = builder.build(mediaItems);

    setState(() {
      groups = generatedGroups;

      selectedGroup = generatedGroups.isNotEmpty ? generatedGroups.first : null;
    });
  }

  void pauseAnalyze() {
    analysisController.pause();

    setState(() {});
  }

  void resumeAnalyze() {
    analysisController.resume();

    setState(() {});
  }

  void cancelAnalyze() {
    analysisController.cancel();
  }
}
