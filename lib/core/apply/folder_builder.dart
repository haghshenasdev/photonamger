import 'dart:io';

import 'package:fgphoto/core/utils/persian_date.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:shamsi_date/shamsi_date.dart';

class FolderBuilder {
  static const _months = [
    "",
    "1-فروردین",
    "2-اردیبهشت",
    "3-خرداد",
    "4-تیر",
    "5-مرداد",
    "6-شهریور",
    "7-مهر",
    "8-آبان",
    "9-آذر",
    "10-دی",
    "11-بهمن",
    "12-اسفند",
  ];

  static Future<Directory> build({
    required ApplySettings settings,
    required TimelineGroup group,
  }) async {
    final j = Jalali.fromDateTime(group.start);

    String path = settings.outputFolder;

    // پوشه سال
    if (settings.createYearFolder) {
      path = "$path/${j.year}";
    }

    // پوشه ماه
    if (settings.createMonthFolder) {
      path = "$path/${_months[j.month]}";
    }

    // پوشه گروه
    if (settings.createGroupFolder) {
      String folderName = clean(group.title);

      if (settings.appendDateToGroupName) {
        folderName += " - ${PersianDate.formatDate(group.start)}";
      }

      path = "$path/$folderName";
    }

    final dir = Directory(path);

    await dir.create(recursive: true);

    return dir;
  }

  static String clean(String text) {
    // حذف کاراکترهای غیرمجاز ویندوز
    text = text.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    // حذف فاصله‌های اضافی
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // حذف نقطه و فاصله انتهایی
    text = text.replaceAll(RegExp(r'[. ]+$'), '');

    // محدود کردن طول نام پوشه
    const maxLength = 240;

    if (text.length > maxLength) {
      text = text.substring(0, maxLength).trim();
    }

    return text;
  }
}
