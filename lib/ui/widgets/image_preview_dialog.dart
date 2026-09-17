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

  /// ایندکس عکس فعلی داخل گروه Duplicate
  int duplicateIndex = 0;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex;

    if (widget.items[currentIndex].isDuplicate) {
      final group = widget.items[currentIndex].duplicate!;

      duplicateIndex = group.selectedIndex;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  PreviewItem get current => widget.items[currentIndex];

  // ============================================================
  // Navigation
  // ============================================================

  void nextImage() {
    if (current.isDuplicate) {
      final group = current.duplicate!;

      // اگر داخل تصاویر Duplicate هنوز تصویر بعدی داریم
      if (duplicateIndex < group.items.length - 1) {
        setState(() {
          duplicateIndex++;
        });

        _requestFocus();

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

      _requestFocus();
    }
  }

  void previousImage() {
    if (current.isDuplicate) {
      // اگر داخل گروه Duplicate هستیم
      if (duplicateIndex > 0) {
        setState(() {
          duplicateIndex--;
        });

        _requestFocus();

        return;
      }
    }

    // رفتن به آیتم قبلی Grid
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

      _requestFocus();
    }
  }

  // ============================================================
  // Keyboard
  // ============================================================

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

    // Space = انتخاب / لغو انتخاب
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _toggleCurrentSelection();

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _toggleCurrentSelection() {
    if (current.isDuplicate) {
      final group = current.duplicate!;

      setState(() {
        group.toggleSelection(duplicateIndex);
      });

      _requestFocus();

      return;
    }

    // برای تصاویر معمولی همان رفتار قبلی
    final media = current.media!;

    setState(() {
      media.isSelected = !media.isSelected;
    });

    _requestFocus();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),

      title: Text(
        current.isMedia
            ? '${currentIndex + 1} / ${widget.items.length}'
            : '${currentIndex + 1} / ${widget.items.length}'
                  '    '
                  '(${duplicateIndex + 1}'
                  '/'
                  '${current.duplicate!.items.length})',
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

              // Previous
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

              // Next
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
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }

  // ============================================================
  // Video
  // ============================================================

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
        : current.duplicate!.items[duplicateIndex].fileName;

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

  // ============================================================
  // Normal Media
  // ============================================================

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

  // ============================================================
  // Duplicate
  // ============================================================

  Widget _buildDuplicate() {
    final group = current.duplicate!;

    if (group.items.isEmpty) {
      return const Center(child: Text('تصویری در این گروه وجود ندارد'));
    }

    if (duplicateIndex < 0 || duplicateIndex >= group.items.length) {
      duplicateIndex = group.selectedIndex;
    }

    final item = group.items[duplicateIndex];

    return Row(
      children: [
        // ========================================================
        // Preview
        // ========================================================
        Expanded(
          flex: 3,
          child: Card(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 8,
                          child: Center(
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // تیک انتخاب عکس فعلی
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _selectionIcon(
                          group.isSelected(duplicateIndex),
                          size: 30,
                        ),
                      ),

                      // ستاره عکس اصلی
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Icon(
                          group.selectedIndex == duplicateIndex
                              ? FluentIcons.favorite_star_fill
                              : FluentIcons.favorite_star,
                          color: group.selectedIndex == duplicateIndex
                              ? Colors.orange
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
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

        // ========================================================
        // Duplicate List
        // ========================================================
        SizedBox(
          width: 350,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'نسخه های مشابه',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  InfoBadge(
                    source: Text(
                      '${group.selectedIndices.length}/${group.items.length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  itemCount: group.items.length,

                  itemBuilder: (_, index) {
                    final file = group.items[index];

                    // selected یعنی عکس فعلی که Preview شده است.
                    // این با selectedIndices فرق دارد.
                    final isPreviewed = duplicateIndex == index;

                    final isChecked = group.isSelected(index);

                    final isPrimary = group.selectedIndex == index;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(
                          color: isPreviewed ? Colors.blue : Colors.grey[80],
                          width: isPreviewed ? 2 : 1,
                        ),
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(8),

                        child: Row(
                          children: [
                            // ==================================================
                            // Checkbox / Tick
                            // ==================================================
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,

                              onTap: () {
                                setState(() {
                                  group.toggleSelection(index);
                                });

                                _requestFocus();
                              },

                              child: Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: _selectionIcon(isChecked, size: 24),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ==================================================
                            // Image
                            // ==================================================
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,

                              onTap: () {
                                setState(() {
                                  // فقط Preview تغییر می‌کند.
                                  // انتخاب تغییر نمی‌کند.
                                  duplicateIndex = index;
                                });

                                _requestFocus();
                              },

                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),

                                child: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ==================================================
                            // File info
                            // ==================================================
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,

                                onTap: () {
                                  setState(() {
                                    // فقط Preview
                                    duplicateIndex = index;
                                  });

                                  _requestFocus();
                                },

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
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ==================================================
                            // Primary Star
                            // ==================================================
                            IconButton(
                              icon: Icon(
                                isPrimary
                                    ? FluentIcons.favorite_star_fill
                                    : FluentIcons.favorite_star,

                                color: isPrimary ? Colors.orange : Colors.grey,
                              ),

                              onPressed: () {
                                setState(() {
                                  // عکس اصلی حتماً انتخاب هم می‌شود.
                                  group.setPrimary(index);

                                  // Preview هم روی همین عکس قرار می‌گیرد.
                                  duplicateIndex = index;
                                });

                                _requestFocus();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // راهنمای کوتاه
              Text(
                'تیک: انتخاب/لغو انتخاب    •    Space: انتخاب عکس فعلی',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[100]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Selection icon
  // دقیقاً با همان سبک MediaGrid
  // ============================================================

  Widget _selectionIcon(bool selected, {double size = 24}) {
    return Icon(
      selected ? FluentIcons.checkbox_composite : FluentIcons.checkbox,
      color: selected ? Colors.green : Colors.white,
      size: size,
    );
  }

  // ============================================================
  // Fullscreen video
  // ============================================================

  Future<void> _openFullscreenVideo(String path) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return _FullscreenVideoDialog(path: path);
      },
    );

    if (!mounted) return;

    _requestFocus();
  }
}

// ================================================================
// Fullscreen Video
// ================================================================

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
