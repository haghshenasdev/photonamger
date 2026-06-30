import 'channel_post.dart';
import 'channel_reader.dart';

class ChannelReadEngine {
  final ChannelReader reader = ChannelReader();

  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  void reset() {
    _cancelled = false;
  }

  Future<List<ChannelPost>> read({
    required String channel,
    required DateTime oldestDate,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    reset();

    final posts = await reader.read(
      channel: channel,
      oldestDate: oldestDate,
      onProgress: (c, t, s) {
        if (_cancelled) return;

        onProgress?.call(c, t, s);
      },
    );

    if (_cancelled) {
      return [];
    }

    return posts;
  }
}
