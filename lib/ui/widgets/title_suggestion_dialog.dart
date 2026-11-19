import 'dart:async';

import 'package:fgphoto/core/channel/category_predictor.dart';
import 'package:fgphoto/core/channel/chanel_post.dart';
import 'package:fgphoto/core/channel/read_chanel.dart';
import 'package:fgphoto/ui/models/timeline_group.dart';
import 'package:fgphoto/ui/widgets/persian_date_field.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
  bool preserveUserTitles = false;

  int maxDistanceMinutes = 60;

  String channel = 'Hamase4';

  // ------------------------------------------------------------
  // Progress
  // ------------------------------------------------------------

  bool running = false;
  bool paused = false;
  bool applying = false;
  bool finishReadingRequested = false;
  Completer<void>? _resumeCompleter;
  late DateTime oldestDate;
  int foundTitlesCount = 0;
  int replacedTitlesCount = 0;
  bool finished = false;
  double? progress;
  String status = '';
  final List<String> postLogs = <String>[];
  final List<ChannelPost> _pendingPostLogs = <ChannelPost>[];
  Timer? _postLogFlushTimer;
  final ScrollController _postLogScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    oldestDate = _automaticOldestDate();
  }

  DateTime _automaticOldestDate() {
    if (widget.groups.isEmpty)
      return DateTime.now().subtract(const Duration(days: 1));
    return widget.groups
        .map((group) => group.start)
        .reduce((a, b) => a.isBefore(b) ? a : b)
        .subtract(Duration(minutes: maxDistanceMinutes));
  }

  // ------------------------------------------------------------

  @override
  void dispose() {
    _postLogFlushTimer?.cancel();
    channelController.dispose();
    _postLogScrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 520),
      title: const Text('پیشنهاد عنوان از کانال'),
      content: SizedBox(
        width: 520,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
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

              const SizedBox(height: 12),
              const Text('قدیمی‌ترین تاریخ پست‌هایی که خوانده می‌شوند'),
              const SizedBox(height: 6),
              PersianDateField(
                value: oldestDate,
                onChanged: running
                    ? (_) {}
                    : (date) => setState(() => oldestDate = date),
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

              SizedBox(
                width: 480,
                child: Checkbox(
                  checked: preserveUserTitles,
                  onChanged: running
                      ? null
                      : (value) =>
                            setState(() => preserveUserTitles = value ?? false),
                  content: const Text('عنوان‌های دستی کاربر حفظ شوند'),
                ),
              ),
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 30, top: 2),
                child: Text(
                  'در این حالت فقط عنوان‌های پیش‌فرض مثل «گروه ۴» جایگزین می‌شوند.',
                  style: TextStyle(fontSize: 11),
                ),
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
              const SizedBox(height: 8),
              const Text(
                'لاگ پست‌های خوانده‌شده',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  controller: _postLogScrollController,
                  itemCount: postLogs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      postLogs[index],
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 11,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (running && !applying)
          Button(
            child: const Text('خواندن تا اینجا کافی است؛ جایگذاری کن'),
            onPressed: _finishReadingAndApply,
          ),
        if (running)
          Button(
            child: Text(paused ? 'ادامه' : 'توقف موقت'),
            onPressed: _togglePause,
          ),
        if (!running && finished)
          Button(
            child: const Text('بستن'),
            onPressed: () => Navigator.pop(context),
          ),
        if (!running && !finished)
          Button(
            child: const Text('انصراف'),
            onPressed: () => Navigator.pop(context),
          ),
        FilledButton(
          child: Text(
            running ? (paused ? 'متوقف‌شده' : 'در حال اجرا...') : 'شروع',
          ),
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
      paused = false;
      applying = false;
      finishReadingRequested = false;
      finished = false;
      foundTitlesCount = 0;
      replacedTitlesCount = 0;
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

      final cutoffDate = oldestDate;

      // --------------------------------------------------------
      // خواندن پست‌های کانال
      // --------------------------------------------------------

      postLogs.clear();
      _pendingPostLogs.clear();
      _postLogFlushTimer?.cancel();
      _postLogFlushTimer = null;
      final posts = await rc.read(
        oldestDate: cutoffDate,
        onlyImagePosts: onlyImagePosts,
        onProgress: (value, message) {
          if (!mounted) {
            return;
          }

          setState(() {
            progress = value;
            status = message;
          });
        },
        onPostRead: _queuePostLog,
        onPauseCheck: _waitWhilePaused,
        shouldStopReading: () => finishReadingRequested,
      );
      _flushPostLogs();

      if (!mounted) return;
      setState(() {
        applying = true;
        paused = false;
        status = 'در حال تطبیق و جایگذاری عنوان‌ها...';
        progress = null;
      });

      final remainingPosts = List<ChannelPost>.from(posts);

      // مرتب‌سازی از قدیمی به جدید
      remainingPosts.sort((a, b) => a.date.compareTo(b.date));
      foundTitlesCount = posts.length;
      replacedTitlesCount = 0;

      widget.suggestedTitles.clear();

      // --------------------------------------------------------
      // تطبیق عنوان‌ها
      // --------------------------------------------------------

      for (int i = 0; i < widget.groups.length; i++) {
        await _waitWhilePaused();
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
          final isSystemTitle = RegExp(
            r'^گروه\s+\d+$',
          ).hasMatch(group.title.trim());
          final canReplace = preserveUserTitles
              ? (isSystemTitle && !group.edited)
              : (replaceTitles || group.title.trim().isEmpty);
          if (canReplace) {
            group.title = bestPost.title;
            replacedTitlesCount++;
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
        paused = false;
        applying = false;
        finished = true;
        progress = 1;
        status =
            'پایان کار: $foundTitlesCount عنوان پیدا شد و $replacedTitlesCount عنوان جایگزین شد.';
      });

      widget.onFinished?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        running = false;
        paused = false;
        applying = false;
        progress = null;
        status = error.toString();
      });
    }
  }

  void _queuePostLog(ChannelPost post) {
    _pendingPostLogs.add(post);
    _postLogFlushTimer ??= Timer(
      const Duration(milliseconds: 180),
      _flushPostLogs,
    );
  }

  void _flushPostLogs() {
    _postLogFlushTimer?.cancel();
    _postLogFlushTimer = null;
    if (!mounted || _pendingPostLogs.isEmpty) return;
    final batch = List<ChannelPost>.from(_pendingPostLogs);
    _pendingPostLogs.clear();
    final lines = batch.map((post) {
      final snippet = post.preview.length > 150
          ? '${post.preview.substring(0, 150)}…'
          : post.preview;
      final localDate = post.date.toLocal();
      final jalali = Jalali.fromDateTime(localDate);
      final jalaliDate =
          '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
      final time =
          '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
      return '$jalaliDate $time  •  $snippet';
    }).toList();
    print('[Channel posts]\n${lines.join('\n')}');
    setState(() {
      postLogs.addAll(lines);
      if (postLogs.length > 300) {
        postLogs.removeRange(0, postLogs.length - 300);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_postLogScrollController.hasClients) {
        _postLogScrollController.jumpTo(
          _postLogScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _finishReadingAndApply() {
    setState(() {
      finishReadingRequested = true;
      if (paused) {
        paused = false;
        _resumeCompleter?.complete();
        _resumeCompleter = null;
      }
      status = 'پس از پایان صفحه‌ی جاری، جایگذاری عنوان‌ها شروع می‌شود...';
    });
  }

  void _togglePause() {
    setState(() {
      if (paused) {
        paused = false;
        _resumeCompleter?.complete();
        _resumeCompleter = null;
        status = 'ادامه خواندن و استخراج پست‌ها...';
      } else {
        paused = true;
        _resumeCompleter = Completer<void>();
        status = 'فرایند متوقف شده است؛ برای ادامه دکمه «ادامه» را بزنید.';
      }
    });
  }

  Future<void> _waitWhilePaused() async {
    while (paused) {
      final completer = _resumeCompleter;
      if (completer == null) return;
      await completer.future;
    }
  }
}
