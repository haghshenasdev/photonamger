import 'dart:async';
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
import 'package:fgphoto/core/project/photon_project.dart';
import 'package:fgphoto/core/project/project_file_service.dart';
import 'package:fgphoto/core/project/project_operation.dart';
import 'package:fgphoto/core/project/project_repository.dart';

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

  PhotonProject? _project;
  String? _projectPath;

  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();

    engine = AnalysisEngine(
      controller: analysisController,
      blurDetector: BlurDetector(),
      qualityScorer: QualityScorer(),
      bestPhotoSelector: BestPhotoSelector(),
    );

    Future.microtask(_restoreLastProject);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        header: PageHeader(
          title: const Text("آرشینو - مدیریت تصاویر"),
          commandBar: AppMenu(
            onNewProject: _newProject,
            onOpenProject: _openProject,
            onSaveProject: _saveProject,
            onSaveProjectAs: _saveProjectAs,
            onResumeOperations: _resumePendingOperations,
          ),
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
                        setState(() {});
                        _scheduleProjectSave();
                      },

                      onReprocessRequested: () {
                        // مهم: وقتی زمان تغییر کرد
                        reassignGroups();
                      },

                      onAnalyzeGroupRequested: _analyzeSingleGroupDuplicates,

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
                        _scheduleProjectSave();
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
                              selectedBytes: totalSelectedBytes,
                              totalFiles: mediaItems.length,
                            ),
                          );

                      if (settings == null) {
                        return;
                      }

                      if (_projectPath == null) {
                        await _saveProjectAs();
                        if (_projectPath == null) {
                          return;
                        }
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

                        final project = _ensureProject();
                        project.applySettings = settings;

                        // ابتدا مقصد همه فایل‌ها در پروژه ثبت می‌شود.
                        // بنابراین حتی اگر قبل از اولین انتقال برق برود،
                        // مقصد عملیات بعد از اجرای بعدی مشخص است.
                        await transferService.prepareOperations(
                          groups: groups,
                          duplicateGroups: duplicateGroups,
                          settings: settings,
                          operations: project.operations,
                        );

                        await _enqueueProjectSave();

                        await transferService.execute(
                          groups: groups,
                          duplicateGroups: duplicateGroups,
                          settings: settings,
                          operations: project.operations,
                          onItemTransferred: (result) {
                            if (!mounted) return;
                            setState(() {});
                            _scheduleProjectSave();
                          },
                          onOperationChanged: (operation) {
                            if (operation.status ==
                                    ProjectOperationStatus.completed ||
                                operation.status ==
                                    ProjectOperationStatus.failed) {
                              _scheduleProjectSave();
                            }
                          },
                          onProgress: (p) {
                            if (!mounted) return;

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

                        await _enqueueProjectSave();

                        if (!mounted) return;

                        setState(() {
                          progress = null;
                        });
                      } catch (e, stackTrace) {
                        debugPrint('Transfer error: $e');
                        debugPrintStack(stackTrace: stackTrace);

                        await _enqueueProjectSave();

                        if (!mounted) return;

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
                const SizedBox(width: 8),
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
      _scheduleProjectSave();

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

  int get totalSelectedBytes {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      selectedDuplicateFiles.add(_normalizePath(group.primary.path));
      for (final item in group.items) {
        duplicateFiles.add(_normalizePath(item.path));
      }
    }

    int total = 0;

    for (final timeline in groups) {
      for (final item in timeline.items) {
        final key = _normalizePath(item.path);
        final shouldTransfer = duplicateFiles.contains(key)
            ? selectedDuplicateFiles.contains(key)
            : item.isSelected;

        if (shouldTransfer) {
          total += item.fileSize;
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

    _ensureProject().sourcePaths = List<String>.from(sourcePaths);
    _scheduleProjectSave();
  }

  Future<void> removeSourceFolder(String path) async {
    setState(() {
      sourcePaths.remove(path);
    });

    _ensureProject().sourcePaths = List<String>.from(sourcePaths);
    _scheduleProjectSave();
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

    final project = _ensureProject();
    project.sourcePaths = List<String>.from(sourcePaths);
    project.mediaItems = mediaItems;
    project.groups = groups;
    project.duplicateGroups = [];
    project.operations.clear();
    project.applySettings = null;
    project.analysisCompleted = false;

    await _enqueueProjectSave();

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

  Future<void> _analyzeSingleGroupDuplicates(TimelineGroup group) async {
    if (engine.isRunning) {
      return;
    }

    setState(() {
      progress = const AnalysisProgress(
        stage: AnalysisStage.duplicate,
        current: 0,
        total: 0,
        message: 'در حال بررسی تصاویر تکراری گروه...',
      );
    });

    try {
      final result = await engine.analyzeGroupDuplicates(
        group,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            progress = p;
          });
        },
      );

      if (!mounted) return;

      final groupPaths = group.items
          .map((item) => _normalizePath(item.path))
          .toSet();

      setState(() {
        duplicateGroups.removeWhere(
          (duplicate) => duplicate.items.any(
            (item) => groupPaths.contains(_normalizePath(item.path)),
          ),
        );
        duplicateGroups.addAll(result);
        selectedGroup = group;
        progress = null;
      });

      _scheduleProjectSave();

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('تحلیل گروه انجام شد'),
            content: Text(
              result.isEmpty
                  ? 'تصویر تکراری در این گروه پیدا نشد.'
                  : '${result.length} گروه تصویر تکراری پیدا شد.',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Single group duplicate analysis error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        progress = null;
      });

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در تحلیل گروه'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
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

    if (mounted) {
      setState(() {
        duplicateGroups = [];
      });
    }

    final result = await engine.run(
      mediaItems,
      onGroupDuplicates: (group, duplicates) {
        if (!mounted) return;

        final groupPaths = group.items
            .map((item) => _normalizePath(item.path))
            .toSet();

        setState(() {
          // نتیجه این گروه را همان لحظه جایگزین می‌کنیم؛
          // نتیجه گروه‌های قبلی دست‌نخورده باقی می‌ماند.
          duplicateGroups.removeWhere(
            (duplicate) => duplicate.items.any(
              (item) => groupPaths.contains(_normalizePath(item.path)),
            ),
          );
          duplicateGroups.addAll(duplicates);
        });

        _scheduleProjectSave();
      },
      onProgress: (p) {
        if (!mounted) {
          return;
        }

        setState(() {
          progress = p;
        });

        // نتایج تحلیل تا همین لحظه هم در پروژه قابل بازیابی هستند.
        _scheduleProjectSave();
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

    final project = _ensureProject();
    project.sourcePaths = List<String>.from(sourcePaths);
    project.mediaItems = mediaItems;
    project.groups = groups;
    project.duplicateGroups = duplicateGroups;
    project.analysisCompleted = true;

    await _enqueueProjectSave();
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

    _ensureProject()
      ..groups = groups
      ..analysisCompleted = true;
    _scheduleProjectSave();
  }

  void resetTimeline() {
    final builder = TimelineBuilder();

    final generatedGroups = builder.build(mediaItems);

    setState(() {
      groups = generatedGroups;

      selectedGroup = generatedGroups.isNotEmpty ? generatedGroups.first : null;
    });

    _ensureProject()
      ..groups = groups
      ..analysisCompleted = true;
    _scheduleProjectSave();
  }

  PhotonProject _ensureProject() {
    return _project ??= PhotonProject.empty('پروژه جدید');
  }

  void _syncProjectState() {
    final project = _ensureProject();

    project.sourcePaths = List<String>.from(sourcePaths);
    project.mediaItems = mediaItems;
    project.groups = groups;
    project.duplicateGroups = duplicateGroups;
  }

  Future<void> _saveCurrentProjectNow() async {
    if (_projectPath == null) return;

    _syncProjectState();

    await ProjectRepository.save(
      path: _projectPath!,
      project: _ensureProject(),
    );

    await ProjectRepository.rememberProjectPath(_projectPath!);
  }

  Future<void> _enqueueProjectSave() {
    if (_projectPath == null) return Future<void>.value();

    final next = _saveQueue.then(
      (_) => _saveCurrentProjectNow(),
      onError: (_) => _saveCurrentProjectNow(),
    );

    _saveQueue = next;
    return next;
  }

  void _scheduleProjectSave() {
    if (_projectPath == null) return;

    _saveTimer?.cancel();

    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      _enqueueProjectSave();
    });
  }

  Future<void> _saveProject() async {
    if (_projectPath == null) {
      await _saveProjectAs();
      return;
    }

    try {
      await _enqueueProjectSave();

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('پروژه ذخیره شد'),
            content: Text(_projectPath!),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در ذخیره پروژه'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
  }

  Future<void> _saveProjectAs() async {
    try {
      _syncProjectState();

      final path = await ProjectFileService.saveProjectAs(_ensureProject());

      if (path == null) return;

      setState(() {
        _projectPath = path;
      });

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('پروژه ذخیره شد'),
            content: Text(path),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در ذخیره پروژه'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
  }

  Future<void> _newProject() async {
    setState(() {
      sourcePaths = [];
      mediaItems = [];
      groups = [];
      duplicateGroups = [];
      selectedGroup = null;
      progress = null;

      _project = PhotonProject.empty('پروژه جدید');
      _projectPath = null;
    });
  }

  Future<void> _openProject() async {
    final path = await ProjectFileService.openProjectPath();
    if (path == null) return;

    await _loadProjectFromPath(path, showRecoveryPrompt: true);
  }

  Future<void> _restoreLastProject() async {
    try {
      final path = await ProjectRepository.readLastProjectPath();

      if (path == null || path.trim().isEmpty) return;
      if (!await File(path).exists()) return;

      await _loadProjectFromPath(path, showRecoveryPrompt: true);
    } catch (e) {
      debugPrint('Last project restore error: $e');
    }
  }

  Future<void> _loadProjectFromPath(
    String path, {
    required bool showRecoveryPrompt,
  }) async {
    try {
      final project = await ProjectRepository.load(path);

      if (!mounted) return;

      setState(() {
        _project = project;
        _projectPath = path;

        sourcePaths = List<String>.from(project.sourcePaths);
        mediaItems = project.mediaItems;
        groups = project.groups;
        duplicateGroups = project.duplicateGroups;
        selectedGroup = groups.isEmpty ? null : groups.first;
        progress = null;
      });

      await ProjectRepository.rememberProjectPath(path);

      if (showRecoveryPrompt) {
        await _offerPendingOperations();
      }
    } catch (e, stackTrace) {
      debugPrint('Project load error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در باز کردن پروژه'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
  }

  Future<void> _offerPendingOperations() async {
    final project = _project;
    if (project == null) return;

    final pending = project.operations
        .where((operation) => !operation.isFinished)
        .toList();

    if (pending.isEmpty) return;

    if (project.applySettings == null) {
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('عملیات ناتمام پیدا شد'),
            content: const Text(
              'فایل پروژه عملیات ناتمام دارد، اما تنظیمات انتقال آن در پروژه موجود نیست.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    if (!mounted) return;

    final shouldResume = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('عملیات ناتمام پیدا شد'),
          content: Text(
            '${pending.length} عملیات انتقال/کپی از این پروژه کامل نشده است.\n\n'
            'آیا می‌خواهید از همان جایی که عملیات متوقف شده ادامه دهید؟',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ادامه عملیات'),
            ),
            Button(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('بعداً'),
            ),
          ],
        );
      },
    );

    if (shouldResume == true) {
      await _resumePendingOperations();
    }
  }

  Future<void> _resumePendingOperations() async {
    final project = _project;

    if (project == null || _projectPath == null) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('پروژه‌ای باز نیست'),
            content: const Text('ابتدا یک فایل پروژه را باز یا ذخیره کنید.'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    final baseSettings = project.applySettings;

    if (baseSettings == null) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('تنظیمات انتقال موجود نیست'),
            content: const Text(
              'برای ادامه عملیات قبلی، تنظیمات انتقال در پروژه ذخیره نشده است.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
      return;
    }

    final pending = project.operations
        .where((operation) => !operation.isFinished)
        .toList();

    if (pending.isEmpty) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('عملیات ناتمامی وجود ندارد'),
            content: const Text('تمام عملیات انتقال این پروژه کامل شده‌اند.'),
            severity: InfoBarSeverity.info,
            onClose: close,
          );
        },
      );
      return;
    }

    final transferService = TransferService();

    setState(() {
      progress = const AnalysisProgress(
        stage: AnalysisStage.finished,
        current: 0,
        total: 0,
        message: 'در حال بازیابی عملیات...',
      );
    });

    try {
      // عملیات Move و Copy ممکن است هر دو در یک پروژه وجود داشته باشند.
      for (final move in [true, false]) {
        final hasPendingType = pending.any(
          (operation) =>
              operation.type ==
                  (move
                      ? ProjectOperationType.move
                      : ProjectOperationType.copy) &&
              !operation.isFinished,
        );

        if (!hasPendingType) continue;

        final settings = baseSettings.copyWith(moveFiles: move);

        await transferService.execute(
          groups: groups,
          duplicateGroups: duplicateGroups,
          settings: settings,
          operations: project.operations,
          saveMetadata: false,
          onItemTransferred: (result) {
            if (!mounted) return;
            setState(() {});
            _scheduleProjectSave();
          },
          onOperationChanged: (operation) {
            if (operation.status == ProjectOperationStatus.completed ||
                operation.status == ProjectOperationStatus.failed) {
              _scheduleProjectSave();
            }
          },
          onProgress: (p) {
            if (!mounted) return;

            setState(() {
              progress = AnalysisProgress(
                stage: AnalysisStage.finished,
                current: p.current,
                total: p.total,
                message: 'در حال ادامه ${p.fileName}',
              );
            });
          },
        );
      }

      await _enqueueProjectSave();

      if (!mounted) return;

      setState(() {
        progress = null;
      });

      final remaining = project.operations
          .where((operation) => !operation.isFinished)
          .length;

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: remaining == 0
                ? const Text('عملیات کامل شد')
                : const Text('عملیات متوقف شد'),
            content: Text(
              remaining == 0
                  ? 'همه عملیات ناتمام با موفقیت بررسی و تکمیل شدند.'
                  : '$remaining عملیات هنوز کامل نشده‌اند و برای Resume بعدی در پروژه باقی می‌مانند.',
            ),
            severity: remaining == 0
                ? InfoBarSeverity.success
                : InfoBarSeverity.warning,
            onClose: close,
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Resume error: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _enqueueProjectSave();

      if (!mounted) return;

      setState(() {
        progress = null;
      });

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در ادامه عملیات'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
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
