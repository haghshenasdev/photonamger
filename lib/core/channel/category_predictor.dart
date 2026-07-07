import 'package:shamsi_date/shamsi_date.dart';

class PredictionResult {
  final List<int> categories;
  final int? city;
  final int? organ;

  const PredictionResult({required this.categories, this.city, this.organ});
}

class CityRecord {
  final int id;
  final String name;

  const CityRecord({required this.id, required this.name});
}

class OrganRecord {
  final int id;
  final String name;

  const OrganRecord({required this.id, required this.name});
}

class CategoryPredictor {
  final List<String> blacklist = [
    'تبریک',
    'مبارک',
    'گرامی باد',
    'تسلیت',
    'صحن',
    'ویدیو',
    'فیلم',
    '#فیلم',
    '#ویدیو',
    'ببینید',
    '#ببینید',
    'بازتاب',
    '#پیشنهاد_تماشا',
    'خبرگزاری',
    'تصویر -',
    '#پوشش_زنده',
    'تسنیم',
    'فارس',
    'نامه',
    'جلسه علنی',
    'بازتاب',
    'صدا و سیما',
    'مشروح',
    'خانه ملت',
    'ایرنا',
    'ایسنا',
    'میزان',
    'نسیم',
    'دیده بان',
    'دیده‌بان',
    '@YjcNewsChannel',
    'تذکرات کتبی',
    'تذکر کتبی',
    'تماس',
    'تماسی',
    '#حاجی_دلیگانی',
  ];

  final List<String> phrasesToRemove = [
    'نماینده مردم شریف شهرستانهای شاهین شهر و میمه و برخوار',
    'نماینده مردم شریف شهرستان های شاهین شهر و میمه و برخوار',
    'شاهین شهر و میمه و برخوار',
    'در مجلس شورای اسلامی',
    'کمیسیون اصل ۹۰',
    'کمیسیون اصل نود',
    'عصر امروز',
    'گزارش تصویری از',
    'گزارش تصویری',
    'بعد از ظهر امروز',
    'بعد از ظهر',
    'ظهر امروز',
    'صبح امروز',
    'هم اکنون',
    'انجام شد',
    'دقایقی قبل',
    'ساعاتی قبل',
    'ساعتی قبل',
    'ساعتی پیش',
    'ساعاتی پیش',
    'لحظاتی پیش',
    'در حال برگزاری است',
    'در حال برگزاری',
    'برگزار شد',
    '@Hamase4',
    'جناب آقای حاجی',
    'حسینعلی حاجی دليگانی',
    'حاجی',
    'جناب آقای حسینعلی',
    'حسینعلی',
    'دلیگانی',
    'کانال ایتا',
    'eitaa.com/hamase4',
    'کانال سروش',
    'splus.ir/hamase4',
    'کانال بله',
    'ble.ir/hamase4',
    'وب سایت رسمی',
    'www.hamasesazan.ir',
    'آپارات',
    'aparat.com/hamasesazan.ir',
    'aparatcomhamasesazanir',
    'wwwhamasesazanir',
    'bleirhamase4',
    'هماکنون',
    'هم اکنون',
    'درحال برگزاری است',
  ];

  final List<String> stopWords = [
    'از',
    'به',
    'در',
    'با',
    'برای',
    'که',
    'و',
    'یا',
    'تا',
    'اما',
    'اگر',
    'این',
    'آن',
    'می',
    'را',
    'است',
    'بود',
    'شود',
    'کرد',
    'کردن',
    'نیز',
    'هم',
    'چون',
    'بر',
    'بین',
    'یک',
    'هیچ',
    'همه',
    'هر',
    'چیزی',
    'چند',
    'چرا',
    'چه',
    'کجا',
    'کی',
    'ما',
    'شما',
    'او',
    'آنها',
    'من',
    'تو',
    'ایشان',
    'خود',
    'همین',
    'اکنون',
    'امروز',
    'فردا',
    'دیروز',
  ];

  final Map<int, List<String>> categoryKeywords = {
    2222: ['سفر', 'معاون', 'وزیر', 'وزارت', 'کشور', 'مشاور', 'دعوت'],
    2229: [
      'حضور',
      'جلسه',
      'نشست',
      'سخنرانی',
      'استان',
      'برنامه',
      'مراسم',
      'کلنگ',
      'آئین',
    ],
    2227: ['بازدید', 'احداث', 'پروژه'],
    2223: ['مراسم', 'سخنرانی', 'حضور', 'نماز', 'مسجد'],
    2225: ['دیدار', 'شهید', 'خانواده', 'امام'],
    2221: ['استان', 'اصفهان', 'مدیر', 'مدیرکل', 'مدیران', 'کل', 'جلسه', 'نشست'],
    2224: ['مسائل', 'جمعی', 'جلسه', 'نشست', 'اقشار', 'قشر', 'اصناف', 'صنف'],
    2228: ['جلسه', 'نشست', 'دیدار', 'گفتگو'],
    2220: ['خانه', 'ملت'],
    2236: ['اعضای', 'یاران', 'معتمدان', 'نخبه', 'مشورت', 'مشورتی'],
    2226: ['مردمی', 'ملاقات'],
    2230: ['پیگیری', 'ملت', 'مصوبه', 'مصوبات'],
    2232: ['پیشرفت', 'معاونین', 'معاون', 'معاونان', 'جلسه'],
    2237: ['شخصی', 'موردی', 'متفرقه', 'جلسه', 'دیدار', 'نشست'],
  };

  Map<int, int>? predict(String title, {int top = 2}) {
    if (containsBlacklistedWord(title)) {
      return null;
    }

    final keywords = extractKeywords(title);

    return predictCore(keywords, top: top);
  }

  PredictionResult? predictWithCity(String title, {int top = 2}) {
    if (containsBlacklistedWord(title)) {
      return null;
    }

    final keywords = extractKeywords(title);

    final categories = predictCore(keywords, top: top).keys.toList();

    return PredictionResult(categories: categories);
  }

  Map<int, int> predictCore(List<String> keywords, {int top = 2}) {
    final scores = <int, int>{};

    for (final entry in categoryKeywords.entries) {
      int score = 0;

      for (final keyword in keywords) {
        if (entry.value.contains(keyword)) {
          score++;
        }
      }

      if (score > 0) {
        scores[entry.key] = score;
      }
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted.take(top));
  }

  List<String> extractKeywords(String text) {
    for (final phrase in phrasesToRemove) {
      text = text.replaceAll(phrase, '');
    }

    text = text.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '');

    text = text.replaceAll(RegExp(r'\d+'), '');

    final words = text.split(RegExp(r'\s+'));

    return words.where((w) => w.length > 2 && !stopWords.contains(w)).toList();
  }

  bool containsBlacklistedWord(String title) {
    for (final blocked in blacklist) {
      if (title.contains(blocked)) {
        return true;
      }
    }

    return false;
  }

  String cleanTitle(String rawTitle) {
    var text = rawTitle;

    // حذف آیدی‌ها
    text = text.replaceAll(RegExp(r'@\w+'), '');

    // حذف علائم نگارشی
    text = text.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');

    // حذف عبارات اضافی
    for (final phrase in phrasesToRemove) {
      text = text.replaceAll(phrase, '');
    }

    // فقط خط اول
    text = text
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');

    // حذف فاصله‌های اضافی
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  DateTime? extractDateFromTitle(String line) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var converted = line;

    for (int i = 0; i < 10; i++) {
      converted = converted.replaceAll(persianDigits[i], englishDigits[i]);
    }

    final match = RegExp(
      r'(\d{4})\/(\d{1,2})\/(\d{1,2})',
    ).firstMatch(converted);

    if (match == null) {
      return null;
    }

    try {
      final jy = int.parse(match.group(1)!);
      final jm = int.parse(match.group(2)!);
      final jd = int.parse(match.group(3)!);

      final g = Jalali(jy, jm, jd).toGregorian();

      final now = DateTime.now();

      return DateTime(g.year, g.month, g.day, now.hour, now.minute, now.second);
    } catch (_) {
      return null;
    }
  }
}
