import 'dart:io';

import 'package:fgphoto/core/analysis/analysis_progress.dart';
import 'package:fgphoto/core/analysis/analysis_stage.dart';
import 'package:fgphoto/core/folder_service.dart';
import 'package:fgphoto/core/media_scanner.dart';
import 'package:fgphoto/core/metadata/metadata_service.dart';
import 'package:fgphoto/core/timeline_builder.dart';
import 'package:fgphoto/ui/dialogs/transfer_dialog.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fgphoto/ui/widgets/app_menu.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
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

import 'package:fgphoto/core/analysis/analysis_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AnalysisController analysisController = AnalysisController();

  List<String> sourcePaths = [];
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
        header: const PageHeader(
          title: Text("آرشینو - مدیریت تصاویر"),
          commandBar: const AppMenu(),
        ),
        content: Column(
          children: [
            FolderSelector(
              paths: sourcePaths,
              onAdd: addSourceFolder,
              onRemove: removeSourceFolder,
            ),
            FilledButton(
              onPressed: sourcePaths.isEmpty ? null : scanSourceFolders,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.search, size: 16),
                  SizedBox(width: 8),
                  Text('شروع اسکن و آنالیز'),
                ],
              ),
            ),
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

                  Expanded(
                    flex: 2,
                    child: MediaGrid(
                      items: buildGridItems(),
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  SizedBox(
                    width: 350,
                    child: DuplicateGroupCard(
                      groups: duplicateGroups,
                      onGroupTap: _openDuplicateGroup,
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ApplyBar(
                    onApply: () async {
                      final ApplySettings? settings =
                          await showDialog<ApplySettings>(
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

                      try {
                        if (mounted) {
                          setState(() {
                            progress = const AnalysisProgress(
                              stage: AnalysisStage.finished,
                              current: 0,
                              total: 0,
                              message: 'در حال آماده‌سازی انتقال...',
                            );
                          });
                        }

                        await transferService.execute(
                          groups: groups,
                          duplicateGroups: duplicateGroups,
                          settings: settings,
                          onItemTransferred: (result) {
                            if (!mounted) {
                              return;
                            }

                            setState(() {});
                          },
                          onProgress: (p) {
                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              progress = AnalysisProgress(
                                stage: AnalysisStage.finished,
                                current: p.current,
                                total: p.total,
                                message: 'در حال انتقال ${p.fileName}',
                              );
                            });
                          },
                        );

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          progress = null;
                        });
                      } catch (e, stackTrace) {
                        debugPrint('Transfer error: $e');

                        debugPrintStack(stackTrace: stackTrace);

                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          progress = null;
                        });

                        await displayInfoBar(
                          context,
                          builder: (context, close) {
                            return InfoBar(
                              title: const Text('خطا در انتقال فایل'),
                              content: Text(e.toString()),
                              severity: InfoBarSeverity.error,
                              onClose: close,
                            );
                          },
                        );
                      }
                    },
                    mediaItems_length: mediaItems.length,
                    progress: progress,
                    onPause: pauseAnalyze,
                    onResume: resumeAnalyze,
                    onCancel: cancelAnalyze,
                  ),
                ),

                const SizedBox(width: 8),

                Button(
                  onPressed: groups.any((group) => group.edited)
                      ? _saveMetadataOnly
                      : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.save, size: 16),
                      SizedBox(width: 8),
                      Text('ذخیره اطلاعات'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDuplicateGroup(DuplicateGroup duplicateGroup) async {
    // پیدا کردن TimelineGroup مربوط به این DuplicateGroup
    TimelineGroup? targetTimeline;

    for (final timelineGroup in groups) {
      final containsDuplicate = timelineGroup.items.any((mediaItem) {
        return duplicateGroup.items.any(
          (duplicateItem) => duplicateItem.path == mediaItem.path,
        );
      });

      if (containsDuplicate) {
        targetTimeline = timelineGroup;
        break;
      }
    }

    if (targetTimeline == null) {
      return;
    }

    // اگر گروه مربوط به Timeline دیگری است،
    // همان Timeline را فعال می‌کنیم.
    if (!identical(selectedGroup, targetTimeline)) {
      setState(() {
        selectedGroup = targetTimeline;
      });

      // صبر می‌کنیم UI با Timeline جدید rebuild شود.
      await Future<void>.delayed(Duration.zero);
    }

    // دقیقاً همان previewItems که MediaGrid استفاده می‌کند
    final gridItems = buildGridItems();

    final previewItems = gridItems.map((item) {
      if (item.isDuplicateGroup) {
        return PreviewItem.duplicate(item.duplicateGroup!);
      }

      return PreviewItem.media(item.media!);
    }).toList();

    // پیدا کردن همان گروه داخل previewItems
    final initialIndex = previewItems.indexWhere((item) {
      return item.isDuplicate && identical(item.duplicate, duplicateGroup);
    });

    if (initialIndex < 0 || !mounted) {
      return;
    }

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return ImagePreviewDialog(
          items: previewItems,
          initialIndex: initialIndex,
        );
      },
    );

    if (changed == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _saveMetadataOnly() async {
    final editedGroups = groups
        .where(
          (group) =>
              group.edited &&
              group.metadata != null &&
              group.metadataDirectory != null &&
              group.metadataDirectory!.trim().isNotEmpty,
        )
        .toList();

    if (editedGroups.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('تغییری برای ذخیره وجود ندارد'),
            content: const Text(
              'گروه ویرایش‌شده‌ای که مسیر پوشه آن مشخص باشد پیدا نشد.',
            ),
            severity: InfoBarSeverity.info,
            onClose: close,
          );
        },
      );

      return;
    }

    try {
      const metadataService = MetadataService();

      int savedCount = 0;

      for (final group in editedGroups) {
        final directoryPath = group.metadataDirectory!.trim();

        final directory = Directory(directoryPath);

        if (!await directory.exists()) {
          continue;
        }

        await metadataService.save(
          directoryPath: directoryPath,
          metadata: group.metadata!,
        );

        group.edited = false;

        savedCount++;
      }

      if (!mounted) {
        return;
      }

      setState(() {});

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('ذخیره شد'),
            content: Text(
              'اطلاعات $savedCount گروه در پوشه اصلی خودشان ذخیره شد.',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Metadata save error: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در ذخیره اطلاعات'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
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

  Future<void> addSourceFolder() async {
    final path = await FolderService.pickFolder();

    if (path == null || path.trim().isEmpty) {
      return;
    }

    final normalizedPath = _normalizePath(path);

    //------------------------------------------------------
    // مسیر تکراری
    //------------------------------------------------------

    final alreadyExists = sourcePaths.any(
      (existingPath) => _normalizePath(existingPath) == normalizedPath,
    );

    if (alreadyExists) {
      return;
    }

    //------------------------------------------------------
    // اگر مسیر انتخاب‌شده داخل یکی از مسیرهای قبلی است
    //------------------------------------------------------

    final insideExisting = sourcePaths.any((existingPath) {
      return _isPathInside(normalizedPath, _normalizePath(existingPath));
    });

    if (insideExisting) {
      return;
    }

    //------------------------------------------------------
    // اگر مسیر جدید والد یکی از مسیرهای قبلی است،
    // مسیرهای کوچک‌تر را حذف می‌کنیم.
    //------------------------------------------------------

    sourcePaths.removeWhere((existingPath) {
      return _isPathInside(_normalizePath(existingPath), normalizedPath);
    });

    //------------------------------------------------------
    // اضافه کردن
    //------------------------------------------------------

    setState(() {
      sourcePaths.add(path);
    });
  }

  Future<void> removeSourceFolder(String path) async {
    setState(() {
      sourcePaths.remove(path);
    });
  }

  Future<void> scanSourceFolders() async {
    if (sourcePaths.isEmpty) {
      setState(() {
        mediaItems = [];
        groups = [];
        duplicateGroups = [];
        selectedGroup = null;
        progress = null;
      });

      return;
    }

    final scanner = MediaScanner();

    //------------------------------------------------------
    // Scan تمام مسیرها
    //------------------------------------------------------

    final files = await scanner.scanFolders(sourcePaths);

    //------------------------------------------------------
    // Timeline اولیه
    //------------------------------------------------------

    final timelineBuilder = TimelineBuilder();

    final generatedGroups = timelineBuilder.build(files);

    if (!mounted) {
      return;
    }

    setState(() {
      mediaItems = files;

      groups = generatedGroups;

      duplicateGroups = [];

      selectedGroup = generatedGroups.isNotEmpty ? generatedGroups.first : null;
    });

    //------------------------------------------------------
    // Analysis
    //------------------------------------------------------

    await analyze();
  }

  String _normalizePath(String path) {
    var value = path.replaceAll('\\', '/').trim();

    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    return value.toLowerCase();
  }

  bool _isPathInside(String child, String parent) {
    if (child == parent) {
      return false;
    }

    final normalizedChild = child.endsWith('/') ? child : '$child/';

    final normalizedParent = parent.endsWith('/') ? parent : '$parent/';

    return normalizedChild.startsWith(normalizedParent);
  }

  Future<void> analyze() async {
    final oldGroups = groups;

    final metadataByDirectory = <String, TimelineGroup>{};

    for (final group in oldGroups) {
      final directory = group.metadataDirectory;

      if (directory == null) {
        continue;
      }

      metadataByDirectory[_normalizePath(directory)] = group;
    }

    final result = await engine.run(
      mediaItems,
      onProgress: (p) {
        if (!mounted) {
          return;
        }

        setState(() {
          progress = p;
        });
      },
    );

    if (result.cancelled) {
      return;
    }

    final analyzedGroups = result.timelineGroups;

    for (final group in analyzedGroups) {
      final directory = group.metadataDirectory;

      if (directory == null) {
        continue;
      }

      final oldGroup = metadataByDirectory[_normalizePath(directory)];

      if (oldGroup == null) {
        continue;
      }

      group.metadata = oldGroup.metadata;

      group.metadataDirectory = oldGroup.metadataDirectory;

      group.edited = oldGroup.edited;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      groups = analyzedGroups;

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
