import 'dart:io';

import 'package:fgphoto/ui/models/duplicate_group.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DuplicateGroupCard extends StatelessWidget {
  final List<DuplicateGroup> groups;

  const DuplicateGroupCard({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'تصاویر تکراری',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(width: 8),

                InfoBadge(source: Text('${groups.length}')),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: groups.length,

              itemBuilder: (_, index) {
                final group = groups[index];

                return Padding(
                  padding: const EdgeInsets.all(8),

                  child: SizedBox(
                    height: 120,

                    child: Stack(
                      children: [
                        if (group.items.length > 2)
                          Positioned(
                            left: 20,
                            top: 20,
                            child: _thumb(group.items[2].path),
                          ),

                        if (group.items.length > 1)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: _thumb(group.items[1].path),
                          ),

                        Positioned(
                          left: 0,
                          top: 0,
                          child: _thumb(group.items[group.selectedIndex].path),
                        ),

                        Positioned(
                          right: 0,
                          bottom: 0,

                          child: InfoBadge(
                            source: Text('${group.items.length}'),
                          ),
                        ),
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

  Widget _thumb(String path) {
    return Container(
      width: 90,
      height: 90,

      decoration: BoxDecoration(border: Border.all()),

      child: Image.file(File(path), fit: BoxFit.cover),
    );
  }
}
