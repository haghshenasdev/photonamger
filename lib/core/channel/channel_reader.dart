import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

import 'channel_post.dart';

class ChannelReader {
  
  Future<List<ChannelPost>> read({
    required String channel,

    required DateTime oldestDate,

    void Function(int current, int total, String status)? onProgress,
  }) async {
    final posts = <ChannelPost>[];

    final addedIds = <int>{};

    int page = 0;

    String? before;

    while (true) {
      page++;

      onProgress?.call(page, 0, "در حال خواندن صفحه $page");

      final url = before == null
          ? "https://eitaa.com/$channel"
          : "https://eitaa.com/$channel?before=$before";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        break;
      }

      final document = parse(response.body);

      final messages = document.querySelectorAll(".etme_widget_message_wrap");

      if (messages.isEmpty) {
        break;
      }

      int? smallestId;

      bool stop = false;

      for (final msg in messages) {
        final id = int.tryParse(msg.id);

        if (id == null) {
          continue;
        }

        smallestId ??= id;

        if (id < smallestId) {
          smallestId = id;
        }

        if (addedIds.contains(id)) {
          continue;
        }

        final time = msg.querySelector("time")?.attributes["datetime"];

        if (time == null) {
          continue;
        }

        final date = DateTime.parse(time);

        if (date.isBefore(oldestDate.subtract(const Duration(days: 2)))) {
          stop = true;

          break;
        }

        final text =
            msg.querySelector(".etme_widget_message_text")?.text.trim() ?? "";

        addedIds.add(id);

        posts.add(ChannelPost(id: id, title: text, text: text, date: date));
      }

      if (stop) {
        break;
      }

      if (smallestId == null) {
        break;
      }

      before = smallestId.toString();
    }

    posts.sort((a, b) => b.id.compareTo(a.id));

    onProgress?.call(posts.length, posts.length, "پایان خواندن کانال");

    return posts;
  }

  
}
