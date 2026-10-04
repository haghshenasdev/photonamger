import '../../ui/models/category_node.dart';
import '../../ui/models/timeline_group.dart';

class CategoryTreeBuilder {
  List<CategoryNode> build(
    List<TimelineGroup> groups, {
    List<List<String>> extraPaths = const <List<String>>[],
  }) {
    final roots = <CategoryNode>[];

    void addPath(List<String> categoryPath) {
      if (categoryPath.isEmpty) return;

      var currentLevel = roots;

      for (final rawCategory in categoryPath) {
        final category = rawCategory.trim();
        if (category.isEmpty) continue;

        CategoryNode? node;
        for (final child in currentLevel) {
          if (child.name == category) {
            node = child;
            break;
          }
        }

        node ??= CategoryNode(name: category);
        if (!currentLevel.contains(node)) {
          currentLevel.add(node);
        }

        currentLevel = node.children;
      }
    }

    for (final group in groups) {
      for (final path in group.categories) {
        addPath(path);
      }
    }

    for (final path in extraPaths) {
      addPath(path);
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
