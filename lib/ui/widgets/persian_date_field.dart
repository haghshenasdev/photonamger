import 'package:fluent_ui/fluent_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'persian_date_dropdown_dialog.dart';

class PersianDateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const PersianDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final jalali = Jalali.fromDateTime(value);

    return Button(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.calendar, size: 14),
          const SizedBox(width: 7),
          Text(
            '${jalali.year}/'
            '${jalali.month.toString().padLeft(2, '0')}/'
            '${jalali.day.toString().padLeft(2, '0')}',
          ),
        ],
      ),
      onPressed: () async {
        final result = await showDialog<DateTime>(
          context: context,
          builder: (_) => PersianDateDropdownDialog(initialDate: value),
        );

        if (result != null) onChanged(result);
      },
    );
  }
}
