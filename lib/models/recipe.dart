import 'dart:convert';

class Recipe {
  final String id;
  final String title;
  final String description;
  final List<Map<String, dynamic>> ingredients;
  final List<String> steps;
  final int cookTime;
  final int prepTime;
  final int servings;
  final String difficulty;
  final String category;
  final String? imageUrl;
  final String tags;
  final String? submittedBy;
  final String status;
  final String? rejectionReason;
  final double avgRating;
  final int ratingCount;
  final String? createdAt;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.cookTime,
    required this.prepTime,
    required this.servings,
    required this.difficulty,
    required this.category,
    this.imageUrl,
    required this.tags,
    this.submittedBy,
    required this.status,
    this.rejectionReason,
    required this.avgRating,
    required this.ratingCount,
    this.createdAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Parse ingredients - can be a JSON string, a list, or comma-separated
    List<Map<String, dynamic>> parseIngredients(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e is Map<String, dynamic> ? e : {'name': e.toString()}).toList();
      }
      if (value is String) {
        if (value.isEmpty) return [];
        try {
          final parsed = jsonDecode(value);
          if (parsed is List) {
            return parsed.map((e) => e is Map<String, dynamic> ? e : {'name': e.toString()}).toList();
          }
        } catch (_) {}
        // Fallback: comma-separated string
        return value.split(',').map((s) => {'name': s.trim()}).where((m) => (m['name'] as String).isNotEmpty).toList();
      }
      return [];
    }

    // Parse steps - can be a JSON string, a list, or comma-separated
    List<String> parseSteps(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        if (value.isEmpty) return [];
        try {
          final parsed = jsonDecode(value);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
        // Fallback: steps separated by commas (each step is a sentence)
        // Split on comma but keep periods attached to the text before the comma
        final steps = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        return steps;
      }
      return [];
    }

    return Recipe(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      ingredients: parseIngredients(json['ingredients']),
      steps: parseSteps(json['steps']),
      cookTime: _parseInt(json['cook_time']),
      prepTime: _parseInt(json['prep_time']),
      servings: _parseInt(json['servings']),
      difficulty: json['difficulty'] ?? 'medium',
      category: json['category'] ?? '',
      imageUrl: json['image_url'],
      tags: json['tags'] ?? '',
      submittedBy: json['submitted_by'],
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      avgRating: _parseDouble(json['avg_rating']),
      ratingCount: _parseInt(json['rating_count']),
      createdAt: json['created_at'],
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'ingredients': jsonEncode(ingredients),
      'steps': jsonEncode(steps),
      'cook_time': cookTime,
      'prep_time': prepTime,
      'servings': servings,
      'difficulty': difficulty,
      'category': category,
      'image_url': imageUrl,
      'tags': tags,
    };
  }
}
