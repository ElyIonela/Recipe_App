import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ubex_image.dart';
import 'recipe_detail_screen.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.myRecipes(auth.token!);
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

  Future<void> _surpriseMe() async {
    if (_recipes.isEmpty) return;
    final random = (_recipes.toList()..shuffle()).first;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: random.id)),
    ).then((_) => _loadRecipes());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recipes'),
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
              ? const Center(child: Text('No recipes yet. Submit your first recipe!'))
              : RefreshIndicator(
                  onRefresh: _loadRecipes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
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
                                width: 100,
                                height: 80,
                                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                                    ? UbexImage(imageUrl: recipe.imageUrl, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.orange.shade50,
                                        child: const Icon(Icons.restaurant, color: Colors.orange),
                                      ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _statusColor(recipe.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: _statusColor(recipe.status)),
                                        ),
                                        child: Text(
                                          recipe.status.toUpperCase(),
                                          style: TextStyle(fontSize: 11, color: _statusColor(recipe.status), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (recipe.status == 'rejected' && recipe.rejectionReason != null && recipe.rejectionReason!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason: ${recipe.rejectionReason}',
                                          style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontStyle: FontStyle.italic),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
