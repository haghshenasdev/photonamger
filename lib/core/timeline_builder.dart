import '../ui/models/media_item.dart';
import '../ui/models/timeline_group.dart';

class TimelineBuilder {
  List<TimelineGroup> build(
    List<MediaItem> items, {
    Duration gap = const Duration(minutes: 30),
    void Function(int current, int total, String status)? onProgress,
  }) {
    if (items.isEmpty) {
      return <TimelineGroup>[];
    }

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // const gapMinutes = 30;
    final gapMinutes = gap.inMinutes;

    List<TimelineGroup> groups = [];

    List<MediaItem> current = [];

    current.add(items.first);

    for (int i = 1; i < items.length; i++) {
      onProgress?.call(i, items.length, "در حال دسته‌بندی زمانی...");

      final previous = items[i - 1];

      final currentItem = items[i];

      final diff = currentItem.createdAt.difference(previous.createdAt);

      if (diff.inMinutes > gapMinutes) {
        final group = _createGroup(groups.length + 1, current);

        groups.add(group);

        current = [];
      }

      current.add(currentItem);
    }

    if (current.isNotEmpty) {
      final group = _createGroup(groups.length + 1, current);

      groups.add(group);
    }

    onProgress?.call(items.length, items.length, "دسته‌بندی زمانی پایان یافت");

    return groups;
  }

  TimelineGroup _createGroup(int index, List<MediaItem> items) {
    return TimelineGroup(
      title: 'گروه $index',

      start: items.first.createdAt,

      end: items.last.createdAt,

      items: List.from(items),
    );
  }

  List<TimelineGroup> rebuild(
    List<MediaItem> items,
){
    return build(items);
}

TimelineGroup merge(
    List<TimelineGroup> groups,
){
    groups.sort(
        (a,b)=>
            a.start.compareTo(
                b.start,
            ),
    );

    final items=<MediaItem>[];

    for(final g in groups){
        items.addAll(g.items);
    }

    items.sort(
        (a,b)=>
            a.createdAt.compareTo(
                b.createdAt,
            ),
    );

    return TimelineGroup(
        title:"گروه ادغام شده",
        start:items.first.createdAt,
        end:items.last.createdAt,
        items:items,
    );
}

}
