import 'duplicate_group.dart';
import 'media_item.dart';

enum PreviewType {
  media,
  duplicate,
}

class PreviewItem {
  final PreviewType type;

  final MediaItem? media;

  final DuplicateGroup? duplicate;

  const PreviewItem.media(this.media)
      : duplicate = null,
        type = PreviewType.media;

  const PreviewItem.duplicate(this.duplicate)
      : media = null,
        type = PreviewType.duplicate;

  bool get isMedia => type == PreviewType.media;

  bool get isDuplicate => type == PreviewType.duplicate;
}