import '../../ui/models/timeline_group.dart';
import 'channel_post.dart';

class ChannelMatcher {
  /// حداکثر اختلاف مجاز بین زمان گروه و پست
  final Duration tolerance;

  const ChannelMatcher({this.tolerance = const Duration(days: 2)});

  void match({
    required List<TimelineGroup> groups,
    required List<ChannelPost> posts,
  }) {
    for (final group in groups) {
      group.suggestions.clear();

      final start = group.start.subtract(tolerance);
      final end = group.end.add(tolerance);

      for (final post in posts) {
        if (post.date.isBefore(start)) {
          continue;
        }

        if (post.date.isAfter(end)) {
          continue;
        }

        group.suggestions.add(post);
      }

      group.suggestions.sort((a, b) {
        final da = _distance(group, a);
        final db = _distance(group, b);
        return da.compareTo(db);
      });
    }
  }

  Duration _distance(TimelineGroup group, ChannelPost post) {
    final center = DateTime.fromMillisecondsSinceEpoch(
      (group.start.millisecondsSinceEpoch + group.end.millisecondsSinceEpoch) ~/
          2,
    );

    return center.difference(post.date).abs();
  }
}
