import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ubex_image.dart';
import 'recipe_detail_screen.dart';
import 'edit_recipe_screen.dart';

class ManageRecipesScreen extends StatefulWidget {
  const ManageRecipesScreen({super.key});

  @override
  State<ManageRecipesScreen> createState() => _ManageRecipesScreenState();
}

class _ManageRecipesScreenState extends State<ManageRecipesScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.listRecipes();
      if (response['success'] == true && response['recipes'] is List) {
        _recipes = (response['recipes'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load recipes')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Permanently delete "${recipe.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteRecipe(auth.token!, recipe.id);
      if (response['success'] == true) _loadRecipes();
    } catch (_) {}
  }

  Future<void> _editRecipe(Recipe recipe) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: recipe)),
    );
    if (edited == true) _loadRecipes();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Recipes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _recipes.isEmpty
              ? const Center(child: Text('No recipes'))
              : RefreshIndicator(
                  onRefresh: _loadRecipes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
                            ).then((_) => _loadRecipes());
                          },
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 70,
                                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                                    ? UbexImage(imageUrl: recipe.imageUrl, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.orange.shade50,
                                        child: const Icon(Icons.restaurant, color: Colors.orange, size: 28),
                                      ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _statusColor(recipe.status).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: _statusColor(recipe.status)),
                                            ),
                                            child: Text(recipe.status, style: TextStyle(fontSize: 10, color: _statusColor(recipe.status), fontWeight: FontWeight.bold)),
                                          ),
                                          if (recipe.category.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(recipe.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                onPressed: () => _editRecipe(recipe),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _deleteRecipe(recipe),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
