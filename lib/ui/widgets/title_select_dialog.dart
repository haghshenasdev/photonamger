import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

class TitleSelectDialog extends StatefulWidget {
  final List<String> titles;
  final List<ChannelPost> posts;

  final String current;

  const TitleSelectDialog({
    super.key,
    required this.titles,
    this.posts = const [],
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
    final filteredPosts = widget.posts
        .where((post) => post.title.contains(search))
        .toList();
    final filteredTitles = widget.titles
        .where((title) => title.contains(search))
        .toList();
    final hasPosts = widget.posts.isNotEmpty;
    final visibleCount = hasPosts ? filteredPosts.length : filteredTitles.length;
    final totalCount = hasPosts ? widget.posts.length : widget.titles.length;
    final dialogHeight = (MediaQuery.of(context).size.height * 0.75)
        .clamp(400.0, 700.0)
        .toDouble();

    return ContentDialog(
      title: const Text("انتخاب عنوان گروه"),

      content: SizedBox(
        width: 500,

        height: dialogHeight,

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

            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'تعداد عنوان‌های استخراج‌شده: ${hasPosts ? widget.posts.length : widget.titles.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'نمایش $visibleCount از $totalCount عنوان',
                style: const TextStyle(fontSize: 12),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: hasPosts
                    ? filteredPosts.length
                    : filteredTitles.length,

                itemBuilder: (_, index) {
                  if (hasPosts) {
                    final post = filteredPosts[index];
                    final localDate = post.date.toLocal();
                    final jalali = Jalali.fromDateTime(localDate);
                    final date =
                        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
                    final time =
                        '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      title: Text(post.title),
                      subtitle: Text('$date  $time'),
                      onPressed: () => Navigator.pop(context, post.title),
                    );
                  }
                  final title = filteredTitles[index];

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
