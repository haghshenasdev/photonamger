import 'package:fgphoto/core/utils/persian_date.dart';
import 'package:fgphoto/ui/dialogs/group_metadata_dialog.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fgphoto/ui/widgets/title_select_dialog.dart';
import 'package:fgphoto/ui/widgets/title_suggestion_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'persian_date_field.dart';
import 'time_field.dart';

class TimelineGroupCard extends StatefulWidget {
  final List<TimelineGroup> groups;

  final TimelineGroup? selectedGroup;

  final ValueChanged<TimelineGroup> onGroupSelected;

  final ValueChanged<TimelineGroup> onGroupUpdated;

  final VoidCallback onReprocessRequested;

  final void Function(List<TimelineGroup> groups) onGroupsMerged;

  final VoidCallback onResetTimeline;

  const TimelineGroupCard({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
    required this.onGroupUpdated,
    required this.onReprocessRequested,
    required this.onGroupsMerged,
    required this.onResetTimeline,
  });

  @override
  State<TimelineGroupCard> createState() => _TimelineGroupCardState();
}

class _TimelineGroupCardState extends State<TimelineGroupCard> {
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  final Set<int> expandedGroups = <int>{};

  final Set<int> selectedForMerge = <int>{};

  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{};

  final Map<int, FlyoutController> _flyoutControllers =
      <int, FlyoutController>{};

  final List<String> suggestedTitles = <String>[];

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    for (final controller in _flyoutControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  TextEditingController _controllerFor(int index, String text) {
    final existing = _controllers[index];

    if (existing != null) {
      if (existing.text != text && !existing.value.composing.isValid) {
        existing.text = text;
        existing.selection = TextSelection.collapsed(
          offset: existing.text.length,
        );
      }

      return existing;
    }

    final controller = TextEditingController(text: text);

    _controllers[index] = controller;

    return controller;
  }

  FlyoutController _flyoutControllerFor(int index) {
    return _flyoutControllers.putIfAbsent(index, () => FlyoutController());
  }

  String _normalizeSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _groupMatchesSearch(TimelineGroup group) {
    final query = _normalizeSearchText(_searchQuery);

    if (query.isEmpty) {
      return true;
    }

    final values = <String>[
      group.title,
      group.description,
      group.metadataDirectory ?? '',
    ];

    // تمام بخش‌های مسیر پوشه
    final metadataDirectory = group.metadataDirectory;

    if (metadataDirectory != null && metadataDirectory.isNotEmpty) {
      values.addAll(
        metadataDirectory
            .replaceAll('\\', '/')
            .split('/')
            .where((part) => part.trim().isNotEmpty),
      );
    }

    // دسته‌بندی‌ها
    for (final path in group.categories) {
      values.addAll(path);
    }

    final searchableText = _normalizeSearchText(
      values.where((value) => value.trim().isNotEmpty).join(' '),
    );

    return searchableText.contains(query);
  }

  bool _groupMatchesCategory(TimelineGroup group) {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return true;
    }

    final selected = _normalizeSearchText(_selectedCategory!);

    for (final path in group.categories) {
      for (final category in path) {
        if (_normalizeSearchText(category) == selected) {
          return true;
        }
      }
    }

    return false;
  }

  List<String> _availableCategories() {
    final categories = <String>{};

    for (final group in widget.groups) {
      for (final path in group.categories) {
        for (final category in path) {
          final value = category.trim();

          if (value.isNotEmpty) {
            categories.add(value);
          }
        }
      }
    }

    final result = categories.toList();

    result.sort(
      (a, b) => _normalizeSearchText(a).compareTo(_normalizeSearchText(b)),
    );

    return result;
  }

  List<TimelineGroup> get _filteredGroups {
    return widget.groups.where((group) {
      return _groupMatchesSearch(group) && _groupMatchesCategory(group);
    }).toList();
  }

  void _notifyUpdate(TimelineGroup group, {bool reprocess = false}) {
    widget.onGroupUpdated(group);

    if (reprocess) {
      widget.onReprocessRequested();
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (expandedGroups.contains(index)) {
        expandedGroups.remove(index);
      } else {
        expandedGroups.add(index);
      }
    });
  }

  String _categoryText(TimelineGroup group) {
    return group.categories
        .map(
          (path) => path
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .join(' > '),
        )
        .where((path) => path.isNotEmpty)
        .join(' | ');
  }

  Future<void> _editGroupMetadata(TimelineGroup group) async {
    final result = await showDialog<GroupMetadata>(
      context: context,
      builder: (_) {
        return GroupMetadataDialog(
          groupTitle: group.title,
          metadata: group.metadata,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      group.metadata = result;
      group.edited = true;
    });

    _notifyUpdate(group);
  }

  void _removeGroup(int index) {
    if (index < 0 || index >= widget.groups.length) {
      return;
    }

    setState(() {
      widget.groups.removeAt(index);

      expandedGroups.remove(index);
      selectedForMerge.remove(index);

      final oldController = _controllers.remove(index);
      oldController?.dispose();

      final oldFlyout = _flyoutControllers.remove(index);
      oldFlyout?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'دسته بندی زمانی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const Spacer(),

                if (selectedForMerge.isNotEmpty) ...[
                  if (selectedForMerge.length > 1)
                    FilledButton(
                      onPressed: () {
                        final selectedGroups = selectedForMerge
                            .where(
                              (index) =>
                                  index >= 0 && index < widget.groups.length,
                            )
                            .map((index) => widget.groups[index])
                            .toList();

                        if (selectedGroups.length < 2) {
                          return;
                        }

                        widget.onGroupsMerged(selectedGroups);

                        setState(() {
                          selectedForMerge.clear();
                        });
                      },
                      child: Text('ادغام (${selectedForMerge.length})'),
                    ),

                  const SizedBox(width: 8),

                  Button(
                    onPressed: () {
                      setState(() {
                        selectedForMerge.clear();
                      });
                    },
                    child: const Text('لغو انتخاب'),
                  ),
                ],

                if (selectedForMerge.isEmpty) ...[
                  Tooltip(
                    message: 'بازسازی دسته‌بندی‌ها',
                    child: IconButton(
                      icon: const Icon(FluentIcons.refresh),
                      onPressed: widget.onResetTimeline,
                    ),
                  ),

                  FilledButton(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) {
                          return TitleSuggestionDialog(
                            groups: widget.groups,
                            suggestedTitles: suggestedTitles,
                            onFinished: () {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          );
                        },
                      );
                    },
                    child: const Text('پیشنهاد عنوان'),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Column(
              children: [
                TextBox(
                  controller: _searchController,
                  prefix: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: Icon(FluentIcons.search, size: 15),
                  ),
                  placeholder: 'جستجو در نام گروه، پوشه و توضیحات...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                IconButton(
                  icon: const Icon(FluentIcons.clear, size: 14),
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = null;
                    });
                  },
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(FluentIcons.filter, size: 14),

                    const SizedBox(width: 6),

                    const Text('دسته‌بندی:', style: TextStyle(fontSize: 12)),

                    const SizedBox(width: 8),

                    Expanded(
                      child: ComboBox<String?>(
                        value: _selectedCategory,
                        isExpanded: true,
                        placeholder: const Text('همه دسته‌بندی‌ها'),
                        items: [
                          const ComboBoxItem<String?>(
                            value: null,
                            child: Text('همه دسته‌بندی‌ها'),
                          ),
                          ..._availableCategories().map((category) {
                            return ComboBoxItem<String?>(
                              value: category,
                              child: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      ),
                    ),

                    if (_searchQuery.isNotEmpty ||
                        _selectedCategory != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(FluentIcons.clear, size: 14),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),

                if (_searchQuery.isNotEmpty || _selectedCategory != null) ...[
                  const SizedBox(height: 5),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${_filteredGroups.length} گروه از ${widget.groups.length} گروه',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _filteredGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.search, size: 28),
                        const SizedBox(height: 10),
                        Text(
                          widget.groups.isEmpty
                              ? 'گروهی یافت نشد'
                              : 'گروهی با این فیلتر پیدا نشد',
                        ),
                        if (_searchQuery.isNotEmpty ||
                            _selectedCategory != null) ...[
                          const SizedBox(height: 10),
                          Button(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = null;
                              });
                            },
                            child: const Text('حذف فیلتر'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredGroups.length,
                    itemBuilder: (_, index) {
                      final group = _filteredGroups[index];

                      final isSelected = identical(widget.selectedGroup, group);

                      final isExpanded = expandedGroups.contains(index);

                      final flyoutController = _flyoutControllerFor(index);

                      final categoryText = _categoryText(group);

                      return Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey[80],
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              FlyoutTarget(
                                controller: flyoutController,
                                child: GestureDetector(
                                  onTap: () {
                                    if (selectedForMerge.isNotEmpty) {
                                      setState(() {
                                        if (selectedForMerge.contains(index)) {
                                          selectedForMerge.remove(index);
                                        } else {
                                          selectedForMerge.add(index);
                                        }
                                      });

                                      return;
                                    }

                                    widget.onGroupSelected(group);
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      selectedForMerge.add(index);
                                    });

                                    widget.onGroupSelected(group);
                                  },
                                  onSecondaryTapUp: (details) {
                                    flyoutController.showFlyout(
                                      position: details.globalPosition,
                                      builder: (context) {
                                        return MenuFlyout(
                                          items: [
                                            MenuFlyoutItem(
                                              leading: const Icon(
                                                FluentIcons.checkbox_composite,
                                              ),
                                              text: const Text('انتخاب'),
                                              onPressed: () {
                                                Navigator.pop(context);

                                                setState(() {
                                                  selectedForMerge.add(index);
                                                });

                                                widget.onGroupSelected(group);
                                              },
                                            ),
                                            MenuFlyoutItem(
                                              leading: const Icon(
                                                FluentIcons.edit,
                                              ),
                                              text: const Text('ویرایش'),
                                              onPressed: () {
                                                Navigator.pop(context);

                                                setState(() {
                                                  expandedGroups.add(index);
                                                });

                                                widget.onGroupSelected(group);
                                              },
                                            ),
                                            MenuFlyoutItem(
                                              leading: const Icon(
                                                FluentIcons.info,
                                              ),
                                              text: const Text('اطلاعات گروه'),
                                              onPressed: () {
                                                Navigator.pop(context);

                                                _editGroupMetadata(group);

                                                widget.onGroupSelected(group);
                                              },
                                            ),
                                            const MenuFlyoutSeparator(),
                                            MenuFlyoutItem(
                                              leading: const Icon(
                                                FluentIcons.delete,
                                              ),
                                              text: const Text('حذف'),
                                              onPressed: () {
                                                Navigator.pop(context);

                                                _removeGroup(index);
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (selectedForMerge.isNotEmpty)
                                          Checkbox(
                                            checked: selectedForMerge.contains(
                                              index,
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedForMerge.add(index);
                                                } else {
                                                  selectedForMerge.remove(
                                                    index,
                                                  );
                                                }
                                              });
                                            },
                                          ),

                                        const SizedBox(width: 4),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                group.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              const SizedBox(height: 4),

                                              Text(
                                                '${group.items.length} فایل',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),

                                              Text(
                                                '${PersianDate.formatDateTime(group.start)} تا ${PersianDate.formatDateTime(group.end)}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),

                                              if (categoryText.isNotEmpty) ...[
                                                const SizedBox(height: 5),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Padding(
                                                      padding: EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                      child: Icon(
                                                        FluentIcons.folder,
                                                        size: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        categoryText,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                group.metadata == null
                                                    ? FluentIcons.info
                                                    : FluentIcons.info_solid,
                                              ),
                                              onPressed: () {
                                                _editGroupMetadata(group);
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isExpanded
                                                    ? FluentIcons.chevron_up
                                                    : FluentIcons.chevron_down,
                                              ),
                                              onPressed: () {
                                                _toggleExpanded(index);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              if (isExpanded)
                                _buildExpandedEditor(index, group),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedEditor(int index, TimelineGroup group) {
    final titleController = _controllerFor(index, group.title);

    final categoryText = _categoryText(group);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[20],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ویرایش گروه',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextBox(
                    controller: titleController,
                    maxLines: 1,
                    minLines: 1,
                    placeholder: 'عنوان گروه',
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                    ],
                    onChanged: (value) {
                      group.title = value;
                      group.edited = true;

                      widget.onGroupUpdated(group);
                    },
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  icon: const Icon(FluentIcons.more),
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (_) {
                        return TitleSelectDialog(
                          titles: suggestedTitles,
                          current: group.title,
                        );
                      },
                    );

                    if (result == null || !mounted) {
                      return;
                    }

                    group.title = result;
                    group.edited = true;

                    final controller = _controllerFor(index, result);

                    controller.text = result;
                    controller.selection = TextSelection.collapsed(
                      offset: result.length,
                    );

                    setState(() {});

                    _notifyUpdate(group);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _editGroupMetadata(group);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          group.metadata == null
                              ? FluentIcons.add
                              : FluentIcons.edit,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          group.metadata == null
                              ? 'افزودن اطلاعات گروه'
                              : 'ویرایش اطلاعات گروه',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (categoryText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                categoryText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],

            const SizedBox(height: 12),

            const Text('شروع', style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: PersianDateField(
                    value: group.start,
                    onChanged: (date) {
                      group.start = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        group.start.hour,
                        group.start.minute,
                      );

                      group.edited = true;

                      _notifyUpdate(group, reprocess: true);
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TimeField(
                    value: group.start,
                    onChanged: (date) {
                      group.start = date;
                      group.edited = true;

                      _notifyUpdate(group, reprocess: true);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text('پایان', style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: PersianDateField(
                    value: group.end,
                    onChanged: (date) {
                      group.end = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        group.end.hour,
                        group.end.minute,
                      );

                      group.edited = true;

                      _notifyUpdate(group, reprocess: true);
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TimeField(
                    value: group.end,
                    onChanged: (date) {
                      group.end = date;
                      group.edited = true;

                      _notifyUpdate(group, reprocess: true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
