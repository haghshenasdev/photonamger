import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fluent_ui/fluent_ui.dart';

class GroupMetadataDialog extends StatefulWidget {
  final String groupTitle;
  final GroupMetadata? metadata;

  const GroupMetadataDialog({
    super.key,
    required this.groupTitle,
    this.metadata,
  });

  @override
  State<GroupMetadataDialog> createState() => _GroupMetadataDialogState();
}

class _GroupMetadataDialogState extends State<GroupMetadataDialog> {
  late final TextEditingController _descriptionController;

  final List<List<TextEditingController>> _categoryPaths = [];

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.metadata?.description ?? '',
    );

    final categories = widget.metadata?.categories ?? const [];

    for (final path in categories) {
      _categoryPaths.add(
        path.map((category) => TextEditingController(text: category)).toList(),
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
    if (pathIndex < 0 || pathIndex >= _categoryPaths.length) {
      return;
    }

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
    if (pathIndex < 0 || pathIndex >= _categoryPaths.length) {
      return;
    }

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

    if (path.length <= 1) {
      return;
    }

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
    final metadata = GroupMetadata(
      categories: _getCategories(),
      description: _descriptionController.text.trim(),
    );

    Navigator.of(context).pop(metadata);
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
                    placeholder: 'سطح ${levelIndex + 1}',
                  ),
                ),

                if (path.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 14),
                    onPressed: () {
                      _removeLevel(pathIndex, levelIndex);
                    },
                  ),
                ],
              ],
            ),

            if (levelIndex < path.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                child: Icon(FluentIcons.chevron_down, size: 14),
              ),
          ],

          const SizedBox(height: 8),

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

          const SizedBox(height: 8),

          Builder(
            builder: (_) {
              final preview = path
                  .map((controller) => controller.text.trim())
                  .where((value) => value.isNotEmpty)
                  .join(' > ');

              if (preview.isEmpty) {
                return const SizedBox.shrink();
              }

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
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
      title: Text('اطلاعات گروه: ${widget.groupTitle}'),
      content: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const Text(
                  'دسته‌بندی‌ها',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'برای هر دسته‌بندی می‌توانید چند سطح تعریف کنید و چند مسیر مستقل داشته باشید.',
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}
