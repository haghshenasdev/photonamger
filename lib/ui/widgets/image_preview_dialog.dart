import 'dart:io';

import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/video_preview.dart';
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
      Navigator.pop(context, true);
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

              if (current.isMedia && current.media!.isVideo)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: _buildVideoFileName(),
                ),

              if (!(current.isMedia && current.media!.isVideo))
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: _buildFileName(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          child: const Text('بستن'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }

  Widget _buildVideoFileName() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.video, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  current.media!.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileName() {
    final fileName = current.isMedia
        ? current.media!.fileName
        : current.duplicate!.items[current.duplicate!.selectedIndex].fileName;

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black.withAlpha(180),
      child: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildMedia() {
    final item = current.media!;

    if (item.isVideo) {
      return VideoPreview(
        path: item.path,
        onFullscreen: () {
          _openFullscreenVideo(item.path);
        },
      );
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

  Future<void> _openFullscreenVideo(String path) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return _FullscreenVideoDialog(path: path);
      },
    );

    if (!mounted) return;

    _focusNode.requestFocus();
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

class _FullscreenVideoDialog extends StatefulWidget {
  final String path;

  const _FullscreenVideoDialog({required this.path});

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPreview(
              path: widget.path,
              onFullscreen: () {
                Navigator.pop(context);
              },
            ),

            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(
                  FluentIcons.chrome_close,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
