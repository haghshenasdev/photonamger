import 'dart:io';

import 'package:fgphoto/core/file_explorer_service.dart';
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

  const MediaGrid({
    super.key,
    required this.items,
    this.onChanged,
    this.onFaceSelected,
    this.faceNameResolver,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Center(child: Text('هیچ فایل رسانه‌ای پیدا نشد')),
      );
    }

    /// فقط یکبار ساخته می‌شود
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
              onFaceSelected: onFaceSelected,
              faceNameResolver: faceNameResolver,
            );
          }

          return _MediaTile(
            item: item.media!,
            previewItems: previewItems,
            onChanged: onChanged,
            onFaceSelected: onFaceSelected,
            faceNameResolver: faceNameResolver,
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

  const _MediaTile({
    required this.item,
    required this.previewItems,
    this.onChanged,
    this.onFaceSelected,
    this.faceNameResolver,
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
      ),
    );

    if (changed == true) {
      widget.onChanged?.call();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _showContextMenu(Offset position) {
    _flyoutController.showFlyout<void>(
      position: position,
      builder: (context) {
        return MenuFlyout(
          items: [
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
          ],
        );
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
          _showContextMenu(details.globalPosition);
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
