import 'package:fgphoto/core/metadata/category_learning_service.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CategorySuggestionDialog extends StatefulWidget {
  final List<TimelineGroup> groups;
  final CategoryLearningModel model;
  final CategoryLearningService service;

  const CategorySuggestionDialog({
    super.key,
    required this.groups,
    required this.model,
    required this.service,
  });

  @override
  State<CategorySuggestionDialog> createState() =>
      _CategorySuggestionDialogState();
}

class _CategorySuggestionDialogState
    extends State<CategorySuggestionDialog> {
  late final List<_SuggestionRowData> _rows;

  @override
  void initState() {
    super.initState();

    _rows = <_SuggestionRowData>[];

    for (final group in widget.groups) {
      // گروه‌های دارای دسته‌بندی قبلی را دست نمی‌زنیم.
      if (group.categories.isNotEmpty) continue;

      final suggestions = widget.service.suggest(
        widget.model,
        group.title,
        top: 3,
      );

      if (suggestions.isEmpty) continue;

      _rows.add(
        _SuggestionRowData(
          group: group,
          suggestions: suggestions,
        ),
      );
    }
  }

  void _apply() {
    var applied = 0;

    for (final row in _rows) {
      if (!row.selected) continue;

      final suggestion = row.selectedSuggestion;
      if (suggestion == null) continue;

      row.group.metadata = GroupMetadata(
        categories: [
          List<String>.from(suggestion.path),
        ],
        description: row.group.description,
      );

      row.group.edited = true;
      applied++;
    }

    Navigator.of(context).pop(applied);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(
        maxWidth: 780,
        maxHeight: 720,
      ),
      title: const Text('پیشنهاد دسته‌بندی بر اساس عنوان'),
      content: _rows.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'برای عنوان‌های فعلی پیشنهاد قابل اعتمادی پیدا نشد.\n\n'
                  'ابتدا چند گروه را به‌صورت دستی دسته‌بندی کنید؛ '
                  'آرشینو از همان گروه‌ها برای یادگیری استفاده می‌کند.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'فقط گروه‌هایی که هنوز دسته‌بندی ندارند نمایش داده شده‌اند. '
                  'پیشنهادها را بررسی کنید و سپس موارد دلخواه را اعمال کنید.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _rows.length,
                    cacheExtent: 300,
                    itemBuilder: (context, index) {
                      return _buildRow(_rows[index]);
                    },
                  ),
                ),
              ],
            ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _rows.any((row) => row.selected)
              ? _apply
              : null,
          child: Text(
            'اعمال (${_rows.where((row) => row.selected).length})',
          ),
        ),
      ],
    );
  }

  Widget _buildRow(_SuggestionRowData row) {
    final selected = row.selectedSuggestion;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: row.selected
              ? FluentTheme.of(context).accentColor
              : Colors.grey[80],
          width: row.selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            checked: row.selected,
            onChanged: (value) {
              setState(() {
                row.selected = value == true;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.group.title.isEmpty
                      ? 'بدون عنوان'
                      : row.group.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ComboBox<CategorySuggestion>(
                  isExpanded: true,
                  value: selected,
                  items: [
                    for (final suggestion in row.suggestions)
                      ComboBoxItem<CategorySuggestion>(
                        value: suggestion,
                        child: Text(
                          '${suggestion.path.join(' > ')}'
                          '  •  ${suggestion.matchedWords} واژه',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      row.selectedSuggestion = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRowData {
  final TimelineGroup group;
  final List<CategorySuggestion> suggestions;

  bool selected = true;
  CategorySuggestion? selectedSuggestion;

  _SuggestionRowData({
    required this.group,
    required this.suggestions,
  }) : selectedSuggestion = suggestions.first;
}
