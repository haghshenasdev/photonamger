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
  // ------------------------------------------------------------
  // تنظیمات
  // ------------------------------------------------------------

  final TextEditingController channelController = TextEditingController(
    text: 'Hamase4',
  );

  bool onlyImagePosts = true;
  bool replaceTitles = true;

  int maxDistanceMinutes = 60;

  String channel = 'Hamase4';

  // ------------------------------------------------------------
  // Progress
  // ------------------------------------------------------------

  bool running = false;
  double? progress;
  String status = '';

  // ------------------------------------------------------------

  @override
  void dispose() {
    channelController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 520),
      title: const Text('پیشنهاد عنوان از کانال'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // کانال
          // ----------------------------------------------------
          const Text('نام کانال'),

          const SizedBox(height: 6),

          TextBox(
            controller: channelController,
            placeholder: '@channel',
            enabled: !running,
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // فاصله زمانی
          // ----------------------------------------------------
          const Text('حداکثر فاصله زمانی (دقیقه) برای تطبیق'),

          const SizedBox(height: 6),

          NumberBox(
            value: maxDistanceMinutes,
            min: 1,
            max: 720,
            mode: SpinButtonPlacementMode.inline,
            onChanged: running
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }

                    int? parsedValue;

                    if (value is int) {
                      parsedValue = value;
                    } else if (value is num) {
                      parsedValue = value.toInt();
                    } else {
                      parsedValue = int.tryParse(value.toString());
                    }

                    if (parsedValue == null) {
                      return;
                    }

                    if (parsedValue < 1) {
                      parsedValue = 1;
                    }

                    if (parsedValue > 720) {
                      parsedValue = 720;
                    }

                    setState(() {
                      maxDistanceMinutes = parsedValue!;
                    });
                  },
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // گزینه‌ها
          // ----------------------------------------------------
          Checkbox(
            checked: onlyImagePosts,
            onChanged: running
                ? null
                : (value) {
                    setState(() {
                      onlyImagePosts = value ?? true;
                    });
                  },
            content: const Text('فقط پست های دارای تصویر'),
          ),

          const SizedBox(height: 8),

          Checkbox(
            checked: replaceTitles,
            onChanged: running
                ? null
                : (value) {
                    setState(() {
                      replaceTitles = value ?? true;
                    });
                  },
            content: const Text('جایگزینی عنوان های فعلی'),
          ),

          const SizedBox(height: 24),

          // ----------------------------------------------------
          // Progress
          // ----------------------------------------------------
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
          child: const Text('انصراف'),
          onPressed: running
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),

        FilledButton(
          child: Text(running ? 'در حال اجرا...' : 'شروع'),
          onPressed: running ? null : _start,
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // START
  // ------------------------------------------------------------

  Future<void> _start() async {
    if (running) {
      return;
    }

    if (widget.groups.isEmpty) {
      setState(() {
        status = 'هیچ گروهی برای بررسی وجود ندارد.';
      });
      return;
    }

    setState(() {
      running = true;
      progress = null;
      status = 'در حال خواندن کانال...';
    });

    try {
      final requestedChannel = channelController.text.trim();

      if (requestedChannel.isEmpty) {
        throw Exception('نام کانال را وارد کنید.');
      }

      channel = requestedChannel.replaceFirst('@', '').trim();

      if (channel.isEmpty) {
        throw Exception('نام کانال معتبر نیست.');
      }

      final rc = ReadChannelService(
        predictor: CategoryPredictor(),
        channel: channel,
      );

      // --------------------------------------------------------
      // قدیمی‌ترین تاریخ گروه‌ها
      // --------------------------------------------------------

      final oldestDate = widget.groups
          .map((group) => group.start)
          .reduce((a, b) => a.isBefore(b) ? a : b)
          .subtract(Duration(minutes: maxDistanceMinutes));

      // --------------------------------------------------------
      // خواندن پست‌های کانال
      // --------------------------------------------------------

      final posts = await rc.read(
        oldestDate: oldestDate,
        onProgress: (value, message) {
          if (!mounted) {
            return;
          }

          setState(() {
            progress = value;
            status = message;
          });
        },
      );

      final remainingPosts = List<ChannelPost>.from(posts);

      // مرتب‌سازی از قدیمی به جدید
      remainingPosts.sort((a, b) => a.date.compareTo(b.date));

      widget.suggestedTitles.clear();

      // --------------------------------------------------------
      // تطبیق عنوان‌ها
      // --------------------------------------------------------

      for (int i = 0; i < widget.groups.length; i++) {
        if (!mounted) {
          return;
        }

        final group = widget.groups[i];

        // نمایش Progress هر 10 گروه
        if (i == 0 || i == widget.groups.length - 1 || i % 10 == 0) {
          setState(() {
            progress = (i + 1) / widget.groups.length;

            status = 'در حال بررسی گروه ${i + 1} از ${widget.groups.length}';
          });
        }

        ChannelPost? bestPost;
        Duration? bestDistance;

        // ------------------------------------------------------
        // پیدا کردن نزدیک‌ترین پست
        // ------------------------------------------------------

        for (final post in remainingPosts) {
          Duration distance;

          if (post.date.isBefore(group.start)) {
            distance = group.start.difference(post.date);
          } else if (post.date.isAfter(group.end)) {
            distance = post.date.difference(group.end);
          } else {
            distance = Duration.zero;
          }

          if (distance.inMinutes > maxDistanceMinutes) {
            continue;
          }

          if (bestDistance == null || distance < bestDistance) {
            bestDistance = distance;
            bestPost = post;
          }
        }

        // ------------------------------------------------------
        // اعمال نتیجه
        // ------------------------------------------------------

        if (bestPost != null && bestDistance != null) {
          if (replaceTitles || group.title.trim().isEmpty) {
            group.title = bestPost.title;
          }

          if (!widget.suggestedTitles.contains(bestPost.title)) {
            widget.suggestedTitles.add(bestPost.title);
          }

          // پست استفاده‌شده دوباره برای
          // گروه بعدی استفاده نشود.
          remainingPosts.remove(bestPost);
        }
      }

      // --------------------------------------------------------
      // پایان
      // --------------------------------------------------------

      if (!mounted) {
        return;
      }

      setState(() {
        running = false;
        progress = 1;
        status = 'پیشنهاد عنوان پایان یافت.';
      });

      widget.onFinished?.call();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        running = false;
        progress = null;
        status = error.toString();
      });
    }
  }
}
