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

  late List<List<TextEditingController>> _categoryControllers;

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.metadata?.description ?? '',
    );

    final paths = widget.metadata?.categories ?? const [];

    _categoryControllers = paths.map((path) {
      return path.map((value) => TextEditingController(text: value)).toList();
    }).toList();
  }

  @override
  void dispose() {
    _descriptionController.dispose();

    for (final path in _categoryControllers) {
      for (final controller in path) {
        controller.dispose();
      }
    }

    super.dispose();
  }

  void _addCategoryPath() {
    setState(() {
      _categoryControllers.add([TextEditingController()]);
    });
  }

  void _addLevel(int pathIndex) {
    setState(() {
      _categoryControllers[pathIndex].add(TextEditingController());
    });
  }

  void _removeLevel(int pathIndex, int levelIndex) {
    final path = _categoryControllers[pathIndex];

    if (path.length == 1) {
      _removeCategoryPath(pathIndex);
      return;
    }

    final controller = path.removeAt(levelIndex);

    controller.dispose();

    setState(() {});
  }

  void _removeCategoryPath(int pathIndex) {
    final path = _categoryControllers.removeAt(pathIndex);

    for (final controller in path) {
      controller.dispose();
    }

    setState(() {});
  }

  List<List<String>> _getCategories() {
    final result = <List<String>>[];

    for (final path in _categoryControllers) {
      final values = path
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (values.isNotEmpty) {
        result.add(values);
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

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),

      title: Row(
        children: [
          const Icon(FluentIcons.folder_open, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('اطلاعات گروه')),
        ],
      ),

      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoLabel(
              label: 'گروه',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[20],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[60]),
                ),
                child: Text(
                  widget.groupTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'دسته‌بندی‌ها',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            const SizedBox(height: 5),

            Text(
              'برای هر دسته‌بندی می‌توانی چند سطح تعریف کنی و چند مسیر مختلف را همزمان انتخاب کنی.',
              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
            ),

            const SizedBox(height: 12),

            if (_categoryControllers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[60]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('هنوز دسته‌بندی انتخاب نشده است.'),
              ),

            for (
              int pathIndex = 0;
              pathIndex < _categoryControllers.length;
              pathIndex++
            )
              _buildCategoryPath(pathIndex),

            const SizedBox(height: 8),

            Button(
              onPressed: _addCategoryPath,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 14),
                  SizedBox(width: 6),
                  Text('افزودن دسته‌بندی'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_getCategories().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[20],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دسته‌بندی‌های انتخاب‌شده',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    for (final path in _getCategories())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(path.join('  >  ')),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            const Text(
              'توضیحات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            const SizedBox(height: 8),

            TextBox(
              controller: _descriptionController,
              placeholder: 'توضیحات مربوط به این گروه...',
              minLines: 4,
              maxLines: 7,
            ),
          ],
        ),
      ),

      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('انصراف'),
        ),

        FilledButton(
          onPressed: _save,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.save, size: 15),
              SizedBox(width: 6),
              Text('ذخیره'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPath(int pathIndex) {
    final path = _categoryControllers[pathIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[60]),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Row(
            children: [
              Text(
                'دسته ${pathIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const Spacer(),

              IconButton(
                icon: const Icon(FluentIcons.delete),
                onPressed: () {
                  _removeCategoryPath(pathIndex);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          for (int levelIndex = 0; levelIndex < path.length; levelIndex++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),

              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: Text(
                      '${levelIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: TextBox(
                      controller: path[levelIndex],

                      placeholder: levelIndex == 0
                          ? 'مثلاً گرگاب'
                          : 'مثلاً ملاقات',

                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(FluentIcons.delete),
                    onPressed: () {
                      _removeLevel(pathIndex, levelIndex);
                    },
                  ),
                ],
              ),
            ),

          Button(
            onPressed: () {
              _addLevel(pathIndex);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add, size: 14),
                SizedBox(width: 6),
                Text('افزودن سطح'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
