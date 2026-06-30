import 'package:fgphoto/core/channel/channel_post.dart';

class ChannelPostSelection {
  final ChannelPost post;
  bool isSelected;

  ChannelPostSelection({
    required this.post,
    this.isSelected = false,
  });
}