import 'dart:io';

import 'package:fgphoto/core/file_explorer_service.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DuplicateStackTile extends StatefulWidget {
  final DuplicateGroup group;

  // لیست کامل Preview
  final List<PreviewItem> previewItems;

  const DuplicateStackTile({
    super.key,
    required this.group,
    required this.previewItems,
  });

  @override
  State<DuplicateStackTile> createState() => _DuplicateStackTileState();
}

class _DuplicateStackTileState extends State<DuplicateStackTile> {
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
      (e) => e.isDuplicate && identical(e.duplicate, widget.group),
    );

    if (index < 0) {
      return;
    }

    await showDialog(
      context: context,
      builder: (_) =>
          ImagePreviewDialog(items: widget.previewItems, initialIndex: index),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _showContextMenu(Offset position) {
    _flyoutController.showFlyout<void>(
      position: position,
      builder: (context) {
        final primary = widget.group.primary;

        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.open_folder_horizontal),
              text: const Text('نمایش عکس اصلی در File Explorer'),
              onPressed: () async {
                _flyoutController.close();

                await FileExplorerService.revealFile(primary.path);
              },
            ),

            MenuFlyoutItem(
              leading: const Icon(FluentIcons.folder_open),
              text: const Text('باز کردن پوشه عکس اصلی'),
              onPressed: () async {
                _flyoutController.close();

                await FileExplorerService.openFolder(
                  FileExplorerService.folderOf(primary.path),
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

        child: SizedBox(
          width: 110,
          height: 110,

          child: Stack(
            clipBehavior: Clip.none,

            children: [
              if (widget.group.items.length > 2)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 12),
                    child: _image(widget.group.items[2]),
                  ),
                ),

              if (widget.group.items.length > 1)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 6),
                    child: _image(widget.group.items[1]),
                  ),
                ),

              Positioned.fill(
                child: _image(widget.group.items[widget.group.selectedIndex]),
              ),

              Positioned(
                right: -6,
                bottom: -6,
                child: InfoBadge(source: Text('${widget.group.items.length}')),
              ),

              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  FluentIcons.favorite_star_fill,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(MediaItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.white, width: 2),

        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(.15),
          ),
        ],
      ),

      clipBehavior: Clip.antiAlias,

      child: Image.file(File(item.path), fit: BoxFit.cover),
    );
  }
}
