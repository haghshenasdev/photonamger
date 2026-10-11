import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:fgphoto/core/metadata/image_metadata_service.dart';

import 'package:fgphoto/core/file_explorer_service.dart';
import 'package:fgphoto/core/analysis/face_database.dart';
import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/duplicate_stack_tile.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fgphoto/ui/widgets/video_thumbnail.dart';
import 'package:fluent_ui/fluent_ui.dart';

String _gridPathKey(String path) =>
    path.replaceAll('\\', '/').trim().toLowerCase();

enum _GridSortMode {
  oldestFirst,
  newestFirst,
  nameAscending,
  nameDescending,
  typeAscending,
  typeDescending,
  sizeAscending,
  sizeDescending,
}

class MediaGrid extends StatefulWidget {
  final List<GridItem> items;
  final VoidCallback? onChanged;
  final Set<String> selectedPaths;
  final bool newestFirst;
  final ValueChanged<bool>? onSortChanged;
  final ValueChanged<List<MediaItem>>? onSelectForTransfer;
  final VoidCallback? onTransferSelected;
  final VoidCallback? onClearTransferSelection;
  final ValueChanged<String>? onFaceSelected;
  final String? Function(String personId)? faceNameResolver;
  final String? selectedPersonId;
  final FaceDatabase? faceDatabase;
  final Future<void> Function(MediaItem item, String personId)?
  onFaceAssignmentRejected;
  final Future<void> Function(MediaItem item, String personId)?
  onFaceRejectionCleared;

  const MediaGrid({
    super.key,
    required this.items,
    this.onChanged,
    this.selectedPaths = const <String>{},
    this.newestFirst = false,
    this.onSortChanged,
    this.onSelectForTransfer,
    this.onTransferSelected,
    this.onClearTransferSelection,
    this.onFaceSelected,
    this.faceNameResolver,
    this.selectedPersonId,
    this.faceDatabase,
    this.onFaceAssignmentRejected,
    this.onFaceRejectionCleared,
  });

  @override
  State<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<MediaGrid> {
  late _GridSortMode _sortMode;
  final FlyoutController _sortController = FlyoutController();
  bool _showDuplicateGroups = true;
  bool _showPhotos = true;
  bool _showVideos = true;

  @override
  void initState() {
    super.initState();
    _sortMode = widget.newestFirst
        ? _GridSortMode.newestFirst
        : _GridSortMode.oldestFirst;
  }

  @override
  void didUpdateWidget(covariant MediaGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.newestFirst != widget.newestFirst &&
        (oldWidget.onSortChanged != null) &&
        (_sortMode == _GridSortMode.oldestFirst ||
            _sortMode == _GridSortMode.newestFirst)) {
      _sortMode = widget.newestFirst
          ? _GridSortMode.newestFirst
          : _GridSortMode.oldestFirst;
    }
  }

  @override
  void dispose() {
    _sortController.dispose();
    super.dispose();
  }

  bool get _isDateSort =>
      _sortMode == _GridSortMode.oldestFirst ||
      _sortMode == _GridSortMode.newestFirst;

  String get _sortLabel => switch (_sortMode) {
    _GridSortMode.oldestFirst => 'قدیم به جدید',
    _GridSortMode.newestFirst => 'جدید به قدیم',
    _GridSortMode.nameAscending => 'نام: الف تا ی',
    _GridSortMode.nameDescending => 'نام: ی تا الف',
    _GridSortMode.typeAscending => 'نوع: عکس سپس ویدئو',
    _GridSortMode.typeDescending => 'نوع: ویدئو سپس عکس',
    _GridSortMode.sizeAscending => 'حجم: کم به زیاد',
    _GridSortMode.sizeDescending => 'حجم: زیاد به کم',
  };

  void _setSort(_GridSortMode mode) {
    setState(() => _sortMode = mode);
    if (mode == _GridSortMode.oldestFirst) widget.onSortChanged?.call(false);
    if (mode == _GridSortMode.newestFirst) widget.onSortChanged?.call(true);
  }

  void _openSortMenu() {
    final options = <(_GridSortMode, String, IconData)>[
      (_GridSortMode.oldestFirst, 'تاریخ: قدیم به جدید', FluentIcons.sort),
      (_GridSortMode.newestFirst, 'تاریخ: جدید به قدیم', FluentIcons.sort),
      (_GridSortMode.nameAscending, 'نام: الف تا ی', FluentIcons.text_box),
      (
        _GridSortMode.nameDescending,
        'نام: ی تا الف',
        FluentIcons.text_document,
      ),
      (_GridSortMode.typeAscending, 'نوع: عکس سپس ویدئو', FluentIcons.picture),
      (_GridSortMode.typeDescending, 'نوع: ویدئو سپس عکس', FluentIcons.video),
      (
        _GridSortMode.sizeAscending,
        'حجم فایل: کم به زیاد',
        FluentIcons.download,
      ),
      (
        _GridSortMode.sizeDescending,
        'حجم فایل: زیاد به کم',
        FluentIcons.upload,
      ),
    ];
    _sortController.showFlyout<void>(
      builder: (context) => MenuFlyout(
        items: options
            .map(
              (option) => MenuFlyoutItem(
                leading: Icon(
                  _sortMode == option.$1 ? FluentIcons.check_mark : option.$3,
                ),
                text: Text(option.$2),
                onPressed: () {
                  _sortController.close();
                  _setSort(option.$1);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showFilters() async {
    var duplicates = _showDuplicateGroups;
    var photos = _showPhotos;
    var videos = _showVideos;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('فیلتر نمایش تصاویر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مواردی را که می‌خواهی در گرید نمایش داده شوند تیک بزن.',
              ),
              const SizedBox(height: 10),
              Checkbox(
                checked: duplicates,
                content: const Text('گروه‌های عکس تکراری'),
                onChanged: (value) =>
                    setDialogState(() => duplicates = value ?? false),
              ),
              Checkbox(
                checked: photos,
                content: const Text('تصاویر تکی'),
                onChanged: (value) =>
                    setDialogState(() => photos = value ?? false),
              ),
              Checkbox(
                checked: videos,
                content: const Text('فیلم‌ها'),
                onChanged: (value) =>
                    setDialogState(() => videos = value ?? false),
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('همه موارد'),
              onPressed: () => setDialogState(() {
                duplicates = true;
                photos = true;
                videos = true;
              }),
            ),
            Button(
              child: const Text('انصراف'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            FilledButton(
              child: const Text('اعمال فیلتر'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _showDuplicateGroups = duplicates;
        _showPhotos = photos;
        _showVideos = videos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = List<GridItem>.from(widget.items);
    final displayItems = allItems.where((item) {
      if (item.isDuplicateGroup) return _showDuplicateGroups;
      final media = item.media!;
      return media.isVideo ? _showVideos : _showPhotos;
    }).toList();

    DateTime itemDate(GridItem item) {
      if (item.isDuplicateGroup) {
        final groupItems = item.duplicateGroup!.items;
        if (groupItems.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
        return groupItems
            .map((media) => media.createdAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      return item.media!.createdAt;
    }

    String itemName(GridItem item) => item.isDuplicateGroup
        ? (item.duplicateGroup!.primary.fileName)
        : item.media!.fileName;
    int itemSize(GridItem item) => item.isDuplicateGroup
        ? item.duplicateGroup!.items.fold<int>(
            0,
            (sum, media) => sum + media.fileSize,
          )
        : item.media!.fileSize;
    int itemType(GridItem item) =>
        item.isDuplicateGroup ? 0 : (item.media!.isVideo ? 2 : 1);

    displayItems.sort((a, b) {
      switch (_sortMode) {
        case _GridSortMode.oldestFirst:
          return itemDate(a).compareTo(itemDate(b));
        case _GridSortMode.newestFirst:
          return itemDate(b).compareTo(itemDate(a));
        case _GridSortMode.nameAscending:
          return itemName(a).toLowerCase().compareTo(itemName(b).toLowerCase());
        case _GridSortMode.nameDescending:
          return itemName(b).toLowerCase().compareTo(itemName(a).toLowerCase());
        case _GridSortMode.typeAscending:
          final result = itemType(a).compareTo(itemType(b));
          return result != 0
              ? result
              : itemName(a).toLowerCase().compareTo(itemName(b).toLowerCase());
        case _GridSortMode.typeDescending:
          final result = itemType(b).compareTo(itemType(a));
          return result != 0
              ? result
              : itemName(a).toLowerCase().compareTo(itemName(b).toLowerCase());
        case _GridSortMode.sizeAscending:
          return itemSize(a).compareTo(itemSize(b));
        case _GridSortMode.sizeDescending:
          return itemSize(b).compareTo(itemSize(a));
      }
    });

    if (displayItems.isEmpty) {
      return Card(
        child: Column(
          children: [
            _buildToolbar(context, 0),
            const Expanded(
              child: Center(
                child: Text('موردی با فیلترهای انتخاب‌شده پیدا نشد'),
              ),
            ),
          ],
        ),
      );
    }

    final previewItems = displayItems
        .map(
          (e) => e.isDuplicateGroup
              ? PreviewItem.duplicate(e.duplicateGroup!)
              : PreviewItem.media(e.media!),
        )
        .toList();

    final visibleMedia = <String, MediaItem>{};
    for (final gridItem in displayItems) {
      if (gridItem.isDuplicateGroup) {
        for (final media in gridItem.duplicateGroup!.items) {
          visibleMedia[media.path.toLowerCase()] = media;
        }
      } else {
        final media = gridItem.media!;
        visibleMedia[media.path.toLowerCase()] = media;
      }
    }
    final selectedCount = visibleMedia.values
        .where(
          (media) => widget.selectedPaths.contains(_gridPathKey(media.path)),
        )
        .length;

    return Card(
      child: Column(
        children: [
          _buildToolbar(context, displayItems.length),
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  const Icon(FluentIcons.checkbox_composite, size: 16),
                  const SizedBox(width: 8),
                  Text('$selectedCount فایل انتخاب شده'),
                  const Spacer(),
                  Button(
                    onPressed: widget.onClearTransferSelection,
                    child: const Text('لغو انتخاب'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: widget.onTransferSelected,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.folder, size: 16),
                        SizedBox(width: 6),
                        Text('انتقال به گروه زمانی…'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: displayItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                if (item.isDuplicateGroup) {
                  final duplicateItems = item.duplicateGroup!.items;
                  final groupSelected =
                      duplicateItems.isNotEmpty &&
                      duplicateItems.every(
                        (media) => widget.selectedPaths.contains(
                          _gridPathKey(media.path),
                        ),
                      );
                  return Container(
                    decoration: BoxDecoration(
                      border: groupSelected
                          ? Border.all(
                              color: FluentTheme.of(context).accentColor,
                              width: 3,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DuplicateStackTile(
                      group: item.duplicateGroup!,
                      previewItems: previewItems,
                      onChanged: widget.onChanged,
                      onFaceSelected: widget.onFaceSelected,
                      faceNameResolver: widget.faceNameResolver,
                      selectedPersonId: widget.selectedPersonId,
                      faceDatabase: widget.faceDatabase,
                      onFaceAssignmentRejected: widget.onFaceAssignmentRejected,
                      onFaceRejectionCleared: widget.onFaceRejectionCleared,
                      onSelectForTransfer: widget.onSelectForTransfer,
                      selectedPaths: widget.selectedPaths,
                    ),
                  );
                }
                return _MediaTile(
                  item: item.media!,
                  previewItems: previewItems,
                  onChanged: widget.onChanged,
                  onFaceSelected: widget.onFaceSelected,
                  faceNameResolver: widget.faceNameResolver,
                  selectedPersonId: widget.selectedPersonId,
                  faceDatabase: widget.faceDatabase,
                  onFaceAssignmentRejected: widget.onFaceAssignmentRejected,
                  onFaceRejectionCleared: widget.onFaceRejectionCleared,
                  onSelectForTransfer: widget.onSelectForTransfer,
                  isTransferSelected: widget.selectedPaths.contains(
                    _gridPathKey(item.media!.path),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, int count) {
    final activeFilters =
        (_showDuplicateGroups ? 1 : 0) +
        (_showPhotos ? 1 : 0) +
        (_showVideos ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          Text('$count مورد'),
          const Spacer(),
          FlyoutTarget(
            controller: _sortController,
            child: Button(
              onPressed: _openSortMenu,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.sort, size: 14),
                  const SizedBox(width: 6),
                  Text(_sortLabel),
                  const SizedBox(width: 4),
                  const Icon(FluentIcons.chevron_down, size: 9),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: _showFilters,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.filter, size: 14),
                const SizedBox(width: 6),
                const Text('فیلتر نمایش'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).accentColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeFilters/3',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  final MediaItem item;
  final List<PreviewItem> previewItems;

  final VoidCallback? onChanged;
  final ValueChanged<List<MediaItem>>? onSelectForTransfer;
  final bool isTransferSelected;

  final ValueChanged<String>? onFaceSelected;

  final String? Function(String personId)? faceNameResolver;

  final String? selectedPersonId;

  final FaceDatabase? faceDatabase;

  final Future<void> Function(MediaItem item, String personId)?
  onFaceAssignmentRejected;

  final Future<void> Function(MediaItem item, String personId)?
  onFaceRejectionCleared;

  const _MediaTile({
    required this.item,
    required this.previewItems,
    this.onChanged,
    this.onSelectForTransfer,
    this.isTransferSelected = false,
    this.onFaceSelected,
    this.faceNameResolver,
    this.selectedPersonId,
    this.faceDatabase,
    this.onFaceAssignmentRejected,
    this.onFaceRejectionCleared,
  });

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  late final FlyoutController _flyoutController;

  @override
  void initState() {
    super.initState();
    _flyoutController = FlyoutController();
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  Future<void> _openPreview() async {
    final index = widget.previewItems.indexWhere(
      (e) => e.isMedia && e.media!.path == widget.item.path,
    );

    if (index < 0) {
      return;
    }

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ImagePreviewDialog(
        items: widget.previewItems,
        initialIndex: index,
        onFaceSelected: widget.onFaceSelected,
        faceNameResolver: widget.faceNameResolver,
        selectedPersonId: widget.selectedPersonId,
      ),
    );

    if (changed == true) {
      widget.onChanged?.call();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addToSubjectFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('افزودن به پوشه سوژه‌ها'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'نام پوشه سوژه را وارد کنید. تصویر اصلی جابه‌جا نمی‌شود.',
            ),
            const SizedBox(height: 8),
            TextBox(controller: controller, placeholder: 'مثلاً جلسه اداری'),
          ],
        ),
        actions: [
          Button(
            child: const Text('انصراف'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          Button(
            child: const Text('کپی تصویر'),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final source = File(widget.item.path);
      if (!await source.exists()) return;
      final monthDirectory = source.parent.path;
      final destinationDir = Directory(
        p.join(monthDirectory, 'سوژه‌ها', name.trim()),
      );
      await destinationDir.create(recursive: true);
      var destinationPath = p.join(
        destinationDir.path,
        p.basename(source.path),
      );
      var i = 1;
      while (await File(destinationPath).exists()) {
        final ext = p.extension(source.path);
        final stem = p.basenameWithoutExtension(source.path);
        destinationPath = p.join(destinationDir.path, '$stem ($i)$ext');
        i++;
      }
      await source.copy(destinationPath);
      final marker = File(
        p.join(destinationDir.path, '.archino_secondary.json'),
      );
      Map<String, dynamic> manifest = {
        'type': 'archino-secondary-folder',
        'subject': name.trim(),
        'items': <dynamic>[],
      };
      if (await marker.exists()) {
        try {
          manifest = Map<String, dynamic>.from(
            jsonDecode(await marker.readAsString()) as Map,
          );
        } catch (_) {}
      }
      final entries =
          (manifest['items'] as List?)?.cast<dynamic>() ?? <dynamic>[];
      entries.add({
        'originalPath': p.normalize(source.path),
        'copyPath': p.normalize(destinationPath),
        'addedAt': DateTime.now().toIso8601String(),
      });
      manifest['items'] = entries;
      await marker.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      // Preserve tags/user metadata alongside the copied image.
      final imageMeta = await ImageMetadataService.read(source.path);
      if ((imageMeta['tags'] as List?)?.isNotEmpty == true ||
          (imageMeta['fields'] as Map?)?.isNotEmpty == true) {
        await ImageMetadataService.write(
          destinationPath,
          Map<String, dynamic>.from(imageMeta),
        );
      }
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('کپی شد'),
            content: Text('تصویر در پوشه سوژه‌ها/$name کپی شد.'),
            severity: InfoBarSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('خطا در کپی تصویر'),
            content: Text('$e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

  Future<void> _editImageTags() async {
    final existing = await ImageMetadataService.tags(widget.item.path);
    final controller = TextEditingController(text: existing.join(', '));
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('تگ‌های تصویر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تگ‌ها را با ویرگول جدا کنید. این تگ‌ها در فایل متادیتای جانبی ذخیره می‌شوند.',
            ),
            const SizedBox(height: 8),
            TextBox(controller: controller, placeholder: 'خانوادگی، سفر، جلسه'),
          ],
        ),
        actions: [
          Button(
            child: const Text('انصراف'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          Button(
            child: const Text('ذخیره'),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await ImageMetadataService.saveTags(
      widget.item.path,
      value.split(RegExp(r'[,،]')),
    );
    if (mounted) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('تگ‌ها ذخیره شدند'),
          content: const Text(
            'تگ‌ها در فایل .archino-image.json کنار تصویر ذخیره شدند.',
          ),
          severity: InfoBarSeverity.success,
        ),
      );
    }
  }

  Future<void> _showContextMenu(Offset position) async {
    final faceDatabase = widget.faceDatabase;

    /*
     * فقط personIdهای معتبر را نگه می‌داریم.
     *
     * چون در مدل FaceInfo/StoredFace ممکن است personId
     * nullable باشد، قبل از trim کردن باید null حذف شود.
     */
    final detectedPersonIds = widget.item.faces
        .map((face) => face.personId)
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final rejectedPersonIds = <String>[];

    if (faceDatabase != null) {
      final fingerprint = await FaceDatabaseService.fingerprintOf(
        widget.item.path,
      );

      if (fingerprint != 'missing') {
        /*
         * rejection.personId در مدل فعلی String? است.
         *
         * whereType<String>() باعث می‌شود فقط مقادیر
         * غیر null وارد لیست String شوند.
         */
        rejectedPersonIds.addAll(
          faceDatabase.rejections
              .where((rejection) => rejection.fingerprint == fingerprint)
              .map((rejection) => rejection.personId)
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
      }
    }

    final menuItems = <MenuFlyoutItemBase>[];

    // انتخاب برای انتقال فقط با دستور صریح منوی راست‌کلیک انجام می‌شود.
    menuItems.add(
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.checkbox_composite),
        text: Text(
          widget.isTransferSelected
              ? 'لغو انتخاب برای انتقال'
              : 'انتخاب برای انتقال',
        ),
        onPressed: () {
          _flyoutController.close();
          widget.onSelectForTransfer?.call([widget.item]);
        },
      ),
    );
    menuItems.add(const MenuFlyoutSeparator());

    /*
     * ==============================
     * تشخیص‌های فعلی
     * ==============================
     */
    if (detectedPersonIds.isNotEmpty &&
        widget.onFaceAssignmentRejected != null) {
      for (final personId in detectedPersonIds) {
        final name = widget.faceNameResolver?.call(personId) ?? 'این شخص';

        menuItems.add(
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.cancel),
            text: Text('این عکس متعلق به «$name» نیست'),
            onPressed: () async {
              _flyoutController.close();

              await widget.onFaceAssignmentRejected!(widget.item, personId);

              if (mounted) {
                setState(() {});
              }

              widget.onChanged?.call();
            },
          ),
        );
      }
    }

    /*
     * ==============================
     * اصلاح‌های قبلی
     * ==============================
     */
    if (rejectedPersonIds.isNotEmpty && widget.onFaceRejectionCleared != null) {
      if (menuItems.isNotEmpty) {
        menuItems.add(const MenuFlyoutSeparator());
      }

      for (final personId in rejectedPersonIds) {
        final name = widget.faceNameResolver?.call(personId) ?? 'این شخص';

        menuItems.add(
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.undo),
            text: Text('لغو اصلاح «$name»'),
            onPressed: () async {
              _flyoutController.close();

              await widget.onFaceRejectionCleared!(widget.item, personId);

              if (mounted) {
                setState(() {});
              }

              widget.onChanged?.call();
            },
          ),
        );
      }
    }

    /*
     * ==============================
     * فایل و پوشه
     * ==============================
     */
    if (menuItems.isNotEmpty) {
      menuItems.add(const MenuFlyoutSeparator());
    }

    menuItems.addAll([
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.folder),
        text: const Text('افزودن به پوشه سوژه‌ها…'),
        onPressed: () async {
          _flyoutController.close();
          await _addToSubjectFolder();
        },
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.tag),
        text: const Text('مدیریت تگ‌های تصویر…'),
        onPressed: () async {
          // _flyoutController.close();
          await _editImageTags();
        },
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.open_folder_horizontal),
        text: const Text('نمایش فایل در File Explorer'),
        onPressed: () async {
          _flyoutController.close();

          await FileExplorerService.revealFile(widget.item.path);
        },
      ),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.folder_open),
        text: const Text('باز کردن پوشه فایل'),
        onPressed: () async {
          _flyoutController.close();

          await FileExplorerService.openFolder(
            FileExplorerService.folderOf(widget.item.path),
          );
        },
      ),
    ]);

    if (!mounted) {
      return;
    }

    _flyoutController.showFlyout<void>(
      position: position,
      builder: (context) {
        return MenuFlyout(items: menuItems);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: _openPreview,

        onSecondaryTapUp: (details) {
          // راست‌کلیک فقط منو را باز می‌کند؛ انتخاب از گزینه منو انجام می‌شود.
          unawaited(_showContextMenu(details.globalPosition));
        },

        child: Container(
          decoration: BoxDecoration(
            border: widget.isTransferSelected
                ? Border.all(
                    color: FluentTheme.of(context).accentColor,
                    width: 3,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!widget.item.isVideo)
                  Image.file(File(widget.item.path), fit: BoxFit.cover),

                if (widget.item.isVideo) VideoThumbnail(path: widget.item.path),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.black.withAlpha(150),
                    child: Text(
                      widget.item.fileName,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(
                    widget.item.isSelected
                        ? FluentIcons.checkbox_composite
                        : FluentIcons.checkbox,
                    color: widget.item.isSelected ? Colors.green : Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
