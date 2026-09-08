class CategoryNode {
  final String name;

  final List<CategoryNode> children;

  /// index گروه‌هایی که در این دسته قرار دارند.
  final List<int> groupIndexes;

  CategoryNode({
    required this.name,
    List<CategoryNode>? children,
    List<int>? groupIndexes,
  }) : children = children ?? [],
       groupIndexes = groupIndexes ?? [];

  CategoryNode? findChild(String name) {
    for (final child in children) {
      if (child.name == name) {
        return child;
      }
    }

    return null;
  }
}
