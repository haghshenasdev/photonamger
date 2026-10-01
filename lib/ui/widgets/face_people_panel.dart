import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:image/image.dart' as img;

import '../../core/analysis/face_database.dart';

class FacePeoplePanel extends StatefulWidget {
  final FaceDatabase database;
  final List<String> sourceRoots;
  final String? selectedPersonId;
  final ValueChanged<String?> onPersonSelected;
  final Future<void> Function(String personId, String name)? onRename;
  final Future<void> Function(
    String primaryPersonId,
    String secondaryPersonId,
  )? onMerge;

  const FacePeoplePanel({
    super.key,
    required this.database,
    required this.sourceRoots,
    required this.selectedPersonId,
    required this.onPersonSelected,
    this.onRename,
    this.onMerge,
  });

  @override
  State<FacePeoplePanel> createState() => _FacePeoplePanelState();
}

class _FacePeoplePanelState extends State<FacePeoplePanel> {
  final TextEditingController _searchController =
      TextEditingController();

  String _query = '';

  /// IDs selected for manual merge.
  final Set<String> _mergeIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FacePerson> get _persons {
    final query = _query.trim().toLowerCase();

    final counts = <String, int>{};

    for (final face in widget.database.faces) {
      counts.update(
        face.personId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final result = widget.database.persons.where((person) {
      if (query.isEmpty) return true;
      return person.name.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      final countCompare =
          (counts[b.id] ?? 0).compareTo(
        counts[a.id] ?? 0,
      );

      if (countCompare != 0) {
        return countCompare;
      }

      return a.name.compareTo(b.name);
    });

    return result;
  }

  StoredFace? _coverFace(FacePerson person) {
    final faces = widget.database.faces
        .where((face) => face.personId == person.id)
        .toList();

    if (faces.isEmpty) return null;

    faces.sort((a, b) {
      final aScore = _faceScore(a);
      final bScore = _faceScore(b);
      return bScore.compareTo(aScore);
    });

    return faces.first;
  }

  double _faceScore(StoredFace face) {
    final areaScore =
        math.sqrt(
          math.max(
            1.0,
            face.width * face.height,
          ),
        ) /
        180.0;

    return face.confidence * 0.65 +
        areaScore.clamp(0.0, 1.0) * 0.35;
  }

  int _count(FacePerson person) {
    final keys = <String>{};

    for (final face in widget.database.faces) {
      if (face.personId == person.id) {
        keys.add(
          '${face.rootKey}|${face.relativePath.toLowerCase()}',
        );
      }
    }

    return keys.length;
  }

  Future<void> _rename(FacePerson person) async {
    if (widget.onRename == null) return;

    final controller = TextEditingController(
      text: person.name,
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('نام شخص'),
          content: TextBox(
            controller: controller,
            autofocus: true,
            placeholder: 'مثلاً مهدی',
            onSubmitted: (_) => Navigator.of(context)
                .pop(controller.text.trim()),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop(controller.text.trim()),
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name != null && name.trim().isNotEmpty) {
      await widget.onRename!(
        person.id,
        name.trim(),
      );
    }
  }

  void _toggleMerge(String id) {
    setState(() {
      if (_mergeIds.contains(id)) {
        _mergeIds.remove(id);
      } else {
        if (_mergeIds.length >= 2) {
          _mergeIds.remove(_mergeIds.first);
        }
        _mergeIds.add(id);
      }
    });
  }

  Future<void> _mergeSelected() async {
    if (widget.onMerge == null || _mergeIds.length != 2) {
      return;
    }

    final ids = _mergeIds.toList();

    FacePerson? first;
    FacePerson? second;

    for (final person in widget.database.persons) {
      if (person.id == ids[0]) first = person;
      if (person.id == ids[1]) second = person;
    }

    if (first == null || second == null) return;

    final primary = await showDialog<String>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('ادغام دو شخص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'همه چهره‌های شخص دوم به شخص اول منتقل می‌شوند.',
              ),
              const SizedBox(height: 14),
              Text(
                'شخص اول: ${first!.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'شخص دوم: ${second!.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'کدام نام حفظ شود؟',
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            Button(
              onPressed: () =>
                  Navigator.of(context).pop(first!.id),
              child: Text('حفظ «${first!.name}»'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(second!.id),
              child: Text('حفظ «${second!.name}»'),
            ),
          ],
        );
      },
    );

    if (primary == null) return;

    final secondary =
        primary == first.id ? second.id : first.id;

    await widget.onMerge!(
      primary,
      secondary,
    );

    if (!mounted) return;

    setState(() {
      _mergeIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final persons = _persons;

    return Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                FluentIcons.contact,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'افراد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${widget.database.persons.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: FluentTheme.of(context)
                      .resources
                      .textFillColorSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextBox(
            controller: _searchController,
            placeholder: 'جستجوی نام شخص...',
            prefix: const Padding(
              padding: EdgeInsetsDirectional.only(
                start: 8,
              ),
              child: Icon(
                FluentIcons.search,
                size: 15,
              ),
            ),
            suffix: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      FluentIcons.clear,
                      size: 12,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            onChanged: (value) {
              setState(() => _query = value);
            },
          ),

          if (_mergeIds.length == 1) ...[
            const SizedBox(height: 8),
            InfoBar(
              title: const Text(
                'یک شخص برای ادغام انتخاب شده',
              ),
              content: const Text(
                'یک شخص دیگر را انتخاب کنید.',
              ),
              severity: InfoBarSeverity.info,
            ),
          ],

          if (_mergeIds.length == 2) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _mergeSelected,
              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.link,
                    size: 14,
                  ),
                  SizedBox(width: 7),
                  Text('ادغام دو شخص انتخاب‌شده'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          Expanded(
            child: persons.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'هنوز چهره‌ای دسته‌بندی نشده است.'
                          : 'موردی پیدا نشد.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: persons.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final person = persons[index];

                      final selected =
                          person.id ==
                              widget.selectedPersonId;

                      final merging =
                          _mergeIds.contains(person.id);

                      final cover =
                          _coverFace(person);

                      return GestureDetector(
                        onDoubleTap: () =>
                            _rename(person),
                        child: HoverButton(
                          onPressed: () =>
                              widget.onPersonSelected(
                            person.id,
                          ),
                          builder: (
                            context,
                            states,
                          ) {
                            return Container(
                              padding:
                                  const EdgeInsets.all(7),
                              decoration:
                                  BoxDecoration(
                                color: merging
                                    ? FluentTheme.of(
                                        context,
                                      )
                                        .accentColor
                                        .withOpacity(
                                          0.18,
                                        )
                                    : selected
                                        ? FluentTheme.of(
                                            context,
                                          )
                                            .accentColor
                                            .withOpacity(
                                              0.10,
                                            )
                                        : null,
                                borderRadius:
                                    BorderRadius.circular(
                                  8,
                                ),
                                border: Border.all(
                                  color: merging
                                      ? FluentTheme.of(
                                          context,
                                        ).accentColor
                                      : selected
                                          ? FluentTheme.of(
                                              context,
                                            ).accentColor
                                          : Colors
                                              .transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      _FaceCrop(
                                        face: cover,
                                        sourceRoots:
                                            widget
                                                .sourceRoots,
                                      ),
                                      if (merging)
                                        Positioned(
                                          right: 2,
                                          top: 2,
                                          child:
                                              Container(
                                            width: 18,
                                            height: 18,
                                            decoration:
                                                BoxDecoration(
                                              color: FluentTheme
                                                      .of(
                                                context,
                                              )
                                                  .accentColor,
                                              shape: BoxShape
                                                  .circle,
                                            ),
                                            child:
                                                const Icon(
                                              FluentIcons.check_mark,
                                              size: 11,
                                              color: Colors
                                                  .white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(width: 9),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          person.name,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          '${_count(person)} تصویر',
                                          style:
                                              TextStyle(
                                            fontSize: 11,
                                            color: FluentTheme
                                                    .of(
                                              context,
                                            )
                                                .resources
                                                .textFillColorSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      merging
                                          ? FluentIcons
                                              .checkbox
                                          : FluentIcons
                                              .link,
                                      size: 14,
                                    ),
                                    onPressed: () =>
                                        _toggleMerge(
                                      person.id,
                                    ),
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      FluentIcons.edit,
                                      size: 13,
                                    ),
                                    onPressed: () =>
                                        _rename(person),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),

          if (widget.selectedPersonId != null) ...[
            const SizedBox(height: 8),
            Button(
              onPressed: () =>
                  widget.onPersonSelected(null),
              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.clear,
                    size: 13,
                  ),
                  SizedBox(width: 6),
                  Text('نمایش همه تصاویر'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),

          Text(
            'دوبار کلیک: تغییر نام  •  آیکون زنجیر: انتخاب برای ادغام',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: FluentTheme.of(context)
                  .resources
                  .textFillColorTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CROPPED FACE
// ============================================================================

class _FaceCrop extends StatefulWidget {
  final StoredFace? face;
  final List<String> sourceRoots;

  const _FaceCrop({
    required this.face,
    required this.sourceRoots,
  });

  @override
  State<_FaceCrop> createState() => _FaceCropState();
}

class _FaceCropState extends State<_FaceCrop> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _createCrop();
  }

  @override
  void didUpdateWidget(covariant _FaceCrop oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.face?.id != widget.face?.id) {
      _future = _createCrop();
    }
  }

  Future<Uint8List?> _createCrop() async {
    final face = widget.face;
    if (face == null) return null;

    final path =
        const FaceDatabaseService().resolveStoredPath(
      face,
      widget.sourceRoots,
    );

    final file = File(path);

    if (!await file.exists()) {
      return null;
    }

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return null;
      }

      final source = decoded;

      // Face coordinates were generated after the recognition engine
      // resized the longest side to 1600px. Reconstruct that scale so
      // the crop is correct on the original image.
      final largest = math.max(
        source.width,
        source.height,
      );

      final analysisScale =
          largest > 1600
              ? largest / 1600.0
              : 1.0;

      final left =
          face.left * analysisScale;

      final top =
          face.top * analysisScale;

      final width =
          face.width * analysisScale;

      final height =
          face.height * analysisScale;

      // Add some context around the face so it doesn't look unnaturally
      // tight. 35% padding is especially useful for hair and jawline.
      final padding =
          math.max(width, height) * 0.35;

      final cropLeft = math.max(
        0,
        (left - padding).round(),
      );

      final cropTop = math.max(
        0,
        (top - padding).round(),
      );

      final cropRight = math.min(
        source.width,
        (left + width + padding).round(),
      );

      final cropBottom = math.min(
        source.height,
        (top + height + padding).round(),
      );

      final cropWidth =
          math.max(1, cropRight - cropLeft);

      final cropHeight =
          math.max(1, cropBottom - cropTop);

      final cropped = img.copyCrop(
        source,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );

      final resized = img.copyResize(
        cropped,
        width: 160,
        height: 160,
        interpolation:
            img.Interpolation.average,
      );

      return Uint8List.fromList(
        img.encodeJpg(
          resized,
          quality: 88,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        return ClipRRect(
          borderRadius:
              BorderRadius.circular(7),
          child: SizedBox(
            width: 58,
            height: 58,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Container(
                    color: FluentTheme.of(
                      context,
                    )
                        .resources
                        .controlFillColorSecondary,
                    child: const Icon(
                      FluentIcons.contact,
                      size: 22,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
