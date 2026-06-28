class Comment {
  final String id;
  final String recipeId;
  final String userId;
  final String userName;
  final String text;
  final String? imageUrl;
  final String createdAt;

  Comment({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userName,
    required this.text,
    this.imageUrl,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      recipeId: json['recipe_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Anonymous',
      text: json['text'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
