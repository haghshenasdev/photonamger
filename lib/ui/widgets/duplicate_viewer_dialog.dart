import 'dart:io';

import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DuplicateViewerDialog extends StatefulWidget {
  final DuplicateGroup group;

  final ValueChanged<MediaItem>? onSelected;

  const DuplicateViewerDialog({
    super.key,
    required this.group,
    this.onSelected,
  });

  @override
  State<DuplicateViewerDialog> createState() => _DuplicateViewerDialogState();
}

class _DuplicateViewerDialogState extends State<DuplicateViewerDialog> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.group.items[selectedIndex];

    return ContentDialog(
      title: const Text('تصاویر تکراری'),

      constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),

      content: SizedBox(
        width: 1100,
        height: 650,

        child: Row(
          children: [
            Expanded(
              flex: 3,

              child: Card(
                child: Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Image.file(
                          File(current.path),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(8),

                      child: Text(
                        current.path,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),  

            SizedBox(
              width: 320,

              child: Column(
                children: [
                  const Text(
                    'نسخه های مشابه',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.group.items.length,

                      itemBuilder: (_, index) {
                        final item = widget.group.items[index];

                        final selected = selectedIndex == index;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },

                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),

                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected ? Colors.blue : Colors.grey[80],
                                width: selected ? 2 : 1,
                              ),

                              borderRadius: BorderRadius.circular(8),
                            ),

                            child: Padding(
                              padding: const EdgeInsets.all(8),

                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 70,

                                    child: Image.file(
                                      File(item.path),

                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          item.path
                                              .split(Platform.pathSeparator)
                                              .last,

                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          item.createdAt.toString(),

                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      widget.group.selectedIndex == index
                                          ? FluentIcons.favorite_star_fill
                                          : FluentIcons.favorite_star,
                                      color: widget.group.selectedIndex == index
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        widget.group.selectedIndex = index;
                                      });

                                      widget.onSelected?.call(item);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      actions: [
        FilledButton(
          child: const Text('انتخاب به عنوان عکس اصلی'),

          onPressed: () {
            setState(() {
              widget.group.selectedIndex = selectedIndex;
            });

            widget.onSelected?.call(widget.group.primary);

            Navigator.pop(context);
          },
        ),

        Button(
          child: const Text('بستن'),

          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
