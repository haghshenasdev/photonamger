import 'package:fluent_ui/fluent_ui.dart';

class FolderSelector extends StatelessWidget {

  final String path;

  final VoidCallback onSelect;

  const FolderSelector({
    super.key,
    required this.path,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {

    return Card(
      child: Row(
        children: [

          Expanded(
            child: TextBox(
              readOnly: true,
              placeholder: path.isEmpty
                  ? "پوشه تصاویر را انتخاب کنید"
                  : path,
            ),
          ),

          const SizedBox(width: 10),

          FilledButton(
            child: const Text("انتخاب پوشه"),
            onPressed: onSelect,
          )
        ],
      ),
    );
  }
}