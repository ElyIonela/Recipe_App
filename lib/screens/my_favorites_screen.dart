import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);
    try {
      final favResponse = await ApiService.listFavorites(auth.token!);
      if (favResponse['success'] == true && favResponse['favorites'] is List) {
        final favoriteIds = (favResponse['favorites'] as List)
            .map((f) => f['recipe_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        final recipes = <Recipe>[];
        // Load each recipe's details
        final futures = favoriteIds.map((id) => ApiService.getRecipe(id));
        final results = await Future.wait(futures);
        for (final result in results) {
          if (result['success'] == true && result['recipe'] != null) {
            recipes.add(Recipe.fromJson(result['recipe']));
          }
        }
        _recipes = recipes;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load favorites')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _surpriseMe() async {
    if (_recipes.isEmpty) return;
    final random = (_recipes.toList()..shuffle()).first;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: random.id)),
    ).then((_) => _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          TextButton.icon(
            onPressed: _surpriseMe,
            icon: const Icon(Icons.casino, color: Colors.orange),
            label: const Text('Surprise Me!', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _recipes.isEmpty
              ? const Center(child: Text('No favorites yet. Tap the heart on recipes you love!'))
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return RecipeCard(
                        recipe: recipe,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
                          ).then((_) => _loadFavorites());
                        },
                        onFavoriteTap: () {
                          context.read<AuthService>().toggleFavorite(recipe.id);
                          // Remove from local list
                          setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
