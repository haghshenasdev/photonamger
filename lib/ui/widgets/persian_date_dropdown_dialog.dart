import 'package:fluent_ui/fluent_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// انتخاب تاریخ شمسی بدون باز کردن تقویم میلادی.
/// سال، ماه و روز هرکدام از یک DropDown انتخاب می‌شوند.
class PersianDateDropdownDialog extends StatefulWidget {
  final DateTime initialDate;
  final int firstYear;
  final int lastYear;

  const PersianDateDropdownDialog({
    super.key,
    required this.initialDate,
    this.firstYear = 1300,
    this.lastYear = 1500,
  });

  @override
  State<PersianDateDropdownDialog> createState() =>
      _PersianDateDropdownDialogState();
}

class _PersianDateDropdownDialogState
    extends State<PersianDateDropdownDialog> {
  late int _year;
  late int _month;
  late int _day;
  late final TextEditingController _yearController;

  static const _monthNames = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  @override
  void initState() {
    super.initState();
    final j = Jalali.fromDateTime(widget.initialDate);
    _year = j.year.clamp(widget.firstYear, widget.lastYear).toInt();
    _month = j.month.clamp(1, 12).toInt();
    _day = j.day.clamp(1, _daysInMonth(_year, _month)).toInt();
    _yearController = TextEditingController(text: _year.toString());
  }

  int _daysInMonth(int year, int month) {
    return Jalali(year, month, 1).monthLength;
  }

  void _normalizeDay() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) _day = maxDay;
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(_year, _month);

    return ContentDialog(
      title: const Text('انتخاب تاریخ شمسی'),
      content: SizedBox(
        width: 520,
        child: Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _yearController,
                placeholder: 'سال',
                keyboardType: TextInputType.number,
                onChanged: (text) {
                  final year = int.tryParse(text.trim());
                  if (year == null || year < 1 || year > 9999) return;
                  setState(() {
                    _year = year;
                    _normalizeDay();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ComboBox<int>(
                isExpanded: true,
                value: _month,
                items: [
                  for (int m = 1; m <= 12; m++)
                    ComboBoxItem(
                      value: m,
                      child: Text('${m.toString().padLeft(2, '0')} - ${_monthNames[m - 1]}'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _month = value;
                    _normalizeDay();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ComboBox<int>(
                isExpanded: true,
                value: _day,
                items: [
                  for (int d = 1; d <= days; d++)
                    ComboBoxItem(
                      value: d,
                      child: Text(d.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _day = value);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final result = Jalali(_year, _month, _day).toDateTime();
            Navigator.of(context).pop(result);
          },
          child: const Text('تأیید'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}
