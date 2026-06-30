import 'dart:io';

import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class ImagePreviewDialog extends StatefulWidget {
  final List<PreviewItem> items;
  final int initialIndex;

  const ImagePreviewDialog({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  late int currentIndex;
  int duplicateIndex = 0;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;

    if (widget.items[currentIndex].isDuplicate) {
      duplicateIndex = widget.items[currentIndex].duplicate!.selectedIndex;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  PreviewItem get current => widget.items[currentIndex];

  void nextImage() {
    if (current.isDuplicate) {
      final group = current.duplicate!;

      // هنوز داخل Duplicate عکس بعدی وجود دارد
      if (duplicateIndex < group.items.length - 1) {
        setState(() {
          duplicateIndex++;
        });

        return;
      }
    }

    // رفتن به آیتم بعدی Grid
    if (currentIndex < widget.items.length - 1) {
      setState(() {
        currentIndex++;

        final preview = widget.items[currentIndex];

        if (preview.isDuplicate) {
          duplicateIndex = preview.duplicate!.selectedIndex;
        } else {
          duplicateIndex = 0;
        }
      });
    }
  }

  void previousImage() {
    if (current.isDuplicate) {
      // هنوز داخل Duplicate هستیم
      if (duplicateIndex > 0) {
        setState(() {
          duplicateIndex--;
        });

        return;
      }
    }

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;

        final preview = widget.items[currentIndex];

        if (preview.isDuplicate) {
          duplicateIndex = preview.duplicate!.selectedIndex;
        } else {
          duplicateIndex = 0;
        }
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      nextImage();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      previousImage();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      setState(() {
        if (current.isDuplicate) {
          current.duplicate!.selectedIndex = duplicateIndex;
        } else {
          current.media!.isSelected = !current.media!.isSelected;
        }
      });

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),
      title: Text(
        current.isMedia
            ? "${currentIndex + 1} / ${widget.items.length}"
            : "${currentIndex + 1} / ${widget.items.length}"
                  "    "
                  "(${duplicateIndex + 1}"
                  "/"
                  "${current.duplicate!.items.length})",
      ),
      content: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: SizedBox(
          width: 1300,
          height: 800,
          child: Stack(
            children: [
              Positioned.fill(
                child: current.isMedia ? _buildMedia() : _buildDuplicate(),
              ),

              if (currentIndex > 0)
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_left, size: 28),
                      onPressed: previousImage,
                    ),
                  ),
                ),

              if (currentIndex < widget.items.length - 1)
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_right, size: 28),
                      onPressed: nextImage,
                    ),
                  ),
                ),

              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black.withAlpha(180),
                  child: Text(
                    current.isMedia
                        ? current.media!.fileName
                        : current
                              .duplicate!
                              .items[current.duplicate!.selectedIndex]
                              .fileName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          child: const Text('بستن'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    final item = current.media!;

    if (item.isVideo) {
      return const Center(child: Icon(FluentIcons.video, size: 120));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 8,
            child: Center(
              child: Image.file(File(item.path), fit: BoxFit.contain),
            ),
          ),
        ),

        Positioned(
          top: 12,
          right: 12,
          child: Icon(
            item.isSelected
                ? FluentIcons.checkbox_composite
                : FluentIcons.checkbox,
            color: item.isSelected ? Colors.green : Colors.grey,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicate() {
    final group = current.duplicate!;

    if (duplicateIndex >= group.items.length) {
      duplicateIndex = group.selectedIndex;
    }

    final item = group.items[duplicateIndex];

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Card(
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8,
                    child: Center(
                      child: Image.file(File(item.path), fit: BoxFit.contain),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(item.fileName, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 330,
          child: Column(
            children: [
              const Text(
                "نسخه های مشابه",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  itemCount: group.items.length,

                  itemBuilder: (_, index) {
                    final file = group.items[index];

                    final selected = duplicateIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          duplicateIndex = index;
                        });
                      },

                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),

                          border: Border.all(
                            color: selected ? Colors.blue : Colors.grey[80],

                            width: selected ? 2 : 1,
                          ),
                        ),

                        child: Padding(
                          padding: const EdgeInsets.all(8),

                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,

                                height: 70,

                                child: Image.file(
                                  File(file.path),

                                  fit: BoxFit.cover,
                                ),
                              ),

                              const SizedBox(width: 8),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      file.fileName,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      file.createdAt.toString(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                icon: Icon(
                                  group.selectedIndex == index
                                      ? FluentIcons.favorite_star_fill
                                      : FluentIcons.favorite_star,

                                  color: group.selectedIndex == index
                                      ? Colors.orange
                                      : Colors.grey,
                                ),

                                onPressed: () {
                                  setState(() {
                                    group.selectedIndex = index;
                                  });
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
    );
  }
}
