import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fgphoto/ui/models/media_item.dart';

class GridItem {

  final MediaItem? media;

  final DuplicateGroup? duplicateGroup;

  bool get isDuplicateGroup =>
      duplicateGroup != null;

  GridItem.media(this.media)
      : duplicateGroup = null;

  GridItem.duplicate(this.duplicateGroup)
      : media = null;
}