import 'dart:async';

import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

class ReadChannelService {
  ReadChannelService({required this.predictor});

  final CategoryPredictor predictor;

  /// از دیتابیس یا تنظیمات بخوان
  // int lastReadId = 9555;

  Future<List<ChannelPost>> read({required DateTime oldestDate}) async {
    try {
      int? currentId;

      final Map<int, List<String>> newPosts = {};

      bool reachedOldest = false;

      while (!reachedOldest) {
        final url = currentId == null
            ? "https://eitaa.com/Hamase4"
            : "https://eitaa.com/Hamase4?before=$currentId";

        final result = await dom(url);

        if (result.isEmpty) {
          break;
        }

        final ids = result.keys.toList()..sort((a, b) => b.compareTo(a));

        DateTime oldestPostInPage = DateTime.now();

        for (final id in ids) {
          final post = result[id]!;

          final date = DateTime.parse(post[1]);

          // قدیمی‌ترین تاریخ این صفحه
          if (date.isBefore(oldestPostInPage)) {
            oldestPostInPage = date;
          }

          // فقط پست‌هایی که در بازه زمانی مورد نیاز هستند
          if (!date.isBefore(oldestDate)) {
            newPosts[id] = post;
          }
        }

        // اگر به تاریخ موردنظر رسیدیم دیگر ادامه نده
        if (!oldestPostInPage.isAfter(oldestDate)) {
          reachedOldest = true;
        }

        // صفحه بعد
        currentId = ids.last;
      }

      final filtered = removeExactDuplicateTitlesKeepHigherId(newPosts);

      final sortedIds = filtered.keys.toList()..sort();

      final posts = <ChannelPost>[];

      print("${sortedIds.length} پست خوانده شد");

      for (final id in sortedIds) {
        final post = filtered[id]!;

        final title = post[0];
        final date = DateTime.parse(post[1]);

        final cats = await predictor.predictWithCity(title);

        if (cats != null && cats.categories.isNotEmpty) {
          posts.add(
            ChannelPost(title: predictor.cleanTitle(title), date: date, id: id),
          );

          print(predictor.cleanTitle(title));
          print(date);
        }
      }

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
      const maxAttempts = 5;

      const wait = Duration(seconds: 3);

      http.Response? response;

      for (int i = 0; i < maxAttempts; i++) {
        try {
          response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            break;
          }
        } catch (_) {}

        await Future.delayed(wait);
      }

      if (response == null || response.statusCode != 200) {
        throw Exception("Cannot download $url");
      }

      final document = parse(response.body);

      final section = document.querySelector("section.etme_channel_history");

      if (section == null) {
        return {};
      }

      final messages = section.querySelectorAll("div.etme_widget_message_wrap");

      final result = <int, List<String>>{};

      for (final message in messages) {
        final idText = message.id;

        if (idText.isEmpty) continue;

        final id = int.tryParse(idText);

        if (id == null) continue;

        final text =
            message.querySelector(".etme_widget_message_text")?.text.trim() ??
            "";

        final time =
            message.querySelector("time.time")?.attributes["datetime"] ?? "";

        result[id] = [text, time];
      }

      return result;
    } catch (e) {
      print(e);
      return {};
    }
  }
}
