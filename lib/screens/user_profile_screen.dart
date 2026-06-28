import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  final String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserRecipes();
  }

  Future<void> _loadUserRecipes() async {
    setState(() => _isLoading = true);
    try {
      // Load all recipes and filter by this user
      final response = await ApiService.listRecipes();
      if (response['success'] == true && response['recipes'] is List) {
        _recipes = (response['recipes'] as List)
            .map((r) => Recipe.fromJson(r))
            .where((r) => r.submittedBy == widget.userId)
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onFavoriteTap(Recipe recipe) {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(pendingFavoriteRecipeId: recipe.id)),
      );
      return;
    }
    auth.toggleFavorite(recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chef's Recipes")),
      body: Column(
        children: [
          const SizedBox(height: 16),
          UserAvatar(userId: widget.userId, userName: _userName, radius: 40),
          const SizedBox(height: 8),
          Text(
            '${_recipes.length} recipe${_recipes.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _recipes.isEmpty
                    ? const Center(child: Text('No published recipes'))
                    : GridView.builder(
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
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
                                ),
                              );
                            },
                            onFavoriteTap: () => _onFavoriteTap(recipe),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
