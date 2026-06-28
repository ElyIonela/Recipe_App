class Rating {
  final String id;
  final String recipeId;
  final String userId;
  final int rating;
  final String createdAt;

  Rating({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.rating,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      recipeId: json['recipe_id'] ?? '',
      userId: json['user_id'] ?? '',
      rating: json['rating'] is int
          ? json['rating']
          : int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
