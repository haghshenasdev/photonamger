import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:image/image.dart' as img;

import '../../core/analysis/face_database.dart';

class FacePeoplePanel extends StatefulWidget {
  final FaceDatabase database;
  final List<String> sourceRoots;
  final String? selectedPersonId;
  final ValueChanged<String?> onPersonSelected;
  final Future<void> Function(String personId, String name)? onRename;
  final Future<void> Function(String primaryPersonId, String secondaryPersonId)?
  onMerge;
  final List<FaceMergeSuggestion> suggestions;
  final ValueChanged<FaceMergeSuggestion>? onDismissSuggestion;
  final Future<void> Function()? onSearchByImage;

  const FacePeoplePanel({
    super.key,
    required this.database,
    required this.sourceRoots,
    required this.selectedPersonId,
    required this.onPersonSelected,
    this.onRename,
    this.onMerge,
    this.suggestions = const [],
    this.onDismissSuggestion,
    this.onSearchByImage,
  });

  @override
  State<FacePeoplePanel> createState() => _FacePeoplePanelState();
}

class _FacePeoplePanelState extends State<FacePeoplePanel> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  final Set<String> _mergeIds = <String>{};

  Map<String, int> _counts = const {};
  Map<String, StoredFace> _covers = const {};

  @override
  void initState() {
    super.initState();
    _rebuildFaceIndex();
  }

  @override
  void didUpdateWidget(covariant FacePeoplePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.database, widget.database)) {
      _rebuildFaceIndex();
    }

    if (!_sameRoots(oldWidget.sourceRoots, widget.sourceRoots)) {
      _rebuildFaceIndex();
    }
  }

  bool _sameRoots(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _rebuildFaceIndex() {
    final counts = <String, int>{};
    final covers = <String, StoredFace>{};
    final coverScores = <String, double>{};

    for (final face in widget.database.faces) {
      counts[face.personId] = (counts[face.personId] ?? 0) + 1;

      final score = _faceScore(face);
      final oldScore = coverScores[face.personId];

      if (oldScore == null || score > oldScore) {
        coverScores[face.personId] = score;
        covers[face.personId] = face;
      }
    }

    _counts = counts;
    _covers = covers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FacePerson> get _persons {
    final query = _query.trim().toLowerCase();

    final result = widget.database.persons.where((person) {
      if (query.isEmpty) return true;
      return person.name.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      final countCompare = (_counts[b.id] ?? 0).compareTo(_counts[a.id] ?? 0);

      if (countCompare != 0) {
        return countCompare;
      }

      return a.name.compareTo(b.name);
    });

    return result;
  }

  double _faceScore(StoredFace face) {
    final areaScore =
        math.sqrt(math.max(1.0, face.width * face.height)) / 180.0;

    return face.confidence * 0.65 + areaScore.clamp(0.0, 1.0) * 0.35;
  }

  FacePerson? _personById(String id) {
    for (final person in widget.database.persons) {
      if (person.id == id) return person;
    }
    return null;
  }

  Future<void> _rename(FacePerson person) async {
    if (widget.onRename == null) return;

    final controller = TextEditingController(text: person.name);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void saveName() {
          final value = controller.text.trim();
          if (value.isEmpty) return;
          Navigator.of(dialogContext).pop(value);
        }

        return ContentDialog(
          title: const Text('نام شخص'),
          content: TextBox(
            controller: controller,
            autofocus: true,
            placeholder: 'مثلاً مهدی',
            onSubmitted: (_) => saveName(),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: saveName,
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name != null && name.trim().isNotEmpty) {
      await widget.onRename!(person.id, name.trim());
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
    final first = _personById(ids[0]);
    final second = _personById(ids[1]);

    if (first == null || second == null) return;

    // انتخاب نام/شخص مقصد در HomePage انجام می‌شود: اگر فقط یکی نام دستی
    // داشته باشد همان خودکار حفظ می‌شود؛ اگر هر دو دستی باشند، آنجا سؤال می‌پرسیم.
    await widget.onMerge!(first.id, second.id);

    if (!mounted) return;

    setState(() => _mergeIds.clear());
  }

  Future<String?> _askPrimary(FacePerson first, FacePerson second) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('ادغام دو شخص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('همه چهره‌های شخص دوم به شخص اول منتقل می‌شوند.'),
              const SizedBox(height: 12),
              Text('شخص اول: ${first.name}'),
              Text('شخص دوم: ${second.name}'),
              const SizedBox(height: 12),
              const Text('کدام نام حفظ شود؟'),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            Button(
              onPressed: () => Navigator.of(context).pop(first.id),
              child: Text('حفظ «${first.name}»'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(second.id),
              child: Text('حفظ «${second.name}»'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mergeSuggestion(FaceMergeSuggestion suggestion) async {
    if (widget.onMerge == null) return;

    final first = _personById(suggestion.firstPersonId);
    final second = _personById(suggestion.secondPersonId);

    if (first == null || second == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('پیشنهاد ادغام افراد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('شباهت دو گروه: ${(suggestion.similarity * 100).round()}٪'),
            const SizedBox(height: 8),
            const Text('آیا این دو شخص متعلق به یک نفر هستند؟'),
            const SizedBox(height: 12),
            Text('• ${first.name}'),
            Text('• ${second.name}'),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ادغام'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onMerge!(first.id, second.id);
  }

  @override
  Widget build(BuildContext context) {
    final persons = _persons;

    return Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.contact, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'افراد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${widget.database.persons.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: FluentTheme.of(
                    context,
                  ).resources.textFillColorSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _searchController,
                  placeholder: 'جستجوی نام شخص...',
                  prefix: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: Icon(FluentIcons.search, size: 15),
                  ),
                  suffix: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(FluentIcons.clear, size: 12),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  onChanged: (value) {
                    setState(() => _query = value);
                  },
                ),
              ),
              if (widget.onSearchByImage != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'جستجو با عکس چهره',
                  child: Button(
                    onPressed: widget.onSearchByImage,
                    child: const Icon(FluentIcons.camera, size: 16),
                  ),
                ),
              ],
            ],
          ),

          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MergeSuggestions(
              suggestions: widget.suggestions,
              personById: _personById,
              coverByPerson: _covers,
              countByPerson: _counts,
              sourceRoots: widget.sourceRoots,
              onMerge: _mergeSuggestion,
              onDismiss: widget.onDismissSuggestion,
            ),
          ],

          if (_mergeIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoBar(
              title: Text(
                _mergeIds.length == 1
                    ? 'یک شخص برای ادغام انتخاب شده'
                    : 'دو شخص انتخاب شده‌اند',
              ),
              content: Text(
                _mergeIds.length == 1
                    ? 'شخص دوم را انتخاب کنید.'
                    : 'برای ادغام روی دکمه زیر بزنید.',
              ),
              severity: InfoBarSeverity.info,
            ),
          ],

          if (_mergeIds.length == 2) ...[
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _mergeSelected,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.link, size: 14),
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
                : ListView.builder(
                    cacheExtent: 700,
                    itemCount: persons.length,
                    itemBuilder: (context, index) {
                      final person = persons[index];
                      final selected = person.id == widget.selectedPersonId;
                      final merging = _mergeIds.contains(person.id);
                      final cover = _covers[person.id];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: HoverButton(
                          onPressed: () => widget.onPersonSelected(person.id),
                          builder: (context, states) {
                            return Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: merging
                                    ? FluentTheme.of(
                                        context,
                                      ).accentColor.withOpacity(0.18)
                                    : selected
                                    ? FluentTheme.of(
                                        context,
                                      ).accentColor.withOpacity(0.10)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: merging || selected
                                      ? FluentTheme.of(context).accentColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _FaceCrop(
                                    face: cover,
                                    sourceRoots: widget.sourceRoots,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_counts[person.id] ?? 0} چهره',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: FluentTheme.of(
                                              context,
                                            ).resources.textFillColorSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      merging
                                          ? FluentIcons.checkbox
                                          : FluentIcons.link,
                                      size: 14,
                                    ),
                                    onPressed: () => _toggleMerge(person.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      FluentIcons.edit,
                                      size: 13,
                                    ),
                                    onPressed: () => _rename(person),
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
              onPressed: () => widget.onPersonSelected(null),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.clear, size: 13),
                  SizedBox(width: 6),
                  Text('نمایش همه تصاویر'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),
          Text(
            'دوبار کلیک: تغییر نام  •  زنجیر: انتخاب برای ادغام',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: FluentTheme.of(context).resources.textFillColorTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MergeSuggestions extends StatelessWidget {
  final List<FaceMergeSuggestion> suggestions;
  final FacePerson? Function(String id) personById;
  final Map<String, StoredFace> coverByPerson;
  final Map<String, int> countByPerson;
  final List<String> sourceRoots;
  final Future<void> Function(FaceMergeSuggestion suggestion) onMerge;
  final ValueChanged<FaceMergeSuggestion>? onDismiss;

  const _MergeSuggestions({
    required this.suggestions,
    required this.personById,
    required this.coverByPerson,
    required this.countByPerson,
    required this.sourceRoots,
    required this.onMerge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final shown = suggestions;

    return Expander(
      header: Row(
        children: [
          const Icon(FluentIcons.lightbulb, size: 15),
          const SizedBox(width: 6),
          const Expanded(child: Text('پیشنهادهای ادغام افراد')),
          InfoBadge(source: Text('${suggestions.length}')),
        ],
      ),
      content: SizedBox(
        height: math.min(360.0, math.max(90.0, shown.length * 58.0)).toDouble(),
        child: ListView.builder(
          itemCount: shown.length,
          itemBuilder: (context, index) {
            final suggestion = shown[index];
            return _SuggestionRow(
              suggestion: suggestion,
              first: personById(suggestion.firstPersonId),
              second: personById(suggestion.secondPersonId),
              firstCover: coverByPerson[suggestion.firstPersonId],
              secondCover: coverByPerson[suggestion.secondPersonId],
              firstCount: countByPerson[suggestion.firstPersonId] ?? 0,
              secondCount: countByPerson[suggestion.secondPersonId] ?? 0,
              sourceRoots: sourceRoots,
              onMerge: onMerge,
              onDismiss: onDismiss,
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final FaceMergeSuggestion suggestion;
  final FacePerson? first;
  final FacePerson? second;
  final StoredFace? firstCover;
  final StoredFace? secondCover;
  final int firstCount;
  final int secondCount;
  final List<String> sourceRoots;
  final Future<void> Function(FaceMergeSuggestion suggestion) onMerge;
  final ValueChanged<FaceMergeSuggestion>? onDismiss;

  const _SuggestionRow({
    required this.suggestion,
    required this.first,
    required this.second,
    required this.firstCover,
    required this.secondCover,
    required this.firstCount,
    required this.secondCount,
    required this.sourceRoots,
    required this.onMerge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (first == null || second == null) {
      return const SizedBox.shrink();
    }

    final percent = (suggestion.similarity * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: FluentTheme.of(context).resources.controlFillColorSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _FaceCrop(face: firstCover, sourceRoots: sourceRoots, size: 42),
            const SizedBox(width: 5),
            _FaceCrop(face: secondCover, sourceRoots: sourceRoots, size: 42),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${first!.name}  ↔  ${second!.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'شباهت $percent٪  •  '
                    '$firstCount / $secondCount چهره',
                    style: TextStyle(
                      fontSize: 10,
                      color: FluentTheme.of(
                        context,
                      ).resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.link, size: 14),
              onPressed: () => onMerge(suggestion),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(FluentIcons.cancel, size: 14),
                onPressed: () => onDismiss!(suggestion),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared crop cache
// ---------------------------------------------------------------------------
//
// The previous implementation created a new state + file decode every time
// a row entered the viewport. With many people this made scrolling stutter.
// Keeping a bounded shared Future cache makes returning to a row effectively
// free after its first decode.
// ---------------------------------------------------------------------------

Future<Uint8List?> _createFaceCropIsolate(Map<String, dynamic> data) async {
  final path = data['path']?.toString() ?? '';
  if (path.isEmpty) return null;

  final file = File(path);
  if (!await file.exists()) return null;

  try {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final leftValue = (data['left'] as num?)?.toDouble() ?? 0;
    final topValue = (data['top'] as num?)?.toDouble() ?? 0;
    final widthValue = (data['width'] as num?)?.toDouble() ?? 0;
    final heightValue = (data['height'] as num?)?.toDouble() ?? 0;

    final largest = math.max(decoded.width, decoded.height);
    final analysisScale = largest > 1600 ? largest / 1600.0 : 1.0;

    final left = leftValue * analysisScale;
    final top = topValue * analysisScale;
    final width = widthValue * analysisScale;
    final height = heightValue * analysisScale;
    final padding = math.max(width, height) * 0.35;

    final cropLeft = math.max(0, (left - padding).round());
    final cropTop = math.max(0, (top - padding).round());
    final cropRight = math.min(decoded.width, (left + width + padding).round());
    final cropBottom = math.min(
      decoded.height,
      (top + height + padding).round(),
    );

    final cropWidth = math.max(1, cropRight - cropLeft);
    final cropHeight = math.max(1, cropBottom - cropTop);

    final cropped = img.copyCrop(
      decoded,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );

    final resized = img.copyResize(
      cropped,
      width: 160,
      height: 160,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: 84));
  } catch (_) {
    return null;
  }
}

class _FaceCropCache {
  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};
  static final List<String> _order = <String>[];
  static const int _maxEntries = 300;

  static Future<Uint8List?> get(StoredFace face, List<String> sourceRoots) {
    final key = '${face.id}|${face.rootKey}|${face.relativePath}';
    final existing = _cache[key];
    if (existing != null) return existing;

    final path = const FaceDatabaseService().resolveStoredPath(
      face,
      sourceRoots,
    );

    final future = compute(_createFaceCropIsolate, <String, dynamic>{
      'path': path,
      'left': face.left,
      'top': face.top,
      'width': face.width,
      'height': face.height,
    });

    _cache[key] = future;
    _order.add(key);

    while (_order.length > _maxEntries) {
      final oldKey = _order.removeAt(0);
      _cache.remove(oldKey);
    }

    return future;
  }
}

class _FaceCrop extends StatelessWidget {
  final StoredFace? face;
  final List<String> sourceRoots;
  final double size;

  const _FaceCrop({
    required this.face,
    required this.sourceRoots,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    final current = face;

    if (current == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FluentTheme.of(context).resources.controlFillColorSecondary,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(FluentIcons.contact, size: 22),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _FaceCropCache.get(current, sourceRoots),
      builder: (context, snapshot) {
        final bytes = snapshot.data;

        return ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: size,
            height: size,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  )
                : Container(
                    color: FluentTheme.of(
                      context,
                    ).resources.controlFillColorSecondary,
                    child: const Icon(FluentIcons.contact, size: 22),
                  ),
          ),
        );
      },
    );
  }
}
