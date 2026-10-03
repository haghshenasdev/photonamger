import 'dart:async';
import 'dart:io';

import 'package:fgphoto/core/file_explorer_service.dart';
import 'package:fgphoto/core/analysis/face_database.dart';
import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/duplicate_stack_tile.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fgphoto/ui/widgets/video_thumbnail.dart';
import 'package:fluent_ui/fluent_ui.dart';

class MediaGrid extends StatelessWidget {
  final List<GridItem> items;
  final VoidCallback? onChanged;

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

    return Card(
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
            return DuplicateStackTile(
              group: item.duplicateGroup!,
              previewItems: previewItems,
              onChanged: onChanged,
              onFaceSelected: onFaceSelected,
              faceNameResolver: faceNameResolver,
              selectedPersonId: selectedPersonId,
              faceDatabase: faceDatabase,
              onFaceAssignmentRejected: onFaceAssignmentRejected,
              onFaceRejectionCleared: onFaceRejectionCleared,
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
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  final MediaItem item;
  final List<PreviewItem> previewItems;

  final VoidCallback? onChanged;

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
          unawaited(_showContextMenu(details.globalPosition));
        },

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
    );
  }
}
