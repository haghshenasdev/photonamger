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
    final metrics = <_MetricData>[
      _MetricData('کل فایل‌ها', '${stats.totalFiles}', FluentIcons.document),
      _MetricData('تصاویر', '${stats.images}', FluentIcons.photo),
      _MetricData('ویدئوها', '${stats.videos}', FluentIcons.video),
      _MetricData('گروه‌های زمانی', '${stats.groups}', FluentIcons.calendar),
      _MetricData('دسته‌بندی‌ها', '${stats.categories}', FluentIcons.folder),
      _MetricData('تصاویر دارای چهره', '${stats.faceImages}', FluentIcons.contact),
      _MetricData('تعداد چهره‌ها', '${stats.faces}', FluentIcons.people),
      _MetricData('گروه‌های تکراری', '${stats.duplicateGroups}', FluentIcons.copy),
      _MetricData('فایل‌های تکراری', '${stats.duplicateFiles}', FluentIcons.copy),
      _MetricData('میانگین کیفیت', '${stats.averageQuality.toStringAsFixed(1)}٪', FluentIcons.analytics_logo),
      _MetricData('حجم کل', _bytes(stats.totalBytes), FluentIcons.database),
      _MetricData('حجم فایل‌های منتخب', _bytes(stats.selectedBytes), FluentIcons.checkbox_composite),
    ];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(FluentIcons.chart, color: Color(0xFF2563EB), size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('آمار جامع آرشینو', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF172033))),
                      SizedBox(height: 3),
                      Text('نمای کلی از فایل‌ها، دسته‌بندی‌ها، چهره‌ها و فضای ذخیره‌سازی', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${stats.totalFiles} فایل ثبت‌شده', style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('خلاصه اطلاعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF172033))),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1150 ? 4 : constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 480 ? 2 : 1;
                      final spacing = 12.0;
                      final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final metric in metrics)
                            SizedBox(width: cardWidth, child: _MetricCard(metric: metric)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(FluentIcons.chart, size: 18, color: Color(0xFF334155)),
                      SizedBox(width: 8),
                      Text('نمودارها و تحلیل‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF172033))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatisticsCharts(stats: stats),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;

  const _MetricData(this.title, this.value, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, size: 19, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 5),
                Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
