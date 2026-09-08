import 'package:fgphoto/core/apply/folder_builder.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/group_metadata.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';

import 'metadata_service.dart';

class MetadataSaveService {
  final MetadataService metadataService;

  MetadataSaveService({MetadataService? metadataService})
    : metadataService = metadataService ?? const MetadataService();

  Future<int> save({
    required List<TimelineGroup> groups,
    required ApplySettings settings,
  }) async {
    int count = 0;

    for (final group in groups) {
      if (!group.edited && group.metadata == null) {
        continue;
      }

      final directory = await FolderBuilder.build(
        settings: settings,
        group: group,
      );

      final metadata = group.metadata ?? const GroupMetadata();

      await metadataService.save(
        directoryPath: directory.path,
        metadata: metadata,
      );

      group.edited = false;

      count++;
    }

    return count;
  }
}
