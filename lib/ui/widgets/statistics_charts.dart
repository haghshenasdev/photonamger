import 'dart:math' as math;

import 'package:fgphoto/ui/models/statistics_snapshot.dart';
import 'package:fluent_ui/fluent_ui.dart';

class StatisticsCharts extends StatelessWidget {
  final StatisticsSnapshot stats;
  final bool compact;

  const StatisticsCharts({
    super.key,
    required this.stats,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _ChartPanel(
        title: 'توزیع فایل‌ها',
        height: 175,
        child: _BarChart(
          values: stats.extensions.isNotEmpty
              ? stats.extensions
              : stats.filesByYear.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartPanel(
          title: 'تعداد فایل بر اساس سال شمسی',
          height: 210,
          child: _BarChart(
            values: stats.filesByYear.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ChartPanel(
          title: 'تصویر / ویدئو',
          height: 210,
          child: _MediaTypeChart(stats: stats),
        ),
        const SizedBox(height: 10),
        _ChartPanel(
          title: 'توزیع ماه‌های شمسی',
          height: 210,
          child: _BarChart(
            values: stats.filesByMonth.map(
              (key, value) => MapEntry(_monthName(key), value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ChartPanel(
          title: 'توزیع نوع فایل',
          height: 210,
          child: _BarChart(values: stats.extensions),
        ),
        if (!compact && stats.categoryCounts.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ChartPanel(
            title: 'دسته‌بندی‌ها',
            height: 230,
            child: _BarChart(values: stats.categoryCounts),
          ),
        ],
        if (!compact) ...[
          const SizedBox(height: 10),
          _ChartPanel(
            title: 'شاخص‌های کلیدی',
            height: 190,
            child: _MetricBars(stats: stats),
          ),
        ],
      ],
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;

  const _ChartPanel({
    required this.title,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[50]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, int> values;

  const _BarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('داده‌ای برای نمایش وجود ندارد.'));
    }

    final entries = values.entries.take(12).toList();
    final maxValue = entries.fold<int>(
      1,
      (max, entry) => math.max(max, entry.value),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: entry.value / maxValue,
                        widthFactor: .72,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.key,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaTypeChart extends StatelessWidget {
  final StatisticsSnapshot stats;

  const _MediaTypeChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.images + stats.videos;
    if (total == 0) {
      return const Center(child: Text('داده‌ای برای نمایش وجود ندارد.'));
    }

    final imageRatio = stats.images / total;
    final videoRatio = stats.videos / total;

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _DonutPainter(
              firstRatio: imageRatio,
              secondRatio: videoRatio,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تصاویر: ${stats.images}'),
            const SizedBox(height: 8),
            Text('ویدئوها: ${stats.videos}'),
            const SizedBox(height: 8),
            Text('مجموع: $total'),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double firstRatio;
  final double secondRatio;

  const _DonutPainter({
    required this.firstRatio,
    required this.secondRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.butt;

    final start = -math.pi / 2;
    final firstSweep = 2 * math.pi * firstRatio;

    paint.color = Colors.blue;
    canvas.drawArc(rect.deflate(14), start, firstSweep, false, paint);

    paint.color = Colors.green;
    canvas.drawArc(
      rect.deflate(14),
      start + firstSweep,
      2 * math.pi * secondRatio,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.firstRatio != firstRatio ||
        oldDelegate.secondRatio != secondRatio;
  }
}

String _monthName(int month) {
  const names = [
    'فرو',
    'ارد',
    'خرد',
    'تیر',
    'مر',
    'شه',
    'مهر',
    'آبا',
    'آذر',
    'دی',
    'بهم',
    'اسف',
  ];
  if (month < 1 || month > 12) return '$month';
  return names[month - 1];
}

class _MetricBars extends StatelessWidget {
  final StatisticsSnapshot stats;

  const _MetricBars({required this.stats});

  @override
  Widget build(BuildContext context) {
    final metrics = <String, double>{
      'آنالیز شده': stats.totalFiles == 0
          ? 0
          : stats.analyzedFiles / stats.totalFiles,
      'دارای چهره': stats.images == 0 ? 0 : stats.faceImages / stats.images,
      'انتخاب شده': stats.totalFiles == 0
          ? 0
          : stats.selectedFiles / stats.totalFiles,
      'کیفیت متوسط': (stats.averageQuality / 100).clamp(0, 1),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final entry in metrics.entries)
          Row(
            children: [
              SizedBox(width: 85, child: Text(entry.key)),
              Expanded(
                child: ProgressBar(value: entry.value * 100),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text('${(entry.value * 100).round()}%'),
              ),
            ],
          ),
      ],
    );
  }
}
