import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/ubex_image.dart';
import 'recipe_detail_screen.dart';
import 'edit_recipe_screen.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  List<Recipe> _pendingRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final auth = context.read<AuthService>();
    if (!auth.isAdmin) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.pendingRecipes(auth.token!);
      if (response['success'] == true && response['recipes'] is List) {
        _pendingRecipes = (response['recipes'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load pending recipes')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(Recipe recipe) async {
    final auth = context.read<AuthService>();
    try {
      final response = await ApiService.approveRecipe(auth.token!, recipe.id);
      if (response['success'] == true) {
        _loadPending();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${recipe.title}" approved!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _reject(Recipe recipe) async {
    final auth = context.read<AuthService>();
    final reason = await _showRejectDialog();
    if (reason == null) return;

    try {
      final response = await ApiService.rejectRecipe(auth.token!, recipe.id, reason);
      if (response['success'] == true) {
        _loadPending();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${recipe.title}" rejected.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (_) {}
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _delete(Recipe recipe) async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Delete "${recipe.title}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await ApiService.deleteRecipe(auth.token!, recipe.id);
      if (response['success'] == true) _loadPending();
    } catch (_) {}
  }

  Future<void> _editAndApprove(Recipe recipe) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: recipe)),
    );
    if (edited == true) {
      // After edit, approve automatically
      final auth = context.read<AuthService>();
      await ApiService.approveRecipe(auth.token!, recipe.id);
      _loadPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Queue')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _pendingRecipes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text('All caught up!', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pendingRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _pendingRecipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image + info
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
                                ).then((_) => _loadPending());
                              },
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 90,
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
                                          Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(recipe.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (recipe.category.isNotEmpty) ...[
                                                Icon(Icons.category, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(recipe.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                                const SizedBox(width: 8),
                                              ],
                                              Icon(Icons.timer, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text('${recipe.cookTime}min', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _approve(recipe),
                                      icon: const Icon(Icons.check, color: Colors.green, size: 18),
                                      label: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 12)),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _reject(recipe),
                                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _editAndApprove(recipe),
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                      label: const Text('Edit', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _delete(recipe),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
