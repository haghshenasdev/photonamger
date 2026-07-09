import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:fgphoto/core/channel/read_chanel.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fluent_ui/fluent_ui.dart';

class TitleSuggestionDialog extends StatefulWidget {
  final List<TimelineGroup> groups;

  final List<String> suggestedTitles;

  final VoidCallback? onFinished;

  const TitleSuggestionDialog({
    super.key,
    required this.groups,
    required this.suggestedTitles,
    this.onFinished,
  });

  @override
  State<TitleSuggestionDialog> createState() => _TitleSuggestionDialogState();
}

class _TitleSuggestionDialogState extends State<TitleSuggestionDialog> {
  //------------------------------------------------------------
  // تنظیمات
  //------------------------------------------------------------

  final channelController = TextEditingController(text: "Hamase4");

  bool onlyImagePosts = true;

  bool replaceTitles = true;

  int maxDistanceMinutes = 60;
  String channel = 'Hamase4';

  //------------------------------------------------------------
  // Progress
  //------------------------------------------------------------

  bool running = false;

  double? progress;

  String status = "";

  //------------------------------------------------------------

  @override
  void dispose() {
    channelController.dispose();

    super.dispose();
  }

  //------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 520),

      title: const Text("پیشنهاد عنوان از کانال"),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //----------------------------------------------------
          // کانال
          //----------------------------------------------------
          const Text("نام کانال"),

          const SizedBox(height: 6),

          TextBox(
            controller: channelController,
            placeholder: "@channel",
            enabled: !running,
          ),

          const SizedBox(height: 18),

          //----------------------------------------------------
          // فاصله زمانی
          //----------------------------------------------------
          const Text("حداکثر فاصله زمانی (دقیقه) برای تطبیق"),

          const SizedBox(height: 6),

          NumberBox(
            value: maxDistanceMinutes,
            min: 1,
            max: 720,
            mode: SpinButtonPlacementMode.inline,

            onChanged: running
                ? null
                : (v) {
                    if (v == null) return;

                    setState(() {
                      maxDistanceMinutes = v.hashCode;
                    });
                  },
          ),

          const SizedBox(height: 18),

          //----------------------------------------------------
          // گزینه ها
          //----------------------------------------------------
          Checkbox(
            checked: onlyImagePosts,

            onChanged: running
                ? null
                : (v) {
                    setState(() {
                      onlyImagePosts = v ?? true;
                    });
                  },

            content: const Text("فقط پست های دارای تصویر"),
          ),

          const SizedBox(height: 8),

          Checkbox(
            checked: replaceTitles,

            onChanged: running
                ? null
                : (v) {
                    setState(() {
                      replaceTitles = v ?? true;
                    });
                  },

            content: const Text("جایگزینی عنوان های فعلی"),
          ),

          const SizedBox(height: 24),

          //----------------------------------------------------
          // Progress
          //----------------------------------------------------
          if (status.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ProgressBar(value: progress),
            ),

          const SizedBox(height: 10),

          Text(status, style: const TextStyle(fontSize: 12)),
        ],
      ),

      actions: [
        Button(
          child: const Text("انصراف"),

          onPressed: running
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),

        FilledButton(
          child: Text(running ? "در حال اجرا..." : "شروع"),

          onPressed: running ? null : _start,
        ),
      ],
    );
  }

  Future<void> _start() async {
    setState(() {
      running = true;

      progress = null;

      status = "در حال خواندن کانال...";
    });

    try {
      final rc = ReadChannelService(
        predictor: CategoryPredictor(),
        channel: channel,
      );

      final oldestDate = widget.groups
          .map((e) => e.start)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final posts = await rc.read(
        oldestDate: oldestDate,

        onProgress: (p, s) {
          setState(() {
            progress = p;

            status = s;
          });
        },
      );

      final remainingPosts = List<ChannelPost>.from(posts);

      remainingPosts.sort((a, b) => a.date.compareTo(b.date));

      widget.suggestedTitles.clear();

      //--------------------------------------------------------
      // تطبیق عنوان‌ها
      //--------------------------------------------------------

      for (int i = 0; i < widget.groups.length; i++) {
        final group = widget.groups[i];

        setState(() {
          progress = (i + 1) / widget.groups.length;

          status = "در حال بررسی گروه ${i + 1} از ${widget.groups.length}";
        });

        ChannelPost? bestPost;

        Duration? bestDistance;

        for (final post in remainingPosts) {
          if (post.date.isBefore(group.start)) {
            continue;
          }

          final distance = post.date.difference(group.end).abs();

          if (bestDistance == null || distance < bestDistance) {
            bestDistance = distance;

            bestPost = post;
          }
        }

        if (bestPost != null) {
          if (replaceTitles || group.title.isEmpty) {
            group.title = bestPost.title;
          }

          if (!widget.suggestedTitles.contains(bestPost.title)) {
            widget.suggestedTitles.add(bestPost.title);
          }

          remainingPosts.remove(bestPost);
        }
      }

      setState(() {
        progress = 1;

        status = "پیشنهاد عنوان پایان یافت.";
      });

      widget.onFinished?.call();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        running = false;

        status = e.toString();
      });
    }
  }
}
