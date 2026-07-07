import 'package:shamsi_date/shamsi_date.dart';

class PersianDate {
  static String format(DateTime dateTime) {
    final j = Gregorian.fromDateTime(dateTime).toJalali();

    return '${j.year}/'
        '${j.month.toString().padLeft(2, '0')}/'
        '${j.day.toString().padLeft(2, '0')}';
  }

  static String formatDateTime(DateTime dateTime) {
    final j = Gregorian.fromDateTime(dateTime).toJalali();

    return '${j.year}/'
        '${j.month.toString().padLeft(2, '0')}/'
        '${j.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime date) {
    final j = Jalali.fromDateTime(date);

    return "${j.day}-${j.month}-${j.year}";
  }
}
