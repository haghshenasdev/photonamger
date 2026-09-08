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

  late List<TextEditingController> _categoryControllers;

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.metadata?.description ?? '',
    );

    final categories = widget.metadata?.categories ?? const <String>[];

    _categoryControllers = categories
        .map((category) => TextEditingController(text: category))
        .toList();
  }

  @override
  void dispose() {
    _descriptionController.dispose();

    for (final controller in _categoryControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _addCategory() {
    setState(() {
      _categoryControllers.add(TextEditingController());
    });
  }

  void _removeCategory(int index) {
    final controller = _categoryControllers.removeAt(index);

    controller.dispose();

    setState(() {});
  }

  List<String> _getCategories() {
    return _categoryControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
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
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
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
            // --------------------------------------------------
            // نام گروه
            // --------------------------------------------------
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

            const SizedBox(height: 20),

            // --------------------------------------------------
            // دسته‌بندی
            // --------------------------------------------------
            const Text(
              'دسته‌بندی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            const SizedBox(height: 5),

            Text(
              'ترتیب موارد از دسته اصلی به دسته فرعی است.',
              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
            ),

            const SizedBox(height: 10),

            if (_categoryControllers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[60]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('برای این گروه هنوز دسته‌بندی ثبت نشده است.'),
              ),

            for (int index = 0; index < _categoryControllers.length; index++)
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
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: TextBox(
                        controller: _categoryControllers[index],
                        placeholder: index == 0 ? 'مثلاً سفر' : 'مثلاً ایران',
                      ),
                    ),

                    const SizedBox(width: 4),

                    IconButton(
                      icon: const Icon(FluentIcons.delete),
                      onPressed: () {
                        _removeCategory(index);
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 4),

            Button(
              onPressed: _addCategory,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 14),
                  SizedBox(width: 6),
                  Text('افزودن سطح دسته‌بندی'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --------------------------------------------------
            // Preview مسیر
            // --------------------------------------------------
            if (_categoryControllers.isNotEmpty)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _categoryControllers.first,
                builder: (context, value, child) {
                  final categories = _getCategories();

                  if (categories.isEmpty) {
                    return const SizedBox();
                  }

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[20],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(FluentIcons.folder, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(categories.join('  >  '))),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // --------------------------------------------------
            // توضیحات
            // --------------------------------------------------
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
}
