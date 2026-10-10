import 'dart:async';
import 'dart:math' as math;

import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

class ReadChannelService {
  ReadChannelService({required this.predictor, required String channel})
    : channel = channel.replaceFirst('@', '');

  final CategoryPredictor predictor;
  final String channel;

  // دسترسی محترمانه به Eitaa: فاصله بین درخواست‌ها و cache کوتاه‌مدت
  // فشار روی سرور را کم می‌کند و از retryهای پشت‌سرهم جلوگیری می‌کند.
  static DateTime? _lastRequestAt;
  static final Map<String, _CachedResponse> _cache =
      <String, _CachedResponse>{};

  static const Duration _minRequestGap = Duration(seconds: 3);
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// از دیتابیس یا تنظیمات بخوان
  // int lastReadId = 9555;

  Future<List<ChannelPost>> read({
    required DateTime oldestDate,
    bool onlyImagePosts = true,
    void Function(double? progress, String status)? onProgress,
  }) async {
    try {
      int page = 0;

      const maxPages = 300;

      onProgress?.call(null, "در حال خواندن کانال...");

      int? currentId;

      final Map<int, List<String>> newPosts = {};

      bool reachedOldest = false;

      while (!reachedOldest && page < maxPages) {
        page++;

        onProgress?.call(null, "در حال خواندن صفحه $page");
        final url = currentId == null
            ? "https://eitaa.com/$channel"
            : "https://eitaa.com/$channel?before=$currentId";

        Map<int, List<String>> result = {};
        Object? pageError;
        // A transient request/HTML error must not be mistaken for the end
        // of the channel. Retry the same cursor a few times, then stop while
        // keeping posts already collected.
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            result = await dom(url);
            pageError = null;
            break;
          } catch (error) {
            pageError = error;
            if (attempt < 2) {
              await Future.delayed(Duration(seconds: 2 + attempt * 3));
            }
          }
        }

        if (pageError != null) {
          onProgress?.call(null, 'خواندن صفحه $page متوقف شد؛ خطا: $pageError');
          break;
        }

        if (result.isEmpty) {
          // A valid empty page means there is no more history. Keep the
          // time-window behavior below unchanged.
          onProgress?.call(null, 'صفحه $page پست قابل‌خواندن نداشت؛ پایان تاریخچه یا تغییر ساختار صفحه.');
          break;
        }

        final ids = result.keys.toList()..sort((a, b) => b.compareTo(a));

        DateTime oldestPostInPage = DateTime.now();

        for (final id in ids) {
          final post = result[id]!;

          final parsedDate = DateTime.tryParse(post[1]);
          if (parsedDate == null) continue;
          final date = parsedDate;

          // قدیمی‌ترین تاریخ این صفحه
          if (date.isBefore(oldestPostInPage)) {
            oldestPostInPage = date;
          }

          // فقط پست‌هایی که در بازه زمانی مورد نیاز هستند
          if (!date.isBefore(oldestDate) &&
              (!onlyImagePosts || (post.length > 2 && post[2] == 'true'))) {
            newPosts[id] = post;
          }
        }

        // اگر به تاریخ موردنظر رسیدیم دیگر ادامه نده
        if (!oldestPostInPage.isAfter(oldestDate)) {
          reachedOldest = true;
        }

        // صفحه بعد: use the smallest id from this page as the cursor.
        // Protect against a page repeating the same IDs indefinitely.
        final nextId = ids.last;
        if (currentId != null && nextId >= currentId) {
          onProgress?.call(null, 'صفحه‌بندی ایتا تکراری شد؛ برای جلوگیری از حلقه، خواندن متوقف شد.');
          break;
        }
        currentId = nextId;
      }

      onProgress?.call(null, "در حال حذف عناوین تکراری...");

      final filtered = removeExactDuplicateTitlesKeepHigherId(newPosts);

      final sortedIds = filtered.keys.toList()..sort();

      final posts = <ChannelPost>[];

      print("${sortedIds.length} پست خوانده شد");

      int current = 0;

      final total = sortedIds.length;

      for (final id in sortedIds) {
        current++;

        onProgress?.call(
          current / total,
          "در حال تحلیل عنوان‌ها ($current از $total)",
        );

        final post = filtered[id]!;

        final title = post[0].trim();
        final parsedDate = DateTime.tryParse(post[1]);
        if (title.isEmpty || parsedDate == null) continue;
        final date = parsedDate;

        final cats = await predictor.predictWithCity(title);

        if (cats != null && cats.categories.isNotEmpty) {
          posts.add(
            ChannelPost(title: predictor.cleanTitle(title), date: date, id: id),
          );

          // print(predictor.cleanTitle(title));
          // print(date);
        }
      }

      onProgress?.call(1, "خواندن کانال پایان یافت");
      return posts;
    } catch (e) {
      print(e);
      return [];
    }
  }

  Map<int, List<String>> removeExactDuplicateTitlesKeepHigherId(
    Map<int, List<String>> posts,
  ) {
    final seen = <String, int>{};

    for (final entry in posts.entries) {
      final id = entry.key;
      final title = entry.value[0];

      if (!seen.containsKey(title) || id > seen[title]!) {
        seen[title] = id;
      }
    }

    final result = <int, List<String>>{};

    for (final entry in seen.entries) {
      result[entry.value] = posts[entry.value]!;
    }

    final sorted = result.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Map.fromEntries(sorted);
  }

  Future<Map<int, List<String>>> dom(String url) async {
    try {
      final cached = _cache[url];
      if (cached != null &&
          DateTime.now().difference(cached.createdAt) < _cacheTtl) {
        return cached.messages;
      }

      const maxAttempts = 3;

      http.Response? response;

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        await _waitForRateLimit();

        try {
          response = await http.get(
            Uri.parse(url),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 Chrome/124 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'fa,en;q=0.8',
            },
          );

          if (response.statusCode == 200) {
            break;
          }

          // 429 یعنی سرویس صراحتاً درخواست‌های زیاد را محدود کرده است.
          // در این حالت retry تهاجمی انجام نمی‌دهیم.
          if (response.statusCode == 429) {
            final retryAfter = _retryAfter(response);
            await Future.delayed(retryAfter);
            continue;
          }

          if (response.statusCode == 403) {
            // تلاش بیشتر برای دور زدن محدودیت انجام نمی‌دهیم.
            break;
          }
        } catch (_) {
          // شبکه ممکن است موقتاً قطع باشد؛ backoff ملایم انجام می‌دهیم.
        }

        if (attempt < maxAttempts - 1) {
          final backoff = Duration(
            seconds: 2 + (attempt * 3),
          );

          await Future.delayed(backoff);
        }
      }

      if (response == null || response.statusCode != 200) {
        throw Exception(
          'دریافت اطلاعات کانال از Eitaa موفق نبود'
          '${response == null ? '' : ' (HTTP ${response.statusCode})'}',
        );
      }

      final document = parse(response.body);

      final section =
          document.querySelector("section.etme_channel_history");

      if (section == null) {
        throw FormatException('ساختار تاریخچه کانال در پاسخ ایتا پیدا نشد؛ احتمالاً HTML تغییر کرده یا دسترسی محدود شده است.');
      }

      final messages = section.querySelectorAll("div.etme_widget_message_wrap");

      final result = <int, List<String>>{};

      for (final message in messages) {
        final idText = message.id;

        if (idText.isEmpty) continue;

        final id = int.tryParse(idText);

        if (id == null) continue;

        // Eitaa has used more than one markup layout. Prefer the message text,
        // but also inspect caption/legacy selectors. Element.text keeps text
        // from later lines and image captions; normalize whitespace afterwards.
        final textElement = message.querySelector('.etme_widget_message_text') ??
            message.querySelector('.etme_widget_message_caption') ??
            message.querySelector('.etme_widget_message_content') ??
            message.querySelector('.tgme_widget_message_text');
        final rawText = textElement?.text ?? '';
        final text = rawText
            .replaceAll('\u00a0', ' ')
            .replaceAll(RegExp(r'[ \t]+\n'), '\n')
            .replaceAll(RegExp(r'\n[ \t]+'), '\n')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

        final timeElement = message.querySelector('time.time') ??
            message.querySelector('time[datetime]') ??
            message.querySelector('time');
        final time = timeElement?.attributes['datetime'] ??
            timeElement?.attributes['title'] ?? '';

        if (text.isEmpty || DateTime.tryParse(time) == null) continue;

        final hasImage = message.querySelector('img') != null ||
            message.querySelector('.etme_widget_message_photo') != null ||
            message.querySelector('.etme_widget_message_video') != null;

        result[id] = [text, time, hasImage.toString()];
      }

      _cache[url] = _CachedResponse(
        createdAt: DateTime.now(),
        messages: result,
      );

      // cache را محدود نگه می‌داریم.
      if (_cache.length > 40) {
        final oldestKey = _cache.entries
            .reduce(
              (a, b) => a.value.createdAt.isBefore(b.value.createdAt)
                  ? a
                  : b,
            )
            .key;

        _cache.remove(oldestKey);
      }

      return result;
    } catch (e) {
      // Let read() retry this page rather than silently treating the error as
      // an empty final page.
      rethrow;
    }
  }

  Future<void> _waitForRateLimit() async {
    final now = DateTime.now();
    final previous = _lastRequestAt;

    if (previous != null) {
      final elapsed = now.difference(previous);
      final jitterMs = math.Random().nextInt(1200);
      final targetGap =
          _minRequestGap + Duration(milliseconds: jitterMs);

      if (elapsed < targetGap) {
        await Future.delayed(targetGap - elapsed);
      }
    }

    _lastRequestAt = DateTime.now();
  }

  Duration _retryAfter(http.Response response) {
    final value = response.headers['retry-after'];

    final seconds = int.tryParse(value ?? '');
    if (seconds != null) {
      return Duration(
        seconds: math.min(30, math.max(3, seconds)),
      );
    }

    // اگر Eitaa Retry-After نفرستاد، retry کوتاه و محدود.
    return const Duration(seconds: 8);
  }
}

class _CachedResponse {
  final DateTime createdAt;
  final Map<int, List<String>> messages;

  const _CachedResponse({
    required this.createdAt,
    required this.messages,
  });
}
