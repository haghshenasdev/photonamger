import '../../ui/models/duplicate_group.dart';
import '../../ui/models/timeline_group.dart';

class AnalysisResult {
  final bool cancelled;

  final List<TimelineGroup> timelineGroups;

  final List<DuplicateGroup> duplicateGroups;

  const AnalysisResult({
    required this.cancelled,
    required this.timelineGroups,
    required this.duplicateGroups,
  });
}