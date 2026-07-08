import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:fgphoto/core/channel/read_chanel.dart';
import 'package:fgphoto/core/utils/persian_date.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fgphoto/ui/widgets/title_select_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'persian_date_field.dart';
import 'time_field.dart';

class TimelineGroupCard extends StatefulWidget {
  final List<TimelineGroup> groups;

  final TimelineGroup? selectedGroup;
  final ValueChanged<TimelineGroup> onGroupSelected;

  /// وقتی یک گروه تغییر کرد
  final ValueChanged<TimelineGroup> onGroupUpdated;

  /// درخواست پردازش مجدد (Rebuild timeline / regroup)
  final VoidCallback onReprocessRequested;

  /// ادغام گروه‌ها
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
  final Set<int> expandedGroups = {};
  final Set<int> selectedForMerge = {};

  bool readingChannel = false;

  double channelProgress = 0;

  String channelStatus = "";

  int channelCurrent = 0;

  int channelTotal = 0;

  final List<String> suggestedTitles = [];

  final Map<int, TextEditingController> _controllers = {};

  TextEditingController _controllerFor(int index, String text) {
    return _controllers.putIfAbsent(
      index,
      () => TextEditingController(text: text),
    );
  }

  void _notifyUpdate(TimelineGroup group, {bool reprocess = false}) {
    widget.onGroupUpdated(group);

    if (reprocess) {
      widget.onReprocessRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'دسته بندی زمانی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),

                /// MERGE BUTTON
                if (selectedForMerge.isNotEmpty) ...[
                  if (selectedForMerge.length > 1)
                    FilledButton(
                      child: Text('ادغام (${selectedForMerge.length})'),
                      onPressed: () {
                        final groups = selectedForMerge
                            .map((i) => widget.groups[i])
                            .toList();

                        widget.onGroupsMerged(groups);

                        setState(() {
                          selectedForMerge.clear();
                        });
                      },
                    ),
                  const SizedBox(width: 8),

                  Button(
                    child: const Text('لغو انتخاب'),
                    onPressed: () {
                      setState(() {
                        selectedForMerge.clear();
                      });
                    },
                  ),
                ],
                const SizedBox(width: 8),

                Tooltip(
                  message: 'بازسازی دسته‌بندی ها',
                  child: IconButton(
                    icon: const Icon(FluentIcons.refresh),
                    onPressed: widget.onResetTimeline,
                  ),
                ),

                FilledButton(
                  child: const Text("پیشنهاد عنوان"),

                  onPressed: () async {
                    final rc = ReadChannelService(
                      predictor: CategoryPredictor(),
                    );

                    final oldestDate = widget.groups
                        .map((e) => e.start)
                        .reduce((a, b) => a.isBefore(b) ? a : b);
                    final posts = rc.read(oldestDate: oldestDate);
                    final remainingPosts = List<ChannelPost>.from(await posts);

                    // مرتب‌سازی بر اساس زمان
                    remainingPosts.sort((a, b) => a.date.compareTo(b.date));

                    suggestedTitles.clear();

                    for (final group in widget.groups) {
                      ChannelPost? bestPost;
                      Duration? bestDistance;

                      for (final post in remainingPosts) {
                        // پست قبل از اولین عکس است => غیرمجاز
                        if (post.date.isBefore(group.start)) {
                          continue;
                        }

                        final distance = post.date.difference(group.end).abs();

                        if (bestDistance == null || distance < bestDistance) {
                          bestDistance = distance;
                          bestPost = post;
                        }
                      }

                      if (bestPost != null) {
                        group.title = bestPost.title;

                        if (!suggestedTitles.contains(bestPost.title)) {
                          suggestedTitles.add(bestPost.title);
                        }

                        remainingPosts.remove(bestPost);
                      }
                    }

                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          /// LIST
          Expanded(
            child: widget.groups.isEmpty
                ? const Center(child: Text('گروهی یافت نشد'))
                : ListView.builder(
                    itemCount: widget.groups.length,
                    itemBuilder: (_, index) {
                      final group = widget.groups[index];
                      final isSelected = widget.selectedGroup == group;
                      final isExpanded = expandedGroups.contains(index);

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
                              /// HEADER ROW
                              GestureDetector(
                                onTap: () => widget.onGroupSelected(group),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      /// CHECKBOX FOR MERGE
                                      Checkbox(
                                        checked: selectedForMerge.contains(
                                          index,
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              selectedForMerge.add(index);
                                            } else {
                                              selectedForMerge.remove(index);
                                            }
                                          });
                                        },
                                      ),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.title,
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
                                              '${PersianDate.formatDateTime(group.start)}'
                                              ' تا '
                                              '${PersianDate.formatDateTime(group.end)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      IconButton(
                                        icon: Icon(
                                          isExpanded
                                              ? FluentIcons.chevron_up
                                              : FluentIcons.chevron_down,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (isExpanded) {
                                              expandedGroups.remove(index);
                                            } else {
                                              expandedGroups.add(index);
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              /// EXPANDED EDITOR
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// TITLE
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextBox(
                                              maxLines: null,
                                              minLines: null,

                                              inputFormatters: [
                                                FilteringTextInputFormatter.deny(
                                                  RegExp(r'[\n\r]'),
                                                ),
                                              ],

                                              controller: _controllerFor(
                                                index,
                                                group.title,
                                              ),

                                              onChanged: (value) {
                                                setState(() {
                                                  group.title = value;
                                                });

                                                _notifyUpdate(group);
                                              },
                                            ),
                                          ),

                                          IconButton(
                                            icon: const Icon(FluentIcons.more),

                                            onPressed: () async {
                                              final result =
                                                  await showDialog<String>(
                                                    context: context,

                                                    builder: (_) {
                                                      return TitleSelectDialog(
                                                        titles: suggestedTitles,
                                                        current: group.title,
                                                      );
                                                    },
                                                  );

                                              if (result != null) {
                                                setState(() {
                                                  group.title = result;

                                                  _controllerFor(
                                                    index,
                                                    group.title,
                                                  ).text = result;
                                                });

                                                _notifyUpdate(group);
                                              }
                                            },
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      const Text('شروع'),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: PersianDateField(
                                              value: group.start,
                                              onChanged: (date) {
                                                setState(() {
                                                  group.start = DateTime(
                                                    date.year,
                                                    date.month,
                                                    date.day,
                                                    group.start.hour,
                                                    group.start.minute,
                                                  );
                                                });
                                                _notifyUpdate(
                                                  group,
                                                  reprocess: true,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TimeField(
                                              value: group.start,
                                              onChanged: (date) {
                                                setState(() {
                                                  group.start = date;
                                                });
                                                _notifyUpdate(
                                                  group,
                                                  reprocess: true,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      const Text('پایان'),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: PersianDateField(
                                              value: group.end,
                                              onChanged: (date) {
                                                setState(() {
                                                  group.end = DateTime(
                                                    date.year,
                                                    date.month,
                                                    date.day,
                                                    group.end.hour,
                                                    group.end.minute,
                                                  );
                                                });
                                                _notifyUpdate(
                                                  group,
                                                  reprocess: true,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TimeField(
                                              value: group.end,
                                              onChanged: (date) {
                                                setState(() {
                                                  group.end = date;
                                                });
                                                _notifyUpdate(
                                                  group,
                                                  reprocess: true,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
}
