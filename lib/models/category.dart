class RecipeCategory {
  final String id;
  final String name;
  final String icon;
  final int sortOrder;

  RecipeCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
  });

  factory RecipeCategory.fromJson(Map<String, dynamic> json) {
    return RecipeCategory(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'restaurant',
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    };
  }
}
