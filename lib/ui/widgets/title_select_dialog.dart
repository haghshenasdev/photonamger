import 'package:fluent_ui/fluent_ui.dart';

class TitleSelectDialog extends StatefulWidget {
  final List<String> titles;

  final String current;

  const TitleSelectDialog({
    super.key,
    required this.titles,
    required this.current,
  });

  @override
  State<TitleSelectDialog> createState() => _TitleSelectDialogState();
}

class _TitleSelectDialogState extends State<TitleSelectDialog> {
  String search = "";
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.titles.where((e) => e.contains(search)).toList();

    return ContentDialog(
      title: const Text("انتخاب عنوان گروه"),

      content: SizedBox(
        width: 500,

        height: 400,

        child: Column(
          children: [
            TextBox(
              controller: _searchController,

              focusNode: _searchFocusNode,

              placeholder: "جستجوی عنوان...",

              onChanged: (value) {
                setState(() {
                  search = value;
                });
              },
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,

                itemBuilder: (_, index) {
                  final title = filtered[index];

                  return ListTile(
                    title: Text(title),

                    onPressed: () {
                      Navigator.pop(context, title);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      actions: [
        Button(
          child: const Text("انصراف"),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
