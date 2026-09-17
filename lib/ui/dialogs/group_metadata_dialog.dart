import 'package:fgphoto/core/metadata/category_tree_builder.dart';
import 'package:fgphoto/ui/models/category_node.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fluent_ui/fluent_ui.dart';

class GroupMetadataDialog extends StatefulWidget {
  final String groupTitle;
  final GroupMetadata? metadata;

  /// تمام گروه‌های موجود پروژه برای ساخت درخت دسته‌بندی‌ها.
  final List<TimelineGroup> groups;

  const GroupMetadataDialog({
    super.key,
    required this.groupTitle,
    this.metadata,
    this.groups = const <TimelineGroup>[],
  });

  @override
  State<GroupMetadataDialog> createState() => _GroupMetadataDialogState();
}

class _GroupMetadataDialogState extends State<GroupMetadataDialog> {
  late final TextEditingController _descriptionController;

  final List<List<TextEditingController>> _categoryPaths = [];
  final Map<String, bool> _expandedSuggestions = <String, bool>{};

  List<CategoryNode> get _categoryTree =>
      CategoryTreeBuilder().build(widget.groups);

  /// همه مسیرهای موجود را به شکل یکتا برمی‌گرداند.
  List<List<String>> get _existingPaths {
    final result = <String, List<String>>{};

    void walk(List<CategoryNode> nodes, List<String> parent) {
      for (final node in nodes) {
        final path = [...parent, node.name];
        final key = path.join('\u0000');
        result[key] = path;
        walk(node.children, path);
      }
    }

    walk(_categoryTree, const []);
    return result.values.toList();
  }

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.metadata?.description ?? '',
    );

    final categories = widget.metadata?.categories ?? const <List<String>>[];

    for (final path in categories) {
      _categoryPaths.add(
        path
            .map((category) => TextEditingController(text: category))
            .toList(),
      );
    }

    if (_categoryPaths.isEmpty) {
      _addPath();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();

    for (final path in _categoryPaths) {
      for (final controller in path) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  void _addPath() {
    setState(() {
      _categoryPaths.add([TextEditingController()]);
    });
  }

  void _removePath(int pathIndex) {
    if (pathIndex < 0 || pathIndex >= _categoryPaths.length) return;

    final path = _categoryPaths.removeAt(pathIndex);
    for (final controller in path) {
      controller.dispose();
    }

    if (_categoryPaths.isEmpty) {
      _categoryPaths.add([TextEditingController()]);
    }

    setState(() {});
  }

  void _addLevel(int pathIndex) {
    if (pathIndex < 0 || pathIndex >= _categoryPaths.length) return;

    setState(() {
      _categoryPaths[pathIndex].add(TextEditingController());
    });
  }

  void _removeLevel(int pathIndex, int levelIndex) {
    if (pathIndex < 0 ||
        pathIndex >= _categoryPaths.length ||
        levelIndex < 0 ||
        levelIndex >= _categoryPaths[pathIndex].length) {
      return;
    }

    final path = _categoryPaths[pathIndex];
    if (path.length <= 1) return;

    final controller = path.removeAt(levelIndex);
    controller.dispose();
    setState(() {});
  }

  List<List<String>> _getCategories() {
    final result = <List<String>>[];

    for (final path in _categoryPaths) {
      final categories = path
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (categories.isNotEmpty) {
        result.add(categories);
      }
    }

    return result;
  }

  void _save() {
    Navigator.of(context).pop(
      GroupMetadata(
        categories: _getCategories(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  void _setPath(int pathIndex, List<String> selectedPath) {
    if (pathIndex < 0 || pathIndex >= _categoryPaths.length) return;

    final oldPath = _categoryPaths[pathIndex];
    for (final controller in oldPath) {
      controller.dispose();
    }

    _categoryPaths[pathIndex] = selectedPath
        .map((value) => TextEditingController(text: value))
        .toList();

    if (_categoryPaths[pathIndex].isEmpty) {
      _categoryPaths[pathIndex].add(TextEditingController());
    }

    setState(() {});
  }

  Future<void> _choosePathFromTree(int pathIndex) async {
    if (_categoryTree.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => ContentDialog(
          title: const Text('دسته‌بندی موجودی نیست'),
          content: const Text(
            'هنوز هیچ دسته‌بندی ثبت‌شده‌ای در گروه‌های پروژه وجود ندارد.\n'
            'می‌توانید دسته‌بندی جدید را مستقیماً در کادرها وارد کنید.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('باشه'),
            ),
          ],
        ),
      );
      return;
    }

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CategoryTreePickerDialog(tree: _categoryTree),
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      _setPath(pathIndex, selected);
    }
  }

  List<List<String>> _suggestionsFor(String query, int pathIndex, int levelIndex) {
    final normalized = query.trim().toLowerCase();

    final suggestions = <String, List<String>>{};

    for (final path in _existingPaths) {
      if (levelIndex >= path.length) continue;

      // سطح‌های قبل از این سطح باید با مسیر فعلی هماهنگ باشند.
      bool prefixMatches = true;
      final currentPath = _categoryPaths[pathIndex];
      for (int i = 0; i < levelIndex && i < currentPath.length; i++) {
        final current = currentPath[i].text.trim();
        if (current.isEmpty ||
            path[i].toLowerCase() != current.toLowerCase()) {
          prefixMatches = false;
          break;
        }
      }
      if (!prefixMatches) continue;

      final value = path[levelIndex].trim();
      if (value.isEmpty) continue;

      if (normalized.isNotEmpty &&
          !value.toLowerCase().contains(normalized)) {
        continue;
      }

      suggestions[path.join(' > ')] = path;
    }

    final result = suggestions.values.toList();
    result.sort((a, b) {
      final av = a[levelIndex].toLowerCase();
      final bv = b[levelIndex].toLowerCase();
      return av.compareTo(bv);
    });

    return result.take(8).toList();
  }

  Widget _buildSuggestions({
    required int pathIndex,
    required int levelIndex,
    required TextEditingController controller,
  }) {
    final suggestions = _suggestionsFor(
      controller.text,
      pathIndex,
      levelIndex,
    );

    if (suggestions.isEmpty) return const SizedBox.shrink();

    final key = '$pathIndex-$levelIndex';
    final expanded = _expandedSuggestions[key] ?? true;

    return Container(
      margin: const EdgeInsets.only(top: 5, bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[70]),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Button(
            onPressed: () {
              setState(() {
                _expandedSuggestions[key] = !expanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  expanded
                      ? FluentIcons.chevron_down
                      : FluentIcons.chevron_left,
                  size: 12,
                ),
                const SizedBox(width: 5),
                Text('پیشنهادهای موجود (${suggestions.length})'),
              ],
            ),
          ),
          if (expanded)
            for (final path in suggestions)
              ListTile(
                title: Text(path.last),
                subtitle: Text(
                  path.join(' > '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(FluentIcons.add, size: 14),
                onPressed: () {
                  _setPath(pathIndex, path);
                },
              ),
        ],
      ),
    );
  }

  Widget _buildPathCard(int pathIndex) {
    final path = _categoryPaths[pathIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[80]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'مسیر دسته‌بندی ${pathIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Button(
                onPressed: () => _removePath(pathIndex),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14),
                    SizedBox(width: 5),
                    Text('حذف مسیر'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          for (int levelIndex = 0; levelIndex < path.length; levelIndex++) ...[
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: path[levelIndex],
                    placeholder: 'سطح ${levelIndex + 1} — می‌توانید نام جدید بنویسید',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (path.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 14),
                    onPressed: () => _removeLevel(pathIndex, levelIndex),
                  ),
                ],
              ],
            ),

            _buildSuggestions(
              pathIndex: pathIndex,
              levelIndex: levelIndex,
              controller: path[levelIndex],
            ),

            if (levelIndex < path.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                child: Icon(FluentIcons.chevron_down, size: 14),
              ),
          ],

          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Button(
                onPressed: () => _addLevel(pathIndex),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 14),
                    SizedBox(width: 5),
                    Text('افزودن سطح'),
                  ],
                ),
              ),
              Button(
                onPressed: () => _choosePathFromTree(pathIndex),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.bulleted_list, size: 14),
                    SizedBox(width: 5),
                    Text('انتخاب از گروه‌های موجود'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Builder(
            builder: (_) {
              final preview = path
                  .map((controller) => controller.text.trim())
                  .where((value) => value.isNotEmpty)
                  .join(' > ');

              if (preview.isEmpty) return const SizedBox.shrink();

              return Text(
                preview,
                style: TextStyle(fontSize: 12, color: Colors.blue),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
      title: Text('اطلاعات گروه: ${widget.groupTitle}'),
      content: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'دسته‌بندی‌ها',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_existingPaths.isNotEmpty)
                      Text(
                        '${_existingPaths.length} مسیر موجود',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'می‌توانید نام دسته‌بندی جدید را آزادانه وارد کنید یا از دسته‌بندی‌های موجود انتخاب کنید. هنگام تایپ، موارد مشابه از دسته‌بندی‌های موجود پیشنهاد می‌شوند.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),

                for (int index = 0; index < _categoryPaths.length; index++)
                  _buildPathCard(index),

                Button(
                  onPressed: _addPath,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.add, size: 14),
                      SizedBox(width: 6),
                      Text('افزودن مسیر دسته‌بندی'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'توضیحات',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextBox(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 7,
                  placeholder: 'توضیحات مربوط به این گروه...',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(onPressed: _save, child: const Text('ذخیره')),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}

class _CategoryTreePickerDialog extends StatefulWidget {
  final List<CategoryNode> tree;

  const _CategoryTreePickerDialog({required this.tree});

  @override
  State<_CategoryTreePickerDialog> createState() =>
      _CategoryTreePickerDialogState();
}

class _CategoryTreePickerDialogState extends State<_CategoryTreePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expanded = <String>{};

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _containsSearch(CategoryNode node, String query) {
    if (query.isEmpty) return true;
    if (node.name.toLowerCase().contains(query)) return true;
    return node.children.any((child) => _containsSearch(child, query));
  }

  Widget _buildNode(
    CategoryNode node,
    List<String> parentPath,
  ) {
    final path = [...parentPath, node.name];
    final key = path.join(' > ');
    final hasChildren = node.children.isNotEmpty;
    final matches = _containsSearch(node, _search);

    if (!matches) return const SizedBox.shrink();

    final forceExpand = _search.isNotEmpty && node.children.any(
      (child) => _containsSearch(child, _search),
    );
    final expanded = forceExpand || _expanded.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: hasChildren
                    ? IconButton(
                        icon: Icon(
                          expanded
                              ? FluentIcons.chevron_down
                              : FluentIcons.chevron_left,
                          size: 12,
                        ),
                        onPressed: () {
                          setState(() {
                            if (expanded) {
                              _expanded.remove(key);
                            } else {
                              _expanded.add(key);
                            }
                          });
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ListTile(
                  title: Text(node.name),
                  subtitle: Text(
                    path.join(' > '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(FluentIcons.check_mark, size: 14),
                  onPressed: () => Navigator.pop(context, path),
                ),
              ),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Column(
              children: [
                for (final child in node.children)
                  _buildNode(child, path),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 650),
      title: const Text('انتخاب دسته‌بندی از گروه‌های موجود'),
      content: Column(
        children: [
          TextBox(
            controller: _searchController,
            placeholder: 'جستجو در دسته‌بندی‌های موجود...',
            onChanged: (value) {
              setState(() {
                _search = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final node in widget.tree) _buildNode(node, const []),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}
