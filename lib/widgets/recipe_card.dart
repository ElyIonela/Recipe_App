import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../widgets/star_rating.dart';
import '../widgets/ubex_image.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isFav = auth.isFavorite(recipe.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                      ? UbexImage(
                          imageUrl: recipe.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.orange.shade50,
                            child: const Center(
                              child: Icon(Icons.restaurant, size: 40, color: Colors.orange),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.orange.shade50,
                          child: const Center(
                            child: Icon(Icons.restaurant, size: 40, color: Colors.orange),
                          ),
                        ),
                  // Favorite button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Difficulty badge
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _difficultyColor(recipe.difficulty),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        recipe.difficulty,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StarRating(rating: recipe.avgRating, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '(${recipe.ratingCount})',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text(
                        '${recipe.cookTime} min',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
