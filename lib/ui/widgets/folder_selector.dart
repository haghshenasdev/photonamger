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

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          //--------------------------------------------------
          // Header
          //--------------------------------------------------
          Row(
            children: [
              const Icon(FluentIcons.folder_open, size: 20),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'مسیرهای اسکن',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),

              FilledButton(
                onPressed: onAdd,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 16),
                    SizedBox(width: 8),
                    Text('افزودن مسیر'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          //--------------------------------------------------
          // Empty state
          //--------------------------------------------------
          if (paths.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[70]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(FluentIcons.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('هنوز مسیری برای اسکن انتخاب نشده است.'),
                  ),
                ],
              ),
            )
          //--------------------------------------------------
          // Paths
          //--------------------------------------------------
          else
            ...paths.map((path) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[70]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.folder, size: 18),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        icon: const Icon(FluentIcons.chrome_close, size: 16),
                        onPressed: () {
                          onRemove(path);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
