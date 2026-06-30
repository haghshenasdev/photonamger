import 'package:fluent_ui/fluent_ui.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

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

    final jalali =
        Jalali.fromDateTime(value);

    return Button(
      child: Text(
        '${jalali.year}/'
        '${jalali.month.toString().padLeft(2, '0')}/'
        '${jalali.day.toString().padLeft(2, '0')}',
      ),
      onPressed: () async {

        final result =
            await showPersianDatePicker(
          context: context,
          initialDate: jalali,
          firstDate: Jalali(1380),
          lastDate: Jalali(1450),
        );

        if (result == null) return;

        onChanged(
          result.toDateTime(),
        );
      },
    );
  }
}