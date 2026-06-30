import 'analysis_stage.dart';

class AnalysisProgress {
  final AnalysisStage stage;

  final int current;

  final int total;

  final String message;

  const AnalysisProgress({
    required this.stage,
    required this.current,
    required this.total,
    required this.message,
  });

  double get percent {
    if (total == 0) return 0;
    return current / total;
  }

  bool get finished => stage == AnalysisStage.finished;

  bool get cancelled => stage == AnalysisStage.cancelled;
}
