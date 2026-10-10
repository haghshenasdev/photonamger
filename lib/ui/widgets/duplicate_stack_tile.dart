import 'dart:async';
import 'dart:io';

import 'package:fgphoto/core/analysis/face_database.dart';
import 'package:fgphoto/core/file_explorer_service.dart';
import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/media_item.dart';
import 'package:fgphoto/ui/models/preview_item.dart';
import 'package:fgphoto/ui/widgets/image_preview_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DuplicateStackTile extends StatefulWidget {
  final DuplicateGroup group;

  /// لیست کامل Preview
  final List<PreviewItem> previewItems;

  final ValueChanged<String>? onFaceSelected;
  final ValueChanged<List<MediaItem>>? onSelectForTransfer;
  final Set<String> selectedPaths;

  final String? Function(String personId)? faceNameResolver;

  final String? selectedPersonId;

  /// برای refresh شدن لیست بعد از اصلاح چهره
  final VoidCallback? onChanged;

  /// دیتابیس تشخیص چهره
  final FaceDatabase? faceDatabase;

  /// رد کردن انتساب عکس به یک شخص
  final Future<void> Function(MediaItem item, String personId)?
  onFaceAssignmentRejected;

  /// لغو رد کردن انتساب
  final Future<void> Function(MediaItem item, String personId)?
  onFaceRejectionCleared;

  const DuplicateStackTile({
    super.key,
    required this.group,
    required this.previewItems,
    this.onFaceSelected,
    this.onSelectForTransfer,
    this.selectedPaths = const <String>{},
    this.faceNameResolver,
    this.selectedPersonId,
    this.onChanged,
    this.faceDatabase,
    this.onFaceAssignmentRejected,
    this.onFaceRejectionCleared,
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

  /// محاسبه fingerprint تمام عکس‌های داخل گروه
  ///
  /// این کار قبل از ساخت Flyout انجام می‌شود چون builder
  /// مربوط به Flyout async نیست.
  Future<Map<String, String>> _loadFingerprints() async {
    final result = <String, String>{};

    if (widget.faceDatabase == null) {
      return result;
    }

    for (final item in widget.group.items) {
      try {
        final fingerprint = await FaceDatabaseService.fingerprintOf(item.path);

        if (fingerprint.isNotEmpty && fingerprint != 'missing') {
          result[item.path] = fingerprint;
        }
      } catch (_) {
        // اگر fingerprint این فایل قابل محاسبه نبود،
        // بقیه فایل‌ها همچنان پردازش می‌شوند.
      }
    }

    return result;
  }

  /// منوی کلیک راست Duplicate Group
  ///
  /// مهم:
  /// این منو تمام عکس‌های گروه را جداگانه نمایش می‌دهد.
  /// بنابراین حتی اگر عکس سوم پشت عکس اول باشد،
  /// می‌توانیم خود عکس سوم را انتخاب کنیم.
  Future<void> _showContextMenu(
    Offset position, {
    MediaItem? clickedItem,
  }) async {
    final fingerprints = await _loadFingerprints();

    if (!mounted) {
      return;
    }

    _flyoutController.showFlyout<void>(
      position: position,
      builder: (context) {
        final menuItems = <MenuFlyoutItemBase>[];

        final items = widget.group.items;

        // انتخاب کل گروه برای انتقال باید صریحاً از منو درخواست شود.
        menuItems.add(
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.checkbox_composite),
            text: const Text('انتخاب همه عکس‌های گروه برای انتقال'),
            onPressed: () {
              _flyoutController.close();
              widget.onSelectForTransfer?.call(items);
            },
          ),
        );
        menuItems.add(const MenuFlyoutSeparator());

        // =========================================================
        // تمام عکس‌های Duplicate
        // =========================================================

        for (var index = 0; index < items.length; index++) {
          final item = items[index];

          final detectedPersonIds = item.faces
              .map((face) => face.personId)
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          final fingerprint = fingerprints[item.path] ?? '';

          final rejectedPersonIds = <String>{};

          if (fingerprint.isNotEmpty &&
              fingerprint != 'missing' &&
              widget.faceDatabase != null) {
            rejectedPersonIds.addAll(
              widget.faceDatabase!.rejections
                  .where((rejection) => rejection.fingerprint == fingerprint)
                  .map((rejection) => rejection.personId)
                  .whereType<String>()
                  .map((id) => id.trim())
                  .where((id) => id.isNotEmpty)
                  .toSet(),
            );
          }

          // -------------------------------------------------------
          // نام فایل
          // -------------------------------------------------------

          final fileName = item.fileName.trim().isNotEmpty
              ? item.fileName
              : File(item.path).uri.pathSegments.isNotEmpty
              ? File(item.path).uri.pathSegments.last
              : 'عکس ${index + 1}';

          // -------------------------------------------------------
          // مشخص کردن عکس فعلی
          // -------------------------------------------------------

          final isClickedItem =
              clickedItem != null && clickedItem.path == item.path;

          final isSelectedItem = widget.group.selectedIndex == index;

          String title;

          if (isClickedItem) {
            title = 'عکس ${index + 1} — $fileName  ← عکس انتخاب‌شده';
          } else if (isSelectedItem) {
            title = 'عکس ${index + 1} — $fileName  ← عکس اصلی';
          } else {
            title = 'عکس ${index + 1} — $fileName';
          }

          // -------------------------------------------------------
          // عنوان عکس
          // -------------------------------------------------------

          menuItems.add(
            MenuFlyoutItem(
              leading: Icon(
                isClickedItem ? FluentIcons.photo2 : FluentIcons.photo,
              ),
              text: Text(title, overflow: TextOverflow.ellipsis),
              onPressed: () {
                // فقط عنوان عکس است؛
                // برای جلوگیری از انتخاب ناخواسته چیزی انجام نمی‌دهیم.
              },
            ),
          );

          // -------------------------------------------------------
          // تشخیص‌های فعلی
          // -------------------------------------------------------

          if (detectedPersonIds.isNotEmpty) {
            for (final personId in detectedPersonIds) {
              final name = widget.faceNameResolver?.call(personId) ?? 'این شخص';

              menuItems.add(
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.clear),
                  text: Text(
                    '   عکس ${index + 1}: این عکس متعلق به «$name» نیست',
                  ),
                  onPressed: widget.onFaceAssignmentRejected == null
                      ? null
                      : () async {
                          _flyoutController.close();

                          await widget.onFaceAssignmentRejected!(
                            item,
                            personId,
                          );

                          if (mounted) {
                            setState(() {});
                          }

                          widget.onChanged?.call();
                        },
                ),
              );
            }
          }

          // -------------------------------------------------------
          // اصلاح‌های قبلی
          // -------------------------------------------------------

          if (rejectedPersonIds.isNotEmpty) {
            for (final personId in rejectedPersonIds) {
              final name = widget.faceNameResolver?.call(personId) ?? 'این شخص';

              menuItems.add(
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.undo),
                  text: Text('   عکس ${index + 1}: لغو اصلاح «$name»'),
                  onPressed: widget.onFaceRejectionCleared == null
                      ? null
                      : () async {
                          _flyoutController.close();

                          await widget.onFaceRejectionCleared!(item, personId);

                          if (mounted) {
                            setState(() {});
                          }

                          widget.onChanged?.call();
                        },
                ),
              );
            }
          }

          // -------------------------------------------------------
          // انتخاب صریح عکس برای انتقال
          // -------------------------------------------------------
          final isTransferSelected = widget.selectedPaths.any(
            (path) => path.replaceAll('\\', '/').trim().toLowerCase() ==
                item.path.replaceAll('\\', '/').trim().toLowerCase(),
          );
          menuItems.add(
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.checkbox_composite),
              text: Text(isTransferSelected
                  ? '   عکس ${index + 1}: لغو انتخاب برای انتقال'
                  : '   عکس ${index + 1}: انتخاب برای انتقال'),
              onPressed: () {
                _flyoutController.close();
                widget.onSelectForTransfer?.call([item]);
              },
            ),
          );

          // -------------------------------------------------------
          // فایل و پوشه همان عکس
          // -------------------------------------------------------

          menuItems.add(
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.open_folder_horizontal),
              text: Text('   عکس ${index + 1}: نمایش در File Explorer'),
              onPressed: () async {
                _flyoutController.close();

                await FileExplorerService.revealFile(item.path);
              },
            ),
          );

          menuItems.add(
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.folder_open),
              text: Text('   عکس ${index + 1}: باز کردن پوشه'),
              onPressed: () async {
                _flyoutController.close();

                await FileExplorerService.openFolder(
                  FileExplorerService.folderOf(item.path),
                );
              },
            ),
          );

          // -------------------------------------------------------
          // جداکننده بین عکس‌ها
          // -------------------------------------------------------

          if (index < items.length - 1) {
            menuItems.add(const MenuFlyoutSeparator());
          }
        }

        return MenuFlyout(items: menuItems);
      },
    );
  }

  /// هر لایه Stack
  Widget _imageLayer(MediaItem item, {required bool openPreviewOnTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      // فقط عکس اصلی Preview را باز می‌کند.
      onTap: openPreviewOnTap ? _openPreview : null,

      // اگر روی قسمت قابل مشاهده‌ی همین لایه راست‌کلیک شود،
      // همان عکس به عنوان clickedItem مشخص می‌شود.
      onSecondaryTapUp: (details) {
        // راست‌کلیک فقط منو را باز می‌کند؛ انتخاب با گزینه منو است.
        unawaited(_showContextMenu(details.globalPosition, clickedItem: item));
      },

      child: Container(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.group.items;

    if (items.isEmpty) {
      return const SizedBox(width: 110, height: 110);
    }

    final selectedIndex = widget.group.selectedIndex;

    final safeSelectedIndex = selectedIndex >= 0 && selectedIndex < items.length
        ? selectedIndex
        : 0;

    final selectedItem = items[safeSelectedIndex];

    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // راست‌کلیک روی هر قسمت از Stack
        // منوی تمام عکس‌های گروه را باز می‌کند.
        onSecondaryTapUp: (details) {
          // راست‌کلیک روی کارت گروه نباید خودش انتخاب را فعال کند.
          unawaited(
            _showContextMenu(details.globalPosition, clickedItem: selectedItem),
          );
        },

        child: SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // -----------------------------------------------------
              // لایه سوم
              // -----------------------------------------------------
              if (items.length > 2)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 12),
                    child: _imageLayer(items[2], openPreviewOnTap: false),
                  ),
                ),

              // -----------------------------------------------------
              // لایه دوم
              // -----------------------------------------------------
              if (items.length > 1)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 6),
                    child: _imageLayer(items[1], openPreviewOnTap: false),
                  ),
                ),

              // -----------------------------------------------------
              // لایه اصلی / انتخاب شده
              // -----------------------------------------------------
              Positioned.fill(
                child: _imageLayer(selectedItem, openPreviewOnTap: true),
              ),

              // -----------------------------------------------------
              // تعداد تصاویر
              // -----------------------------------------------------
              Positioned(
                right: -6,
                bottom: -6,
                child: InfoBadge(source: Text('${items.length}')),
              ),

              // -----------------------------------------------------
              // آیکون Duplicate
              // -----------------------------------------------------
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
}
