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

  /// Extracts a concise, news-like headline from the full post text.
  /// Channel posts often start with a boilerplate line and put the actual
  /// event in a later sentence, so score all lines and sentences.
  String extractHeadline(String rawText) {
    final normalized = _normalizePersian(rawText);
    final cleaned = normalized
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'www\.\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'@[\w\u200c]+'), ' ')
        .replaceAll(RegExp(r'#[\p{L}\p{N}_]+', unicode: true), ' ')
        .replaceAll(RegExp(r'[📸📹🎥🔻🔺🔹🔸▪️▫️✅❇️🌐📲🆔]+'), ' ');

    final candidates = <String>[];
    for (final line in cleaned.split(RegExp(r'[\r\n]+'))) {
      final parts = line.split(RegExp(r'(?<=[.!؟!?])\s+'));
      for (final part in parts) {
        final value = _tidyHeadline(part);
        if (value.isNotEmpty) candidates.add(value);
      }
    }
    if (candidates.isEmpty) return '';
    candidates.sort((a, b) => _headlineScore(b).compareTo(_headlineScore(a)));
    final best = candidates.first;
    if (_headlineScore(best) < 2 || best.contains('\uFFFD')) return '';
    return _shortenHeadline(best, 300);
  }

  String _normalizePersian(String value) => value
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u0640', '')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('\u00a0', ' ');

  String _tidyHeadline(String value) {
    var text = _normalizePersian(value)
        .replaceAll(RegExp(r'^[\s\-–—|:،؛ـ]+|[\s\-–—|:،؛ـ]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    const boilerplate = [
      'هم اکنون در حال برگزاری است',
      'در حال برگزاری است',
      'با ما همراه باشید',
      'برای مشاهده',
      'ادامه خبر',
      'گزارش تصویری',
      'روابط عمومی',
    ];
    for (final phrase in boilerplate) {
      text = text.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        ' ',
      );
    }
    return _cleanTitleCharacters(text);
  }

  /// Keeps Persian/Arabic-script letters and Persian/English digits only.
  /// Replacing other characters with spaces avoids joining neighboring words.
  String _cleanTitleCharacters(String value) => value
      .replaceAll(RegExp(r'[^ءاآأإؤئابتثجچحخدذرزژسشصضطظعغفقکگلمنوهیۀةي۰-۹0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  int _headlineScore(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    // Full event sentences can make useful titles when they identify people,
    // action, and location.
    if (words < 4 || words > 55) return -10;
    if (RegExp(r'^(https?://|www\.|@|#)').hasMatch(text)) return -10;
    var score = 1;
    if (words >= 6 && words <= 20) score += 2;
    if (RegExp(r'[\p{L}]', unicode: true).hasMatch(text)) score++;
    if (RegExp(
      r'(گفت|اعلام|برگزار|دیدار|بازدید|تصویب|افتتاح|ملاقات|جلسه|نشست|تاکید|تأکید|خبر|استان|شهرستان)',
      unicode: true,
    ).hasMatch(text))
      score += 3;
    if (RegExp(
      r'(هم اکنون|لحظاتی پیش|دقایقی پیش|امروز|فردا|کانال|عضویت|لینک)',
      unicode: true,
    ).hasMatch(text))
      score--;
    if (RegExp(
      r'(بازدید کردند|بازدید کرد|دیدار کردند|دیدار کرد|افتتاح کردند|افتتاح کرد|بررسی کردند|بررسی کرد|به دعوت|از پروژه|از طرح|از بیمارستان)',
      unicode: true,
    ).hasMatch(text)) {
      score += 5;
    }
    if (text.length > 260) score--;
    return score;
  }

  String _shortenHeadline(String text, int maxLength) {
    final codePoints = text.runes.toList();
    if (codePoints.length <= maxLength) return text;
    final cut = String.fromCharCodes(codePoints.take(maxLength));
    final boundary = cut.lastIndexOf(' ');
    return (boundary > maxLength * .65 ? cut.substring(0, boundary) : cut)
        .trim();
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
    final extracted = extractHeadline(rawTitle);
    if (extracted.isNotEmpty) return _cleanTitleCharacters(extracted);
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

    // حذف ادامه جمله از روی کلمات کلیدی
    const cutWords = [
      'جهت',
      'به منظور',
      'بمنظور',
      'بهمنظور',
      'به منظور',
      'با هدف',
      'در راستای',
      'در خصوص',
      'به مناسبت',
      'با حضور',
      'با همراهی',
      'با مشارکت',
      'با همکاری',
      'به ریاست',
      'در دیدار',
      'در بازدید',
    ];

    int? cutIndex;

    for (final word in cutWords) {
      final index = text.indexOf(word);

      if (index != -1) {
        if (cutIndex == null || index < cutIndex) {
          cutIndex = index;
        }
      }
    }

    if (cutIndex != null) {
      text = text.substring(0, cutIndex);
    }

    // حذف فاصله‌های اضافی
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return _cleanTitleCharacters(text);
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
