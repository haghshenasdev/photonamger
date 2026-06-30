import '../../ui/models/timeline_group.dart';
import 'channel_post.dart';

class ChannelTitleMatcher {
  /// اختلاف مجاز بین تاریخ گروه و تاریخ پست
  final Duration tolerance;

  const ChannelTitleMatcher({
    this.tolerance = const Duration(days: 2),
  });

  void applyTitles(
    List<TimelineGroup> groups,
    List<ChannelPost> posts,
  ) {
    for (final group in groups) {
      final post = _findBestPost(group, posts);

      if (post != null) {
        group.title = post.title;
      }
    }
  }

  ChannelPost? _findBestPost(
    TimelineGroup group,
    List<ChannelPost> posts,
  ) {
    ChannelPost? best;

    Duration? bestDiff;

    for (final post in posts) {
      final diff = group.start.difference(post.date).abs();

      if (diff > tolerance) {
        continue;
      }

      if (best == null || diff < bestDiff!) {
        best = post;
        bestDiff = diff;
      }
    }

    return best;
  }
}