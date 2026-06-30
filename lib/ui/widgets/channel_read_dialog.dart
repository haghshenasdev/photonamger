import 'package:fluent_ui/fluent_ui.dart';

class ChannelReadDialog extends StatelessWidget {
  final double progress;

  final String status;

  final int current;

  final int total;

  final VoidCallback onCancel;

  const ChannelReadDialog({
    super.key,
    required this.progress,
    required this.status,
    required this.current,
    required this.total,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text("دریافت پست‌های کانال"),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(status),

          const SizedBox(height: 15),

          ProgressBar(
            value: progress * 100,
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "$current / $total",
            ),
          ),
        ],
      ),

      actions: [

        FilledButton(

          onPressed: onCancel,

          child: const Text("لغو"),

        ),

      ],
    );
  }
}