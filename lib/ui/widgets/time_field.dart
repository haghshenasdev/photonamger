import 'package:fluent_ui/fluent_ui.dart';

class TimeField extends StatefulWidget {
  final DateTime value;

  final ValueChanged<DateTime> onChanged;

  const TimeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(
      text:
          '${widget.value.hour.toString().padLeft(2, '0')}:'
          '${widget.value.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  void didUpdateWidget(TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    controller.text =
        '${widget.value.hour.toString().padLeft(2, '0')}:'
        '${widget.value.minute.toString().padLeft(2, '0')}';
  }

  void _updateTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return;

    if (hour < 0 || hour > 23) return;

    if (minute < 0 || minute > 59) return;

    widget.onChanged(
      DateTime(
        widget.value.year,
        widget.value.month,
        widget.value.day,
        hour,
        minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextBox(
      controller: controller,
      placeholder: '08:30',

      onSubmitted: _updateTime,

      onEditingComplete: () {
        _updateTime(controller.text);
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}