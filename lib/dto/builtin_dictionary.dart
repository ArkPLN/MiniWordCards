/// 内置词库定义（硬编码）
class BuiltinDictionary {
  final String id;
  final String name;
  final String assetPath;
  final String category;
  final String variant;
  final String description;

  const BuiltinDictionary({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.category,
    required this.variant,
    required this.description,
  });
}
