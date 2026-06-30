import 'analysis_stage.dart';

class AnalysisStatus {
  static String title(AnalysisStage stage) {
    switch (stage) {
      case AnalysisStage.idle:
        return 'آماده';

      case AnalysisStage.scanning:
        return 'در حال اسکن فایل‌ها';

      case AnalysisStage.timeline:
        return 'در حال دسته‌بندی زمانی';

      case AnalysisStage.duplicate:
        return 'در حال یافتن تصاویر تکراری';

      case AnalysisStage.blur:
        return 'در حال بررسی تاری تصاویر';

      case AnalysisStage.faces:
        return 'در حال تشخیص چهره';

      case AnalysisStage.quality:
        return 'در حال محاسبه کیفیت تصاویر';

      case AnalysisStage.selecting:
        return 'در حال انتخاب بهترین تصاویر';

      case AnalysisStage.finished:
        return 'تحلیل پایان یافت';

      case AnalysisStage.cancelled:
        return 'تحلیل لغو شد';

      case AnalysisStage.error:
        return 'خطا در تحلیل';
      case AnalysisStage.bestPhoto:
        return "در حال انتخاب بهترین تصویر...";
    }
  }
}
