import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:fgphoto/core/analysis/analysis_progress.dart';
import 'package:fgphoto/core/analysis/analysis_stage.dart';
import 'package:fgphoto/core/folder_service.dart';
import 'package:fgphoto/core/media_scanner.dart';
import 'package:fgphoto/core/metadata/metadata_service.dart';
import 'package:fgphoto/core/timeline_builder.dart';
import 'package:fgphoto/ui/dialogs/transfer_dialog.dart';
import 'package:fgphoto/ui/pages/statistics_page.dart';
import 'package:fgphoto/ui/models/statistics_snapshot.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fgphoto/ui/widgets/app_menu.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fgphoto/core/apply/transfer_service.dart';
import 'package:fgphoto/core/apply/folder_builder.dart';
import 'package:fgphoto/core/project/photon_project.dart';
import 'package:fgphoto/core/project/project_file_service.dart';
import 'package:fgphoto/core/project/project_operation.dart';
import 'package:fgphoto/core/project/project_repository.dart';

import '../widgets/folder_selector.dart';
import '../widgets/timeline_group_card.dart';
import '../widgets/media_grid.dart';
import '../widgets/duplicate_group_card.dart';
import '../widgets/apply_bar.dart';
import '../widgets/face_people_panel.dart';
import '../widgets/category_suggestion_dialog.dart';

import 'package:fgphoto/core/analysis/analysis_engine.dart';
import 'package:fgphoto/core/analysis/blur_detector.dart';
import 'package:fgphoto/core/analysis/best_photo_selector.dart';
import 'package:fgphoto/core/analysis/quality_scorer.dart';

import 'package:fgphoto/core/analysis/analysis_controller.dart';
import 'package:fgphoto/core/analysis/face_database.dart';
import 'package:fgphoto/core/metadata/category_learning_service.dart';
import 'package:fgphoto/core/portable/portable_project_database_service.dart';

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

  FaceDatabase _faceDatabase = FaceDatabase();
  String? _faceDatabaseDirectory;
  String? _workingDatabaseDirectory;
  List<List<String>> _categoryCatalogPaths = <List<String>>[];
  String? _selectedFacePersonId;
  int _rightPanelTab = 0;
  List<FaceMergeSuggestion> _faceMergeSuggestions = const [];
  final Set<String> _dismissedFaceMergeSuggestions = <String>{};

  // Portable archive currently associated with the opened source folders.
  String? _portableArchiveRoot;
  PortableProjectSnapshot? _portableSnapshot;
  List<DuplicateGroup> _cachedPortableDuplicateGroups = const [];
  Set<String> _cachedPortableAnalysisPaths = <String>{};
  bool _faceDatabaseDirty = false;

  CategoryLearningModel _categoryLearningModel = const CategoryLearningModel();

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
    unawaited(engine.faceRecognitionEngine.dispose());
    super.dispose();
  }

  String _getFaceDatabaseDirectory() {
    if (_workingDatabaseDirectory != null &&
        _workingDatabaseDirectory!.trim().isNotEmpty) {
      return _workingDatabaseDirectory!;
    }

    if (_projectPath != null && _projectPath!.trim().isNotEmpty) {
      return File(_projectPath!).parent.path;
    }

    if (sourcePaths.isNotEmpty) {
      return sourcePaths.first;
    }

    return Directory.systemTemp.path;
  }

  Future<void> _ensureWorkingDatabaseDirectory() async {
    if (_workingDatabaseDirectory != null &&
        _workingDatabaseDirectory!.trim().isNotEmpty) {
      await Directory(_workingDatabaseDirectory!).create(recursive: true);
      return;
    }

    if (_projectPath != null && _projectPath!.trim().isNotEmpty) {
      _workingDatabaseDirectory = File(_projectPath!).parent.path;
      await Directory(_workingDatabaseDirectory!).create(recursive: true);
      return;
    }

    final safeId = DateTime.now().microsecondsSinceEpoch.toString();
    _workingDatabaseDirectory = p.join(
      Directory.systemTemp.path,
      'Archino',
      'working_$safeId',
    );
    await Directory(_workingDatabaseDirectory!).create(recursive: true);
  }

  Future<void> _loadFaceDatabase() async {
    await _ensureWorkingDatabaseDirectory();

    final directory = _getFaceDatabaseDirectory();
    const service = FaceDatabaseService();

    final db = await service.load(directory);

    if (!mounted) return;

    final suggestions = service.findMergeSuggestions(db);

    setState(() {
      _faceDatabaseDirectory = directory;
      _faceDatabase = db;
      _faceMergeSuggestions = suggestions;
    });
  }

  Future<void> _importArchiveFromDisk() async {
    final root = await FolderService.pickFolder();
    if (root == null || root.trim().isEmpty) return;

    try {
      await _ensureWorkingDatabaseDirectory();

      const portable = PortableProjectDatabaseService();
      final working = await const FaceDatabaseService().load(
        _getFaceDatabaseDirectory(),
      );

      var snapshot = await portable.importIntoWorkingDatabase(
        root: root,
        workingDatabase: working,
        workingDatabaseDirectory: _getFaceDatabaseDirectory(),
        currentCategoryPaths: _categoryCatalogPaths,
        currentLearningModel: _categoryLearningModel,
      );

      // Backward compatibility: older builds stored face information as
      // .archino_faces.json in the selected archive tree.
      if (snapshot == null) {
        final legacyService = const FaceDatabaseService();
        final changed = await legacyService.importPortableArchives(
          sourceRoots: [root],
          database: working,
        );

        if (changed || working.persons.isNotEmpty || working.faces.isNotEmpty) {
          await legacyService.save(_getFaceDatabaseDirectory(), working);

          snapshot = PortableProjectSnapshot(
            database: working,
            categoryPaths: _categoryCatalogPaths,
            learningModel: _categoryLearningModel,
          );
        }
      }

      if (snapshot == null) {
        throw StateError(
          'در مسیر انتخاب‌شده دیتابیس archino.sqlite یا آرشیو قدیمی قابل استفاده پیدا نشد.',
        );
      }

      final importedSnapshot = snapshot;
      final learning = CategoryLearningService();
      final currentGroupsModel = learning.rebuild(groups);
      final mergedLearning = learning.merge(
        importedSnapshot.learningModel,
        currentGroupsModel,
      );

      if (!mounted) return;

      _portableArchiveRoot = root;
      _portableSnapshot = importedSnapshot;
      _cachedPortableDuplicateGroups =
          await const PortableProjectDatabaseService().bindDuplicateGroups(
            snapshot: importedSnapshot,
            items: mediaItems,
          );
      _cachedPortableAnalysisPaths =
          await const PortableProjectDatabaseService().bindAnalysisPaths(
            snapshot: importedSnapshot,
            items: mediaItems,
          );

      setState(() {
        _faceDatabase = importedSnapshot.database;
        _faceDatabaseDirectory = _getFaceDatabaseDirectory();
        _faceMergeSuggestions = const FaceDatabaseService()
            .findMergeSuggestions(_faceDatabase);
        _categoryCatalogPaths = _uniqueCategoryPaths([
          ..._categoryCatalogPaths,
          ...importedSnapshot.categoryPaths,
          ..._categoryPathsFromGroups(),
        ]);
        _categoryLearningModel = mergedLearning;
      });

      await learning.save(_getFaceDatabaseDirectory(), mergedLearning);
      _scheduleProjectSave();

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('اطلاعات آرشیو بارگذاری شد'),
          content: Text(
            '${_faceDatabase.persons.length} شخص، '
            '${_categoryCatalogPaths.length} مسیر دسته‌بندی از آرشیو خوانده شد.',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Archive import error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در بارگذاری آرشیو'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  List<List<String>> _categoryPathsFromGroups() {
    final result = <List<String>>[];
    for (final group in groups) {
      for (final path in group.categories) {
        result.add(List<String>.from(path));
      }
    }
    return result;
  }

  List<List<String>> _uniqueCategoryPaths(Iterable<List<String>> paths) {
    final result = <String, List<String>>{};

    for (final raw in paths) {
      final path = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (path.isEmpty) continue;

      final key = path
          .map(
            (e) => e
                .toLowerCase()
                .replaceAll('ي', 'ی')
                .replaceAll('ى', 'ی')
                .replaceAll('ك', 'ک')
                .replaceAll(RegExp(r'\s+'), ' '),
          )
          .join('\u0000');

      result.putIfAbsent(key, () => path);
    }

    return result.values.toList();
  }

  Future<void> _loadCategoryLearningModel() async {
    await _ensureWorkingDatabaseDirectory();

    final directory = _getFaceDatabaseDirectory();
    const service = CategoryLearningService();
    final model = await service.load(directory);

    final merged = service.merge(model, service.rebuild(groups));

    if (!mounted) return;

    setState(() {
      _categoryLearningModel = merged;
      _categoryCatalogPaths = _uniqueCategoryPaths([
        ..._categoryCatalogPaths,
        ..._categoryPathsFromGroups(),
      ]);
    });
  }

  Future<void> _suggestCategoriesFromTitles() async {
    if (groups.isEmpty) return;

    final directory = _projectPath != null && _projectPath!.trim().isNotEmpty
        ? File(_projectPath!).parent.path
        : (sourcePaths.isNotEmpty ? sourcePaths.first : Directory.current.path);

    const service = CategoryLearningService();

    // همیشه قبل از پیشنهاد، آخرین دسته‌بندی‌های دستی پروژه را وارد مدل می‌کنیم.
    final model = service.merge(
      _categoryLearningModel,
      service.rebuild(groups),
    );

    if (model.rules.isEmpty) {
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('مدل دسته‌بندی هنوز آموزشی ندارد'),
          content: const Text(
            'ابتدا چند گروه را به‌صورت دستی دسته‌بندی کنید تا آرشینو '
            'از عنوان و دسته‌بندی‌های واقعی پروژه الگو یاد بگیرد.',
          ),
          severity: InfoBarSeverity.info,
          onClose: close,
        ),
      );
      return;
    }

    await service.save(directory, model);

    if (!mounted) return;

    final applied = await showDialog<int>(
      context: context,
      builder: (_) => CategorySuggestionDialog(
        groups: groups,
        model: model,
        service: service,
      ),
    );

    if (applied == null || !mounted) return;

    setState(() {
      _categoryLearningModel = service.rebuild(groups);
    });

    await service.save(directory, _categoryLearningModel);

    if (applied > 0) {
      _scheduleProjectSave();
    }

    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('پیشنهاد دسته‌بندی'),
        content: Text(
          applied == 0
              ? 'هیچ دسته‌بندی‌ای اعمال نشد.'
              : '$applied گروه دسته‌بندی شد.',
        ),
        severity: applied == 0 ? InfoBarSeverity.info : InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Future<void> _renameFacePerson(String personId, String name) async {
    final directory = _faceDatabaseDirectory ?? _getFaceDatabaseDirectory();

    await const FaceDatabaseService().renamePerson(
      databaseDirectory: directory,
      personId: personId,
      name: name,
      sourceRoots: sourcePaths,
    );

    _faceDatabaseDirty = true;
    await _loadFaceDatabase();
    if (mounted) setState(() {});
  }

  Future<void> _rejectFaceAssignment(MediaItem item, String personId) async {
    final directory = _faceDatabaseDirectory ?? _getFaceDatabaseDirectory();

    try {
      await const FaceDatabaseService().rejectFaceForPerson(
        databaseDirectory: directory,
        imagePath: item.path,
        personId: personId,
        sourceRoots: sourcePaths,
      );

      // Remove only the rejected person from the in-memory item.
      item.faces.removeWhere((face) => face.personId == personId);
      item.faceCount = item.faces.length;

      _faceDatabaseDirty = true;
      await _loadFaceDatabase();

      if (!mounted) return;

      setState(() {});

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('اصلاح تشخیص چهره'),
          content: Text(
            'چهره این عکس دیگر به «${_facePersonName(personId) ?? 'این شخص'}» نسبت داده نمی‌شود.',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );

      _scheduleProjectSave();
    } catch (e, stackTrace) {
      debugPrint('Reject face assignment error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در اصلاح تشخیص'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _clearFaceRejection(MediaItem item, String personId) async {
    final directory = _faceDatabaseDirectory ?? _getFaceDatabaseDirectory();

    try {
      await const FaceDatabaseService().clearFaceRejection(
        databaseDirectory: directory,
        imagePath: item.path,
        personId: personId,
        sourceRoots: sourcePaths,
      );

      if (!mounted) return;

      // The next explicit face analysis will decide the identity again.
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('اصلاح قبلی لغو شد'),
          content: const Text(
            'این محدودیت حذف شد. برای تشخیص دوباره، «آنالیز چهره» را اجرا کنید.',
          ),
          severity: InfoBarSeverity.info,
          onClose: close,
        ),
      );

      _faceDatabaseDirty = true;
      await _loadFaceDatabase();
      setState(() {});
      _scheduleProjectSave();
    } catch (e, stackTrace) {
      debugPrint('Clear face rejection error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در لغو اصلاح'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  bool _isSystemFaceName(String value) {
    final name = value.trim();
    return name.isEmpty ||
        name == 'شخص' ||
        RegExp(r'^شخص\s+\d+$').hasMatch(name);
  }

  Future<void> _mergeFacePersons(
    String primaryPersonId,
    String secondaryPersonId,
  ) async {
    if (primaryPersonId == secondaryPersonId) return;

    var primaryId = primaryPersonId;
    var secondaryId = secondaryPersonId;
    FacePerson? first;
    FacePerson? second;
    for (final person in _faceDatabase.persons) {
      if (person.id == primaryId) first = person;
      if (person.id == secondaryId) second = person;
    }
    if (first == null || second == null) return;

    final firstSystem = _isSystemFaceName(first.name);
    final secondSystem = _isSystemFaceName(second.name);
    String chosenName;

    if (firstSystem && !secondSystem) {
      // شخص نام‌گذاری‌شده را مقصد نگه می‌داریم، حتی اگر در UI سمت دوم باشد.
      primaryId = second.id;
      secondaryId = first.id;
      chosenName = second.name.trim();
    } else if (!firstSystem && secondSystem) {
      chosenName = first.name.trim();
    } else if (firstSystem && secondSystem) {
      chosenName = first.name.trim().isNotEmpty ? first.name.trim() : 'شخص';
    } else {
      // هر دو نام دستی هستند؛ تنها در این حالت از کاربر می‌پرسیم کدام نام بماند.
      final selectedName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('انتخاب نام برای ادغام'),
          content: Text(
            'هر دو شخص نام دستی دارند. کدام نام حفظ شود؟\n\n۱) ${first?.name}\n۲) ${second?.name}',
          ),
          actions: [
            Button(
              child: Text(first!.name),
              onPressed: () => Navigator.pop(dialogContext, first?.name),
            ),
            Button(
              child: Text(second!.name),
              onPressed: () => Navigator.pop(dialogContext, second?.name),
            ),
            Button(
              child: const Text('لغو'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      if (selectedName == null) return;
      chosenName = selectedName;
      if (selectedName == second.name) {
        primaryId = second.id;
        secondaryId = first.id;
      }
    }

    final directory = _faceDatabaseDirectory ?? _getFaceDatabaseDirectory();

    try {
      // ============================================================
      // 1. ابتدا ادغام را در Face Database انجام می‌دهیم.
      //
      // تمام StoredFaceهای شخص دوم به شخص اصلی منتقل می‌شوند.
      // ============================================================
      await const FaceDatabaseService().mergePersons(
        databaseDirectory: directory,
        primaryPersonId: primaryId,
        secondaryPersonId: secondaryId,
        preferredName: chosenName,
        sourceRoots: sourcePaths,
      );

      if (!mounted) return;

      // ============================================================
      // 2. بسیار مهم:
      //
      // MediaItemهای موجود در حافظه هنوز personId قدیمی را دارند.
      // آنها را هم اصلاح می‌کنیم تا People و Grid بلافاصله
      // بعد از Merge با Database هماهنگ باشند.
      // ============================================================

      void updateFaces(List<MediaItem> items) {
        for (final item in items) {
          for (final face in item.faces) {
            if (face.personId == secondaryId) {
              face.personId = primaryId;
            }
          }
        }
      }

      // Mediaهای اصلی
      updateFaces(mediaItems);

      // ============================================================
      // Duplicate Groups
      //
      // برای اطمینان، آیتم‌های داخل Duplicate Groupها را هم
      // جداگانه اصلاح می‌کنیم.
      // ============================================================
      for (final group in duplicateGroups) {
        updateFaces(group.items);
      }

      // ============================================================
      // 3. اگر شخص دوم انتخاب شده بود، انتخاب را به شخص اصلی منتقل
      // می‌کنیم.
      // ============================================================
      setState(() {
        if (_selectedFacePersonId == secondaryId) {
          _selectedFacePersonId = primaryId;
        }

        // اگر شخص اصلی یا شخص دوم در لیست انتخاب merge بودند،
        // وضعیت UI را پاک می‌کنیم.
      });

      // ============================================================
      // 4. Database را دوباره Load می‌کنیم.
      //
      // این کار باعث می‌شود:
      // - شخص دوم از persons حذف شده باشد
      // - نام شخص اصلی حفظ شده باشد
      // - پیشنهادهای Merge دوباره محاسبه شوند
      // ============================================================
      _faceDatabaseDirty = true;
      await _loadFaceDatabase();

      if (!mounted) return;

      // ============================================================
      // 5. پروژه را بعد از اصلاح MediaItemها ذخیره می‌کنیم.
      //
      // این قسمت بسیار مهم است؛ چون اگر قبل از اصلاح MediaItemها
      // پروژه ذخیره شود، personId قدیمی دوباره داخل project JSON
      // ذخیره می‌شود.
      // ============================================================
      await _enqueueProjectSave();

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('ادغام افراد انجام شد'),
          content: const Text('تمام چهره‌های شخص دوم به شخص اصلی منتقل شدند.'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Face person merge error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در ادغام افراد'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  List<GridItem> _buildFaceGridItems() {
    final personId = _selectedFacePersonId;
    if (personId == null) return [];

    // Keep DuplicateGroup behavior intact in the people view too.
    // A duplicate file must not appear once as a normal media tile and once
    // inside its duplicate stack.
    final result = <GridItem>[];
    final duplicateFiles = <String>{};

    for (final duplicateGroup in duplicateGroups) {
      final containsPerson = duplicateGroup.items.any(
        (item) => item.faces.any((face) => face.personId == personId),
      );

      if (!containsPerson) continue;

      result.add(GridItem.duplicate(duplicateGroup));

      for (final item in duplicateGroup.items) {
        duplicateFiles.add(_normalizePath(item.path));
      }
    }

    for (final item in mediaItems) {
      if (duplicateFiles.contains(_normalizePath(item.path))) {
        continue;
      }

      if (item.faces.any((face) => face.personId == personId)) {
        result.add(GridItem.media(item));
      }
    }

    return result;
  }

  String? _facePersonName(String personId) {
    for (final person in _faceDatabase.persons) {
      if (person.id == personId) return person.name;
    }
    return null;
  }

  Future<void> _searchFaceByImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty || !mounted) return;

    try {
      final detected = await engine.faceRecognitionEngine.analyzeFile(path);
      if (detected.isEmpty) {
        if (!mounted) return;
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('چهره‌ای پیدا نشد'),
            content: const Text(
              'در تصویر انتخاب‌شده چهره قابل تشخیصی پیدا نشد.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
        return;
      }

      const service = FaceDatabaseService();
      FaceMatchResult? best;

      for (final face in detected) {
        final match = service.findBestPerson(_faceDatabase, face.embedding);
        if (match == null) continue;
        if (best == null || match.similarity > best.similarity) {
          best = match;
        }
      }

      if (best == null) {
        if (!mounted) return;
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('شخص مشابه پیدا نشد'),
            content: const Text(
              'چهره انتخاب‌شده با افراد ذخیره‌شده تطبیق کافی نداشت.',
            ),
            severity: InfoBarSeverity.info,
            onClose: close,
          ),
        );
        return;
      }

      _selectFacePerson(best.person.id);

      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('شخص پیدا شد: ${best!.person.name}'),
          content: Text('شباهت: ${(best.similarity * 100).round()}٪'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Face image search error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در جستجوی چهره'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  void _selectFacePerson(String? personId) {
    setState(() {
      _selectedFacePersonId = personId;
      if (personId != null) {
        _rightPanelTab = 1;
      }
    });
  }

  String _mergeSuggestionKey(FaceMergeSuggestion suggestion) {
    final ids = [suggestion.firstPersonId, suggestion.secondPersonId]..sort();
    return '${ids[0]}|${ids[1]}';
  }

  FacePerson? _facePersonById(String? id) {
    if (id == null) return null;
    for (final person in _faceDatabase.persons) {
      if (person.id == id) return person;
    }
    return null;
  }

  FaceMergeSuggestion? get _activePersonMergeSuggestion {
    final selected = _selectedFacePersonId;
    if (selected == null) return null;
    for (final suggestion in _faceMergeSuggestions) {
      if (_dismissedFaceMergeSuggestions.contains(_mergeSuggestionKey(suggestion))) continue;
      if (suggestion.firstPersonId == selected || suggestion.secondPersonId == selected) {
        return suggestion;
      }
    }
    return null;
  }

  Future<void> _handleMergeSuggestion(bool samePerson) async {
    final suggestion = _activePersonMergeSuggestion;
    final selected = _selectedFacePersonId;
    if (suggestion == null || selected == null) return;
    if (samePerson) {
      final other = suggestion.firstPersonId == selected
          ? suggestion.secondPersonId
          : suggestion.firstPersonId;
      await _mergeFacePersons(selected, other);
    } else {
      setState(() => _dismissedFaceMergeSuggestions.add(_mergeSuggestionKey(suggestion)));
    }
  }

  Widget _buildActiveMergeSuggestionCard(FaceMergeSuggestion suggestion) {
    final selected = _facePersonById(_selectedFacePersonId);
    final otherId = suggestion.firstPersonId == _selectedFacePersonId
        ? suggestion.secondPersonId
        : suggestion.firstPersonId;
    final other = _facePersonById(otherId);
    if (selected == null || other == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        padding: const EdgeInsets.all(10),
        child: Row(
        children: [
          const Icon(FluentIcons.lightbulb, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'پیشنهاد ادغام: «${selected.name}» با «${other.name}» '
              '(${(suggestion.similarity * 100).round()}٪ شباهت). همین شخص است؟',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: () => _handleMergeSuggestion(false),
            child: const Text('خیر، بعدی'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => _handleMergeSuggestion(true),
            child: const Text('بله، ادغام'),
          ),
        ],
        ),
      ),
    );
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
            onImportArchive: _importArchiveFromDisk,
            onShowStatistics: _showStatistics,
          ),
        ),
        content: Column(
          children: [
            FolderSelector(
              paths: sourcePaths,
              onAdd: addSourceFolder,
              onRemove: removeSourceFolder,
              onScan: scanSourceFolders,
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
                          _selectedFacePersonId = null;
                        });
                      },

                      onGroupUpdated: (group) {
                        setState(() {
                          _categoryCatalogPaths = _uniqueCategoryPaths([
                            ..._categoryCatalogPaths,
                            ...group.categories,
                          ]);
                        });
                        _scheduleProjectSave();
                      },

                      onReprocessRequested: () {
                        // مهم: وقتی زمان تغییر کرد
                        reassignGroups();
                      },

                      onAnalyzeGroupRequested: _analyzeSingleGroupDuplicates,
                      onAnalyzeGroupFacesRequested: _analyzeGroupFacesOnly,

                      onGroupsMerged: (selectedGroups) {
                        mergeGroups(selectedGroups);
                      },
                      onSuggestCategories: _suggestCategoriesFromTitles,
                      availableCategoryPaths: _categoryCatalogPaths,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (_selectedFacePersonId != null && _activePersonMergeSuggestion != null)
                          _buildActiveMergeSuggestionCard(_activePersonMergeSuggestion!),
                        Expanded(
                          child: MediaGrid(
                            items: _selectedFacePersonId != null
                                ? _buildFaceGridItems()
                                : buildGridItems(),
                            selectedPersonId: _selectedFacePersonId,
                            onFaceSelected: _selectFacePerson,
                            faceNameResolver: _facePersonName,
                            faceDatabase: _faceDatabase,
                            onFaceAssignmentRejected: _rejectFaceAssignment,
                            onFaceRejectionCleared: _clearFaceRejection,
                            onChanged: () {
                              setState(() {});
                              _scheduleProjectSave();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  SizedBox(
                    width: 350,
                    child: TabView(
                      currentIndex: _rightPanelTab,
                      onChanged: (index) {
                        setState(() {
                          _rightPanelTab = index;
                          if (index != 1) {
                            _selectedFacePersonId = null;
                          }
                        });
                      },
                      closeButtonVisibility: CloseButtonVisibilityMode.never,
                      showScrollButtons: false,
                      tabs: [
                        Tab(
                          icon: const Icon(FluentIcons.copy, size: 14),
                          text: const Text('پشت‌سرهم'),
                          body: DuplicateGroupCard(
                            groups: duplicateGroups,
                            onGroupTap: _openDuplicateGroup,
                          ),
                        ),
                        Tab(
                          icon: const Icon(FluentIcons.contact, size: 14),
                          text: const Text('افراد'),
                          body: FacePeoplePanel(
                            database: _faceDatabase,
                            sourceRoots: sourcePaths,
                            selectedPersonId: _selectedFacePersonId,
                            onPersonSelected: _selectFacePerson,
                            onRename: _renameFacePerson,
                            onMerge: _mergeFacePersons,
                            suggestions: _faceMergeSuggestions,
                            onSearchByImage: _searchFaceByImage,
                          ),
                        ),
                      ],
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
                              statistics: StatisticsSnapshot.from(
                                items: mediaItems,
                                groups: groups,
                                duplicateGroups: duplicateGroups,
                              ),
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

                        final transferResults = await transferService.execute(
                          groups: groups,
                          duplicateGroups: duplicateGroups,
                          settings: settings,
                          operations: project.operations,
                          sourceRoots: sourcePaths,
                          faceDatabaseDirectory: _getFaceDatabaseDirectory(),
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

                        await const PortableProjectDatabaseService().syncToRoot(
                          root: settings.outputFolder,
                          workingDatabase: _faceDatabase,
                          transferredItems: transferResults
                              .map((result) => result.item)
                              .toList(),
                          categoryPaths: _uniqueCategoryPaths([
                            ..._categoryCatalogPaths,
                            ..._categoryPathsFromGroups(),
                          ]),
                          learningModel: CategoryLearningService().merge(
                            _categoryLearningModel,
                            CategoryLearningService().rebuild(groups),
                          ),
                          duplicateGroups: duplicateGroups,
                          analyzedItems: transferResults
                              .map((result) => result.item)
                              .toList(),
                        );

                        await _enqueueProjectSave();

                        if (!mounted) return;

                        setState(() {
                          _categoryCatalogPaths = _uniqueCategoryPaths([
                            ..._categoryCatalogPaths,
                            ..._categoryPathsFromGroups(),
                          ]);
                          progress = null;
                          _faceDatabaseDirty = false;
                          _portableArchiveRoot = settings.outputFolder;
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
                  onPressed: mediaItems.isEmpty || engine.isRunning
                      ? null
                      : _analyzeFacesOnly,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.contact, size: 16),
                      SizedBox(width: 8),
                      Text('تشخیص چهره'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                Button(
                  onPressed:
                      groups.any((group) => group.edited) || _faceDatabaseDirty
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
          onFaceSelected: _selectFacePerson,
          faceNameResolver: _facePersonName,
        );
      },
    );

    if (changed == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _saveInformationToPortableArchive({List<MediaItem> transferredItems = const []}) async {
    var root = _portableArchiveRoot;

    if (root == null || root.trim().isEmpty) {
      root = await FolderService.pickFolder();
      if (root == null || root.trim().isEmpty) return;
      final portable = const PortableProjectDatabaseService();
      if (!await portable.exists(root)) {
        await Directory(root).create(recursive: true);
      }
    }

    try {
      final portable = const PortableProjectDatabaseService();
      await portable.syncToRoot(
        root: root!,
        workingDatabase: _faceDatabase,
        transferredItems: transferredItems,
        categoryPaths: _uniqueCategoryPaths([
          ..._categoryCatalogPaths,
          ..._categoryPathsFromGroups(),
        ]),
        learningModel: CategoryLearningService().merge(
          _categoryLearningModel,
          CategoryLearningService().rebuild(groups),
        ),
        duplicateGroups: duplicateGroups,
        analyzedItems: mediaItems,
      );

      _portableArchiveRoot = root;
      _faceDatabaseDirty = false;

      if (!mounted) return;
      setState(() {});

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('اطلاعات روی هارد ذخیره شد'),
          content: Text('دیتابیس آرشینو در $root به‌روزرسانی شد.'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Portable information save error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در ذخیره اطلاعات روی هارد'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<List<MediaItem>> _renameEditedGroupFolders(
    List<TimelineGroup> editedGroups,
  ) async {
    final renamedItems = <MediaItem>[];

    for (final group in editedGroups) {
      final oldPath = group.metadataDirectory?.trim();
      if (oldPath == null || oldPath.isEmpty) continue;

      final oldDirectory = Directory(oldPath);
      if (!await oldDirectory.exists()) continue;

      final oldName = p.basename(oldDirectory.path);
      final newName = FolderBuilder.renamedGroupFolderName(
        group: group,
        oldDirectoryName: oldName,
      );

      if (newName.trim().isEmpty || newName == oldName) continue;

      final parent = oldDirectory.parent;
      final targetPath = p.join(parent.path, newName);
      final target = Directory(targetPath);

      if (await target.exists()) {
        if (!mounted) continue;
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('تغییر نام پوشه انجام نشد'),
            content: Text(
              'پوشه «$newName» از قبل در مسیر ${parent.path} وجود دارد.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
        continue;
      }

      try {
        await oldDirectory.rename(targetPath);

        for (final item in group.items) {
          final normalizedItem = item.path.replaceAll('\\', '/');
          final normalizedOld = oldDirectory.path.replaceAll('\\', '/');
          final lowerItem = normalizedItem.toLowerCase();
          final lowerOld = normalizedOld.toLowerCase();

          if (lowerItem == lowerOld ||
              lowerItem.startsWith('$lowerOld/')) {
            final relative = normalizedItem.substring(normalizedOld.length)
                .replaceFirst(RegExp(r'^[/\\]+'), '');
            item.updatePath(p.join(targetPath, relative));
            renamedItems.add(item);
          }
        }

        group.metadataDirectory = targetPath;
        group.edited = true;
      } catch (e, stackTrace) {
        debugPrint('Group folder rename error: $e');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) continue;
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('خطا در تغییر نام پوشه'),
            content: Text('$oldName → $newName\n$e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }

    return renamedItems;
  }

  Future<void> _saveMetadataOnly() async {
    final editedGroups = groups
        .where(
          (group) =>
              group.edited ||
              group.metadata?.groupDate != null,
        )
        .toList();

    final renamedItems = await _renameEditedGroupFolders(editedGroups);

    final hasFaceChanges = _faceDatabaseDirty;

    if (hasFaceChanges || renamedItems.isNotEmpty) {
      await _saveInformationToPortableArchive(
        transferredItems: renamedItems,
      );
    }

    final groupsToSave = groups
        .where(
          (group) =>
              group.edited &&
              group.metadata != null &&
              group.metadataDirectory != null &&
              group.metadataDirectory!.trim().isNotEmpty,
        )
        .toList();

    if (groupsToSave.isEmpty) {
      if (hasFaceChanges || renamedItems.isNotEmpty) {
        if (!mounted) return;
        setState(() {});
        _scheduleProjectSave();
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('ذخیره شد'),
            content: Text(
              renamedItems.isNotEmpty
                  ? 'نام پوشه و اطلاعات آرشیو روی هارد به‌روزرسانی شد.'
                  : 'اطلاعات چهره روی هارد ذخیره شد.',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
      return;
    }

    try {
      const metadataService = MetadataService();
      int savedCount = 0;

      for (final group in groupsToSave) {
        final directoryPath = group.metadataDirectory!.trim();
        final directory = Directory(directoryPath);

        if (!await directory.exists()) continue;

        await metadataService.save(
          directoryPath: directoryPath,
          metadata: group.metadata!,
        );

        // نام پوشه، تاریخ گروه و دسته‌بندی همگی اکنون در همین metadata
        // ثبت شده‌اند و در Scan بعدی دوباره بازیابی می‌شوند.
        group.edited = false;
        savedCount++;
      }

      if (renamedItems.isNotEmpty) {
        // بعد از Rename، مسیرهای جدید در دیتابیس قابل‌حمل نیز ثبت شوند.
        await _saveInformationToPortableArchive(
          transferredItems: renamedItems,
        );
      }

      if (!mounted) return;

      setState(() {});
      _scheduleProjectSave();

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('ذخیره شد'),
          content: Text(
            '$savedCount گروه ذخیره شد'
            '${renamedItems.isNotEmpty ? ' و ${renamedItems.length} فایل با مسیر جدید ثبت شد.' : '.'}',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Metadata save error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در ذخیره اطلاعات'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _showStatistics() async {
    final snapshot = StatisticsSnapshot.from(
      items: mediaItems,
      groups: groups,
      duplicateGroups: duplicateGroups,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => StatisticsPage(stats: snapshot),
      ),
    );
  }


  int get totalSelectedFiles {
    final selectedDuplicateFiles = <String>{};
    final duplicateFiles = <String>{};

    for (final group in duplicateGroups) {
      for (final index in group.selectedIndices) {
        if (index >= 0 && index < group.items.length) {
          selectedDuplicateFiles.add(group.items[index].path);
        }
      }

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
      for (final index in group.selectedIndices) {
        if (index >= 0 && index < group.items.length) {
          selectedDuplicateFiles.add(_normalizePath(group.items[index].path));
        }
      }

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
      _selectedFacePersonId = null;
    });

    _ensureProject().sourcePaths = List<String>.from(sourcePaths);
    _scheduleProjectSave();
  }

  Future<void> removeSourceFolder(String path) async {
    setState(() {
      sourcePaths.remove(path);
      _selectedFacePersonId = null;
    });

    _ensureProject().sourcePaths = List<String>.from(sourcePaths);
    _scheduleProjectSave();
  }

  Future<PortableProjectSnapshot?> _loadPortableArchiveForSources(
    List<MediaItem> items,
  ) async {
    final portable = const PortableProjectDatabaseService();
    final root = await portable.findArchiveRoot(sourcePaths);

    if (root == null) {
      _portableArchiveRoot = null;
      _portableSnapshot = null;
      _cachedPortableDuplicateGroups = const [];
      _cachedPortableAnalysisPaths = <String>{};
      return null;
    }

    await _ensureWorkingDatabaseDirectory();
    final working = await const FaceDatabaseService().load(
      _getFaceDatabaseDirectory(),
    );

    final snapshot = await portable.importIntoWorkingDatabase(
      root: root,
      workingDatabase: working,
      workingDatabaseDirectory: _getFaceDatabaseDirectory(),
      currentCategoryPaths: _categoryCatalogPaths,
      currentLearningModel: _categoryLearningModel,
    );

    if (snapshot == null) return null;

    _portableArchiveRoot = root;
    _portableSnapshot = snapshot;
    _cachedPortableDuplicateGroups = await portable.bindDuplicateGroups(
      snapshot: snapshot,
      items: items,
    );
    _cachedPortableAnalysisPaths = await portable.bindAnalysisPaths(
      snapshot: snapshot,
      items: items,
    );

    _faceDatabase = snapshot.database;
    _faceDatabaseDirectory = _getFaceDatabaseDirectory();
    _faceMergeSuggestions = const FaceDatabaseService().findMergeSuggestions(
      _faceDatabase,
    );
    _categoryCatalogPaths = _uniqueCategoryPaths([
      ..._categoryCatalogPaths,
      ...snapshot.categoryPaths,
    ]);

    final learning = const CategoryLearningService();
    _categoryLearningModel = learning.merge(
      _categoryLearningModel,
      snapshot.learningModel,
    );

    return snapshot;
  }

  Future<Map<String, bool>?> _showAnalysisSettings() async {
    final values = <String, bool>{
      'timeline': true,
      'faces': true,
      'bursts': true,
      'quality': true,
      'best': true,
    };
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('تنظیمات تحلیل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مشخص کنید کدام پردازش‌ها اجرا شوند:'),
              const SizedBox(height: 8),
              for (final option in const <(String, String)>[
                ('timeline', 'دسته‌بندی زمانی تصاویر'),
                ('bursts', 'تشخیص تصاویر پشت‌سرهم و مشابه زمانی'),
                ('faces', 'تشخیص و دسته‌بندی چهره‌ها'),
                ('quality', 'امتیازدهی کیفیت و تاری تصاویر'),
                ('best', 'انتخاب بهترین عکس هر گروه'),
              ])
                Row(
                  children: [
                    Checkbox(
                      checked: values[option.$1] ?? false,
                      onChanged: (value) => setDialogState(
                        () => values[option.$1] = value ?? false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(option.$2)),
                  ],
                ),
            ],
          ),
          actions: [
            Button(
              child: const Text('انصراف'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              child: const Text('شروع تحلیل'),
              onPressed: values.values.any((v) => v)
                  ? () => Navigator.pop(dialogContext, Map<String, bool>.from(values))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> scanSourceFolders() async {
    final analysisOptions = await _showAnalysisSettings();
    if (analysisOptions == null) return;
    if (sourcePaths.isEmpty) {
      setState(() {
        mediaItems = [];
        groups = [];
        duplicateGroups = [];
        selectedGroup = null;
        _selectedFacePersonId = null;
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
      _selectedFacePersonId = null;
    });

    _faceDatabaseDirectory = _getFaceDatabaseDirectory();

    // اگر مسیر انتخابی روی هارد قبلاً آرشیو شده باشد، دیتابیس مرکزی همان
    // هارد قبل از شروع آنالیز وارد workspace می‌شود. در نتیجه تشخیص چهره
    // و تشخیص تکراری‌ها فقط برای فایل‌هایی که cache ندارند اجرا خواهد شد.
    try {
      await _loadPortableArchiveForSources(files);
    } catch (e, stackTrace) {
      debugPrint('Portable archive auto-load error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _loadFaceDatabase();
    await _loadCategoryLearningModel();

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

    await analyze(options: analysisOptions);
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

  Future<void> _analyzeGroupFacesOnly(TimelineGroup group) async {
    if (engine.isRunning || group.items.isEmpty) return;
    setState(() => progress = const AnalysisProgress(
      stage: AnalysisStage.faces,
      current: 0,
      total: 0,
      message: 'در حال تشخیص چهره‌های این گروه...',
    ));
    try {
      await engine.detectFaces(
        sourceRoots: sourcePaths,
        databaseDirectory: _getFaceDatabaseDirectory(),
        onlyItems: group.items,
        forceRescan: false,
        callback: (p) {
          if (mounted) setState(() => progress = p);
        },
      );
      await _loadFaceDatabase();
      await _enqueueProjectSave();
      if (!mounted) return;
      setState(() => progress = null);
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('تشخیص چهره گروه پایان یافت'),
          content: Text('تعداد تصاویر گروه: ${group.items.length}. چهره‌های جدید به پایگاه چهره‌های کلی اضافه شدند.'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Group face analysis error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => progress = null);
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('خطا در تشخیص چهره گروه'),
          content: Text(e.toString()),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _analyzeFacesOnly() async {
    if (mediaItems.isEmpty || engine.isRunning) return;

    setState(() {
      progress = const AnalysisProgress(
        stage: AnalysisStage.faces,
        current: 0,
        total: 0,
        message: 'در حال آماده‌سازی تشخیص چهره...',
      );
    });

    try {
      await engine.detectFaces(
        sourceRoots: sourcePaths,
        databaseDirectory: _getFaceDatabaseDirectory(),
        // تحلیل عادی باید همیشه از cache/portable archive استفاده کند.
        // برای بازتحلیل اجباری می‌توان بعداً یک فرمان جداگانه اضافه کرد.
        forceRescan: false,
        callback: (p) {
          if (!mounted) return;
          setState(() => progress = p);
        },
      );

      await _loadFaceDatabase();
      await _enqueueProjectSave();

      if (!mounted) return;

      setState(() => progress = null);

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('تشخیص چهره انجام شد'),
            content: Text(
              '${_faceDatabase.persons.length} نفر و '
              '${_faceDatabase.faces.length} چهره در حافظه محلی ثبت شده است.',
            ),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Face analysis error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => progress = null);

      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('خطا در تشخیص چهره'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        },
      );
    }
  }

  Future<void> analyze({Map<String, bool>? options}) async {
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

    try {
      final result = await engine.run(
        mediaItems,
        sourceRootsForFaces: sourcePaths,
        faceDatabaseDirectory: _getFaceDatabaseDirectory(),
        cachedDuplicateGroups: _cachedPortableDuplicateGroups,
        cachedAnalysisPaths: _cachedPortableAnalysisPaths,
        analyzeTimeline: options?['timeline'] ?? true,
        analyzeFaces: options?['faces'] ?? true,
        analyzeBursts: options?['bursts'] ?? true,
        analyzeQuality: options?['quality'] ?? true,
        selectBestPhotos: options?['best'] ?? true,
        onGroupDuplicates: (group, duplicates) {
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

            duplicateGroups.addAll(duplicates);
          });

          _scheduleProjectSave();
        },
        onProgress: (p) {
          if (!mounted) return;

          setState(() {
            progress = p;
          });

          _scheduleProjectSave();
        },
      );

      // اگر کاربر آنالیز را لغو کرده باشد،
      // پروگرس‌بار باید فوراً از صفحه حذف شود.
      if (result.cancelled) {
        if (mounted) {
          setState(() {
            progress = null;
          });
        }

        return;
      }

      final analyzedGroups = (options?['timeline'] ?? true)
          ? result.timelineGroups
          : oldGroups;

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

        // پایان کامل آنالیز
        progress = null;
      });

      await _loadFaceDatabase();
      await _loadCategoryLearningModel();

      final project = _ensureProject();

      project.sourcePaths = List<String>.from(sourcePaths);
      project.mediaItems = mediaItems;
      project.groups = groups;
      project.duplicateGroups = duplicateGroups;
      project.analysisCompleted = true;

      await _enqueueProjectSave();
    } catch (e, stackTrace) {
      debugPrint('Analysis error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('خطا در تحلیل تصاویر'),
              content: Text(e.toString()),
              severity: InfoBarSeverity.error,
              onClose: close,
            );
          },
        );
      }
    } finally {
      // چه آنالیز کامل شود، چه لغو شود، چه خطایی رخ دهد،
      // پروگرس‌بار در نهایت باید حذف شود.
      if (mounted) {
        setState(() {
          progress = null;
        });
      }
    }
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

      final oldWorkingDirectory = _workingDatabaseDirectory;

      setState(() {
        _projectPath = path;
        _workingDatabaseDirectory = File(path).parent.path;
      });

      // دیتابیس کاری چهره را از workspace موقت به کنار فایل پروژه منتقل می‌کنیم
      // تا با باز کردن پروژه در اجرای بعدی همان هویت‌ها در دسترس باشند.
      if (oldWorkingDirectory != null &&
          _normalizePath(oldWorkingDirectory) !=
              _normalizePath(_workingDatabaseDirectory!)) {
        final oldDb = await const FaceDatabaseService().load(
          oldWorkingDirectory,
        );
        if (oldDb.persons.isNotEmpty ||
            oldDb.faces.isNotEmpty ||
            oldDb.scans.isNotEmpty ||
            oldDb.rejections.isNotEmpty) {
          await const FaceDatabaseService().save(
            _workingDatabaseDirectory!,
            oldDb,
          );
        }
      }

      // مدل دسته‌بندی همراه فایل پروژه منتقل می‌شود.
      const categoryService = CategoryLearningService();
      _categoryLearningModel = categoryService.rebuild(groups);
      await categoryService.save(
        File(path).parent.path,
        _categoryLearningModel,
      );

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
      _selectedFacePersonId = null;
      _categoryLearningModel = const CategoryLearningModel();
      progress = null;

      _project = PhotonProject.empty('پروژه جدید');
      _projectPath = null;
      _workingDatabaseDirectory = null;
      _faceDatabaseDirectory = null;
      _faceDatabase = FaceDatabase();
      _categoryCatalogPaths = <List<String>>[];
      _portableArchiveRoot = null;
      _portableSnapshot = null;
      _cachedPortableDuplicateGroups = const [];
      _cachedPortableAnalysisPaths = <String>{};
      _faceDatabaseDirty = false;
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
        _workingDatabaseDirectory = File(path).parent.path;

        sourcePaths = List<String>.from(project.sourcePaths);
        mediaItems = project.mediaItems;
        groups = project.groups;
        duplicateGroups = project.duplicateGroups;
        selectedGroup = groups.isEmpty ? null : groups.first;
        progress = null;
        _portableArchiveRoot = null;
        _portableSnapshot = null;
        _cachedPortableDuplicateGroups = const [];
        _cachedPortableAnalysisPaths = <String>{};
        _faceDatabaseDirty = false;
      });

      await ProjectRepository.rememberProjectPath(path);
      await _loadFaceDatabase();
      await _loadCategoryLearningModel();

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
          sourceRoots: sourcePaths,
          faceDatabaseDirectory: _getFaceDatabaseDirectory(),
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

    if (mounted) {
      setState(() {
        progress = null;
      });
    }
  }
}
