import '../../ui/models/category_node.dart';
import '../../ui/models/timeline_group.dart';

class CategoryTreeBuilder {
  List<CategoryNode> build(List<TimelineGroup> groups) {
    final roots = <CategoryNode>[];

    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];

      if (group.categories.isEmpty) {
        continue;
      }

      var currentLevel = roots;

      for (final rawCategory in group.categories) {
        final category = rawCategory.trim();

        if (category.isEmpty) {
          continue;
        }

        CategoryNode? node;

        for (final child in currentLevel) {
          if (child.name == category) {
            node = child;
            break;
          }
        }

        if (node == null) {
          node = CategoryNode(name: category);

          currentLevel.add(node);
        }

        if (!node.groupIndexes.contains(groupIndex)) {
          node.groupIndexes.add(groupIndex);
        }

        currentLevel = node.children;
      }
    }

    _sort(roots);

    return roots;
  }

  void _sort(List<CategoryNode> nodes) {
    nodes.sort((a, b) => a.name.compareTo(b.name));

    for (final node in nodes) {
      _sort(node.children);
    }
  }
}
