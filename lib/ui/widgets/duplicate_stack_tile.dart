import 'dart:io';

import 'package:fgphoto/ui/models/duplicate_group.dart';
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

  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: () async {

        final index = widget.previewItems.indexWhere(
          (e) => e.isDuplicate && identical(e.duplicate, widget.group),
        );

        await showDialog(
          context: context,
          builder: (_) => ImagePreviewDialog(
            items: widget.previewItems,
            initialIndex: index,
          ),
        );

        // اگر عکس اصلی عوض شده باشد، کارت دوباره رسم شود
        setState(() {});
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
                  padding: const EdgeInsets.only(
                    left: 12,
                    top: 12,
                  ),
                  child: _image(widget.group.items[2]),
                ),
              ),

            if (widget.group.items.length > 1)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 6,
                    top: 6,
                  ),
                  child: _image(widget.group.items[1]),
                ),
              ),

            Positioned.fill(
              child: _image(
                widget.group.items[
                    widget.group.selectedIndex],
              ),
            ),

            Positioned(
              right: -6,
              bottom: -6,
              child: InfoBadge(
                source: Text(
                  '${widget.group.items.length}',
                ),
              ),
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
    );
  }

  Widget _image(item) {

    return Container(

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: Colors.white,
          width: 2,
        ),

        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(.15),
          )
        ],
      ),

      clipBehavior: Clip.antiAlias,

      child: Image.file(
        File(item.path),
        fit: BoxFit.cover,
      ),
    );
  }
}