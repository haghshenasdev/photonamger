import 'package:fgphoto/core/channel/channel_post.dart';

import 'media_item.dart';

class TimelineGroup {
  String title;

  DateTime start;

  DateTime end;

  List<MediaItem> items;

  List<ChannelPost> suggestions;

  /// آیا کاربر این گروه را ویرایش کرده؟
  bool edited;

  /// آیا این گروه Merge شده؟
  bool merged;

  TimelineGroup({
    required this.title,
    required this.start,
    required this.end,
    required this.items,

    this.edited = false,

    this.merged = false,
    List<ChannelPost>? suggestions,
  }): suggestions = suggestions ?? [];
}
