import 'package:fgphoto/ui/models/statistics_snapshot.dart';
import 'package:fgphoto/ui/widgets/statistics_charts.dart';
import 'package:fluent_ui/fluent_ui.dart';

class StatisticsPage extends StatelessWidget {
  final StatisticsSnapshot stats;

  const StatisticsPage({super.key, required this.stats});

  String _bytes(int bytes) {
    if (bytes < 1024) return '$bytes بایت';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unit = -1;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('آمار جامع آرشینو'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 330,
              child: ListView(
                children: [
                  _MetricCard('کل فایل‌ها', '${stats.totalFiles}'),
                  _MetricCard('تصاویر', '${stats.images}'),
                  _MetricCard('ویدئوها', '${stats.videos}'),
                  _MetricCard('گروه‌های Timeline', '${stats.groups}'),
                  _MetricCard('دسته‌بندی‌ها', '${stats.categories}'),
                  _MetricCard('تصاویر دارای چهره', '${stats.faceImages}'),
                  _MetricCard('تعداد چهره‌ها', '${stats.faces}'),
                  _MetricCard('گروه‌های تکراری', '${stats.duplicateGroups}'),
                  _MetricCard('فایل‌های تکراری', '${stats.duplicateFiles}'),
                  _MetricCard('میانگین کیفیت', '${stats.averageQuality.toStringAsFixed(1)}'),
                  _MetricCard('حجم کل', _bytes(stats.totalBytes)),
                  _MetricCard('حجم منتخب', _bytes(stats.selectedBytes)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SingleChildScrollView(
                child: StatisticsCharts(stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[50]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
