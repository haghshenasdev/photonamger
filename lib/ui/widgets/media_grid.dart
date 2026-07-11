import 'dart:io';

import 'package:fgphoto/ui/models/girid_item.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/duplicate_stack_tile.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class MediaGrid extends StatelessWidget {
  final List<GridItem> items;
  final VoidCallback? onChanged;

  const MediaGrid({super.key, required this.items, this.onChanged});

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
            );
          }

          return _MediaTile(item: item.media!, previewItems: previewItems,onChanged: onChanged,);
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;

  final List<PreviewItem> previewItems;
  final VoidCallback? onChanged;

  const _MediaTile({required this.item, required this.previewItems,this.onChanged,});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final index = previewItems.indexWhere(
          (e) => e.isMedia && e.media!.path == item.path,
        );

        final changed = await showDialog<bool>(
          context: context,
          builder: (_) =>
              ImagePreviewDialog(items: previewItems, initialIndex: index),
        );

        if (changed == true) {
          onChanged?.call();
        }
      },

      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

        child: Stack(
          fit: StackFit.expand,

          children: [
            if (!item.isVideo) Image.file(File(item.path), fit: BoxFit.cover),

            if (item.isVideo)
              Container(
                color: Colors.grey[80],

                child: const Center(child: Icon(FluentIcons.video, size: 40)),
              ),

            Positioned(
              bottom: 0,

              left: 0,

              right: 0,

              child: Container(
                padding: const EdgeInsets.all(4),

                color: Colors.black.withAlpha(150),

                child: Text(
                  item.fileName,

                  style: const TextStyle(fontSize: 10, color: Colors.white),

                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            Positioned(
              top: 5,
              right: 5,
              child: Icon(
                item.isSelected
                    ? FluentIcons.checkbox_composite
                    : FluentIcons.checkbox,
                color: item.isSelected ? Colors.green : Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
