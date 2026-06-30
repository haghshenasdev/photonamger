import 'package:fgphoto/core/analysis/analysis_progress.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ApplyBar extends StatelessWidget {
  final VoidCallback onApply;

  final int mediaItems_length;
  final AnalysisProgress? progress;

  final VoidCallback onPause;

  final VoidCallback onResume;

  final VoidCallback onCancel;

  bool get isAnalyzing =>
      progress != null &&
      progress!.stage.name != "idle" &&
      progress!.stage.name != "finished";

  double get analyzeProgress {
    if (progress == null) return 0;

    if (progress!.total == 0) return 0;

    return progress!.current / progress!.total;
  }

  String get analyzeStatus => progress?.message ?? "";

  const ApplyBar({
    super.key,
    required this.onApply,
    required this.mediaItems_length,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (progress != null)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),

                  child: Row(
                    spacing: 10,
                    children: [
                      Text(analyzeStatus),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: 250,
                        child: ProgressBar(value: analyzeProgress * 100),
                      ),

                      const SizedBox(height: 5),

                      Text('${(analyzeProgress * 100).toStringAsFixed(0)} %'),
                    ],
                  ),
                ),

                Button(
                  onPressed: onPause,
                  child: const Icon(FluentIcons.pause),
                ),
                Button(
                  onPressed: onResume,
                  child: const Icon(FluentIcons.play),
                ),
                Button(
                  onPressed: onCancel,
                  child: const Icon(FluentIcons.cancel),
                ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('تعداد فایل ها: ${mediaItems_length}'),
          ),
          const Expanded(
            child: Text("پس از بررسی دسته‌بندی‌ها، روی اعمال کلیک کنید."),
          ),

          FilledButton(onPressed: onApply, child: const Text("اعمال")),
        ],
      ),
    );
  }
}
