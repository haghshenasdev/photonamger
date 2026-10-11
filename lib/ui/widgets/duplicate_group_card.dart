import 'dart:io';

import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DuplicateGroupCard extends StatelessWidget {
  final List<DuplicateGroup> groups;

  /// وقتی روی یک گروه کلیک شود.
  final ValueChanged<DuplicateGroup>? onGroupTap;

  const DuplicateGroupCard({super.key, required this.groups, this.onGroupTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(FluentIcons.copy, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'عکس‌های پشت‌سرهم',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                InfoBadge(source: Text('${groups.length} گروه')),
              ],
            ),
          ),
          Container(height: 1, color: theme.acrylicBackgroundColor),
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.copy, size: 32),
                        SizedBox(height: 10),
                        Text('گروه پشت‌سرهمی پیدا نشده است'),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final selectedCount = group.selectedIndices
                          .where((i) => i >= 0 && i < group.items.length)
                          .length;
                      final primaryPath = group.items.isEmpty
                          ? null
                          : group.items[
                              group.selectedIndex >= 0 &&
                                      group.selectedIndex < group.items.length
                                  ? group.selectedIndex
                                  : 0
                            ].path;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onGroupTap?.call(group),
                        child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.micaBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.acrylicBackgroundColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  height: 86,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (group.items.length > 2)
                                        Positioned(
                                          left: 16,
                                          top: 12,
                                          child: _thumb(group.items[2].path, 66),
                                        ),
                                      if (group.items.length > 1)
                                        Positioned(
                                          left: 8,
                                          top: 6,
                                          child: _thumb(group.items[1].path, 66),
                                        ),
                                      if (primaryPath != null)
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: _thumb(primaryPath, 66),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'گروه پشت‌سرهم ${index + 1}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 5,
                                        children: [
                                          _countPill(
                                            icon: FluentIcons.photo,
                                            text: '${group.items.length} عکس',
                                          ),
                                          _countPill(
                                            icon: FluentIcons.checkbox_composite,
                                            text: '$selectedCount انتخاب‌شده',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'برای مشاهده و تغییر انتخاب‌ها کلیک کنید',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[120],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(FluentIcons.chevron_left, size: 14),
                              ],
                            ),
                          ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _countPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[30],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _thumb(String path, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[100]),
        borderRadius: BorderRadius.circular(7),
        color: Colors.grey[30],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(FluentIcons.photo, size: 20),
        ),
      ),
    );
  }
}
