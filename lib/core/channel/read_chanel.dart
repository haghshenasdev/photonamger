import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  static Future<void>? _diskCacheLoad;
  static File? _diskCacheFile;

  static const Duration _maxRequestGap = Duration(seconds: 2);
  static const Duration _latestPageTtl = Duration(minutes: 2);
  static const Duration _historyPageTtl = Duration(days: 30);

  /// از دیتابیس یا تنظیمات بخوان
  // int lastReadId = 9555;

  Future<List<ChannelPost>> read({
    required DateTime oldestDate,
    bool onlyImagePosts = true,
    void Function(double? progress, String status)? onProgress,
    void Function(ChannelPost post)? onPostRead,
    Future<void> Function()? onPauseCheck,
    bool Function()? shouldStopReading,
  }) async {
    try {
      int page = 0;

      const maxPages = 300;

      onProgress?.call(null, "در حال خواندن کانال...");

      int? currentId;

      final Map<int, List<String>> newPosts = {};

      bool reachedOldest = false;

      while (!reachedOldest &&
          page < maxPages &&
          !(shouldStopReading?.call() ?? false)) {
        await onPauseCheck?.call();
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
          await onPauseCheck?.call();
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
          // No dated message wrappers were parsed, so there is no safe cursor
          // to request the next page with.
          onProgress?.call(
            null,
            'صفحه $page هیچ پست قابل‌صفحه‌بندی نداشت؛ احتمالاً به انتهای تاریخچه یا پاسخ نامعتبر رسیده‌ایم.',
          );
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
            final rawText = post[0].trim();
            if (rawText.isNotEmpty) {
              onPostRead?.call(
                ChannelPost(
                  // Headline extraction happens once in the processing pass.
                  title: '',
                  date: date,
                  id: id,
                  preview: rawText.replaceAll(RegExp(r'\s+'), ' ').trim(),
                ),
              );
            }
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
          onProgress?.call(
            null,
            'صفحه‌بندی ایتا تکراری شد؛ برای جلوگیری از حلقه، خواندن متوقف شد.',
          );
          break;
        }
        currentId = nextId;
      }

      onProgress?.call(null, "در حال حذف عناوین تکراری...");

      if (page >= maxPages &&
          !reachedOldest &&
          !(shouldStopReading?.call() ?? false)) {
        onProgress?.call(
          null,
          'به سقف ایمنی $maxPages صفحه رسیدیم؛ تاریخ درخواستی ممکن است هنوز پوشش داده نشده باشد.',
        );
      }

      final filtered = removeExactDuplicateTitlesKeepHigherId(newPosts);

      final sortedIds = filtered.keys.toList()..sort();

      final posts = <ChannelPost>[];

      print("${sortedIds.length} پست خوانده شد");

      int current = 0;

      final total = sortedIds.length;

      for (final id in sortedIds) {
        await onPauseCheck?.call();
        current++;

        onProgress?.call(
          current / total,
          "در حال تحلیل عنوان‌ها ($current از $total)",
        );

        final rawPost = filtered[id]!;

        final title = rawPost[0].trim();
        final parsedDate = DateTime.tryParse(rawPost[1]);
        if (title.isEmpty || parsedDate == null) continue;
        final date = parsedDate;

        final headline = predictor.extractHeadline(title);
        final channelPost = ChannelPost(
          title: headline,
          date: date,
          id: id,
          preview: title.replaceAll(RegExp(r'\s+'), ' ').trim(),
        );
        if (headline.isNotEmpty) {
          posts.add(channelPost);

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
      await _ensureDiskCacheLoaded();
      final cached = _cache[url];
      final ttl = url.contains('?before=') ? _historyPageTtl : _latestPageTtl;
      if (cached != null && DateTime.now().difference(cached.createdAt) < ttl) {
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
          final backoff = Duration(seconds: 2 + (attempt * 3));

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

      final section = document.querySelector("section.etme_channel_history");

      if (section == null) {
        throw FormatException(
          'ساختار تاریخچه کانال در پاسخ ایتا پیدا نشد؛ احتمالاً HTML تغییر کرده یا دسترسی محدود شده است.',
        );
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
        final textElement =
            message.querySelector('.etme_widget_message_text') ??
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

        final timeElement =
            message.querySelector('time.time') ??
            message.querySelector('time[datetime]') ??
            message.querySelector('time');
        final time =
            timeElement?.attributes['datetime'] ??
            timeElement?.attributes['title'] ??
            '';

        // Keep IDs for posts with an empty caption or unparseable time so
        // media-only pages cannot truncate pagination.

        final hasImage =
            message.querySelector('.etme_widget_message_photo_wrap') != null ||
            message.querySelector('.etme_widget_message_grouped_wrap') !=
                null ||
            message.querySelector('.etme_widget_message_photo') != null ||
            message.querySelector('.etme_widget_message_video') != null;

        result[id] = [text, time, hasImage.toString()];
      }

      _cache[url] = _CachedResponse(
        createdAt: DateTime.now(),
        messages: result,
      );
      await _persistDiskCache();

      // cache را محدود نگه می‌داریم.
      if (_cache.length > 40) {
        final oldestKey = _cache.entries
            .reduce(
              (a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b,
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

  Future<void> _ensureDiskCacheLoaded() async {
    _diskCacheLoad ??= _loadDiskCache();
    await _diskCacheLoad;
  }

  Future<void> _loadDiskCache() async {
    try {
      final directory = await getApplicationSupportDirectory();
      // v2 stores media-only posts so old v1 pages cannot truncate paging.
      _diskCacheFile = File(
        '${directory.path}${Platform.pathSeparator}eitaa_channel_pages_v2.json',
      );
      if (!await _diskCacheFile!.exists()) return;
      final decoded = jsonDecode(await _diskCacheFile!.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final now = DateTime.now();
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final createdAt = DateTime.tryParse(
          value['createdAt']?.toString() ?? '',
        );
        final rawMessages = value['messages'];
        if (createdAt == null || rawMessages is! Map) continue;
        final ttl = entry.key.contains('?before=')
            ? _historyPageTtl
            : _latestPageTtl;
        if (now.difference(createdAt) > ttl) continue;
        final messages = <int, List<String>>{};
        for (final item in rawMessages.entries) {
          final id = int.tryParse(item.key.toString());
          if (id == null || item.value is! List) continue;
          messages[id] = (item.value as List)
              .map((part) => part.toString())
              .toList();
        }
        _cache[entry.key] = _CachedResponse(
          createdAt: createdAt,
          messages: messages,
        );
      }
    } catch (_) {
      // A damaged or unavailable cache must not prevent fetching the channel.
    }
  }

  Future<void> _persistDiskCache() async {
    try {
      final file = _diskCacheFile;
      if (file == null) return;
      final entries = _cache.entries.toList()
        ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));
      final bounded = entries.take(120);
      final payload = <String, Object?>{
        for (final entry in bounded)
          entry.key: <String, Object?>{
            'createdAt': entry.value.createdAt.toIso8601String(),
            'messages': <String, List<String>>{
              for (final post in entry.value.messages.entries)
                post.key.toString(): post.value,
            },
          },
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Cache persistence is best-effort; channel reading remains available.
    }
  }

  Future<void> _waitForRateLimit() async {
    final now = DateTime.now();
    final previous = _lastRequestAt;

    if (previous != null) {
      final elapsed = now.difference(previous);
      final randomDelay = Duration(
        milliseconds: math.Random().nextInt(_maxRequestGap.inMilliseconds + 1),
      );
      final targetGap = randomDelay;

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
      return Duration(seconds: math.min(30, math.max(3, seconds)));
    }

    // اگر Eitaa Retry-After نفرستاد، retry کوتاه و محدود.
    return const Duration(seconds: 8);
  }
}

class _CachedResponse {
  final DateTime createdAt;
  final Map<int, List<String>> messages;

  const _CachedResponse({required this.createdAt, required this.messages});
}
