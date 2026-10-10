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

String _gridPathKey(String path) => path.replaceAll('\\', '/').trim().toLowerCase();

class MediaGrid extends StatelessWidget {
  final List<GridItem> items;
  final VoidCallback? onChanged;
  final Set<String> selectedPaths;
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Center(child: Text('هیچ فایل رسانه‌ای پیدا نشد')),
      );
    }

    final previewItems = items.map((e) {
      if (e.isDuplicateGroup) {
        return PreviewItem.duplicate(e.duplicateGroup!);
      }

      return PreviewItem.media(e.media!);
    }).toList();

    final visibleMedia = <String, MediaItem>{};
    for (final gridItem in items) {
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
        .where((media) => selectedPaths.contains(_gridPathKey(media.path)))
        .length;

    return Card(
      child: Column(
        children: [
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  Icon(FluentIcons.checkbox_composite, size: 16),
                  const SizedBox(width: 8),
                  Text('$selectedCount فایل انتخاب شده'),
                  const Spacer(),
                  Button(
                    onPressed: onClearTransferSelection,
                    child: const Text('لغو انتخاب'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onTransferSelected,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(FluentIcons.folder, size: 16),
                      SizedBox(width: 6),
                      Text('انتقال به گروه زمانی…'),
                    ]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          if (item.isDuplicateGroup) {
            final duplicateItems = item.duplicateGroup!.items;
            final groupSelected = duplicateItems.isNotEmpty && duplicateItems.every(
              (media) => selectedPaths.contains(_gridPathKey(media.path)),
            );
            return Container(
              decoration: BoxDecoration(
                border: groupSelected
                    ? Border.all(color: FluentTheme.of(context).accentColor, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DuplicateStackTile(
              group: item.duplicateGroup!,
              previewItems: previewItems,
              onChanged: onChanged,
              onFaceSelected: onFaceSelected,
              faceNameResolver: faceNameResolver,
              selectedPersonId: selectedPersonId,
              faceDatabase: faceDatabase,
              onFaceAssignmentRejected: onFaceAssignmentRejected,
              onFaceRejectionCleared: onFaceRejectionCleared,
              onSelectForTransfer: onSelectForTransfer,
              selectedPaths: selectedPaths,
              ),
            );
          }

          return _MediaTile(
            item: item.media!,
            previewItems: previewItems,
            onChanged: onChanged,
            onFaceSelected: onFaceSelected,
            faceNameResolver: faceNameResolver,
            selectedPersonId: selectedPersonId,
            faceDatabase: faceDatabase,
            onFaceAssignmentRejected: onFaceAssignmentRejected,
            onFaceRejectionCleared: onFaceRejectionCleared,
            onSelectForTransfer: onSelectForTransfer,
            isTransferSelected: selectedPaths.contains(_gridPathKey(item.media!.path)),
          );
        },
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('نام پوشه سوژه را وارد کنید. تصویر اصلی جابه‌جا نمی‌شود.'),
          const SizedBox(height: 8),
          TextBox(controller: controller, placeholder: 'مثلاً جلسه اداری'),
        ]),
        actions: [
          Button(child: const Text('انصراف'), onPressed: () => Navigator.pop(dialogContext)),
          Button(child: const Text('کپی تصویر'), onPressed: () => Navigator.pop(dialogContext, controller.text.trim())),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final source = File(widget.item.path);
      if (!await source.exists()) return;
      final monthDirectory = source.parent.path;
      final destinationDir = Directory(p.join(monthDirectory, 'سوژه‌ها', name.trim()));
      await destinationDir.create(recursive: true);
      var destinationPath = p.join(destinationDir.path, p.basename(source.path));
      var i = 1;
      while (await File(destinationPath).exists()) {
        final ext = p.extension(source.path);
        final stem = p.basenameWithoutExtension(source.path);
        destinationPath = p.join(destinationDir.path, '$stem ($i)$ext');
        i++;
      }
      await source.copy(destinationPath);
      final marker = File(p.join(destinationDir.path, '.archino_secondary.json'));
      Map<String, dynamic> manifest = {'type': 'archino-secondary-folder', 'subject': name.trim(), 'items': <dynamic>[]};
      if (await marker.exists()) {
        try { manifest = Map<String, dynamic>.from(jsonDecode(await marker.readAsString()) as Map); } catch (_) {}
      }
      final entries = (manifest['items'] as List?)?.cast<dynamic>() ?? <dynamic>[];
      entries.add({'originalPath': p.normalize(source.path), 'copyPath': p.normalize(destinationPath), 'addedAt': DateTime.now().toIso8601String()});
      manifest['items'] = entries;
      await marker.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest), flush: true);
      // Preserve tags/user metadata alongside the copied image.
      final imageMeta = await ImageMetadataService.read(source.path);
      if ((imageMeta['tags'] as List?)?.isNotEmpty == true || (imageMeta['fields'] as Map?)?.isNotEmpty == true) {
        await ImageMetadataService.write(destinationPath, Map<String, dynamic>.from(imageMeta));
      }
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) => InfoBar(
          title: const Text('کپی شد'),
          content: Text('تصویر در پوشه سوژه‌ها/$name کپی شد.'),
          severity: InfoBarSeverity.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) => InfoBar(
          title: const Text('خطا در کپی تصویر'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
        ));
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تگ‌ها را با ویرگول جدا کنید. این تگ‌ها در فایل متادیتای جانبی ذخیره می‌شوند.'),
          const SizedBox(height: 8),
          TextBox(controller: controller, placeholder: 'خانوادگی، سفر، جلسه'),
        ]),
        actions: [
          Button(child: const Text('انصراف'), onPressed: () => Navigator.pop(dialogContext)),
          Button(child: const Text('ذخیره'), onPressed: () => Navigator.pop(dialogContext, controller.text)),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await ImageMetadataService.saveTags(widget.item.path, value.split(RegExp(r'[,،]')));
    if (mounted) {
      await displayInfoBar(context, builder: (context, close) => InfoBar(
        title: const Text('تگ‌ها ذخیره شدند'),
        content: const Text('تگ‌ها در فایل .archino-image.json کنار تصویر ذخیره شدند.'),
        severity: InfoBarSeverity.success,
      ));
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
          widget.onSelectForTransfer?.call([widget.item]);
          unawaited(_showContextMenu(details.globalPosition));
        },

        child: Container(
          decoration: BoxDecoration(
            border: widget.isTransferSelected
                ? Border.all(color: FluentTheme.of(context).accentColor, width: 3)
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
