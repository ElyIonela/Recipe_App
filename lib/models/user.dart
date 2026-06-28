class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profilePicture;
  final String? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profilePicture,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profile_picture': profilePicture,
      'created_at': createdAt,
    };
  }
}
