import 'package:fluent_ui/fluent_ui.dart';

class FolderSelector extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const FolderSelector({
    super.key,
    required this.paths,
    required this.onAdd,
    required this.onRemove,
  });

  static const int _maxPreviewPaths = 2;

  @override
  Widget build(BuildContext context) {
    final previewPaths = paths.take(_maxPreviewPaths).toList();
    final remainingCount = paths.length - previewPaths.length;

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // Header
          // ============================================================
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(FluentIcons.folder_open, size: 19),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مسیرهای آنالیز',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paths.isEmpty
                          ? 'مسیری برای بررسی انتخاب نشده است'
                          : '${paths.length} مسیر انتخاب شده',
                      style: TextStyle(fontSize: 12, color: Colors.grey[110]),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              FilledButton(
                onPressed: onAdd,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 15),
                    SizedBox(width: 7),
                    Text('افزودن مسیر'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ============================================================
          // Empty state
          // ============================================================
          if (paths.isEmpty)
            _EmptyState()
          // ============================================================
          // Paths
          // ============================================================
          else ...[
            for (final path in previewPaths)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _PathItem(path: path, onRemove: () => onRemove(path)),
              ),

            // ============================================================
            // Show all button
            // ============================================================
            if (remainingCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Button(
                  onPressed: () => _showAllPaths(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.list, size: 15),
                      const SizedBox(width: 7),
                      Text('نمایش همه مسیرها  •  $remainingCount مسیر دیگر'),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==================================================================
  // Show all paths dialog
  // ==================================================================

  Future<void> _showAllPaths(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ContentDialog(
          title: Row(
            children: [
              const Icon(FluentIcons.folder_open, size: 20),
              const SizedBox(width: 10),
              const Text('مسیرهای آنالیز'),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[30],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${paths.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          content: SizedBox(
            width: 650,
            height: 430,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'مسیرهایی که برای آنالیز انتخاب کرده‌اید:',
                  style: TextStyle(fontSize: 13, color: Colors.grey[110]),
                ),

                const SizedBox(height: 12),

                // ======================================================
                // Scrollable paths
                // ======================================================
                Expanded(
                  child: ListView.separated(
                    itemCount: paths.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 6);
                    },
                    itemBuilder: (context, index) {
                      final path = paths[index];

                      return _PathItem(
                        path: path,
                        number: index + 1,
                        onRemove: () {
                          onRemove(path);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          actions: [
            Button(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('بستن'),
            ),

            FilledButton(
              onPressed: onAdd,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 15),
                  SizedBox(width: 7),
                  Text('افزودن مسیر'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ======================================================================
// Empty State
// ======================================================================

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[10],
        border: Border.all(color: Colors.grey[50]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.folder_open, size: 18, color: Colors.grey[100]),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'برای شروع، حداقل یک پوشه برای آنالیز اضافه کنید.',
              style: TextStyle(fontSize: 12, color: Colors.grey[110]),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Path Item
// ======================================================================

class _PathItem extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final int? number;

  const _PathItem({required this.path, required this.onRemove, this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 6, right: 10),
      decoration: BoxDecoration(
        color: Colors.grey[20],
        border: Border.all(color: Colors.grey[50]),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          // ============================================================
          // Number
          // ============================================================
          if (number != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[40],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),
          ],

          // ============================================================
          // Folder icon
          // ============================================================
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(FluentIcons.folder, size: 16),
          ),

          const SizedBox(width: 9),

          // ============================================================
          // Path
          // ============================================================
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          const SizedBox(width: 5),

          // ============================================================
          // Remove
          // ============================================================
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 13),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
