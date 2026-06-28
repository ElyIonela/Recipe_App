import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/star_rating.dart';
import '../widgets/ubex_image.dart';
import '../widgets/comment_tile.dart';
import '../widgets/user_avatar.dart';
import '../widgets/image_source_picker.dart';
import 'login_screen.dart';
import 'edit_recipe_screen.dart';
import 'user_profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  List<Comment> _comments = [];
  int? _myRating;
  bool _isLoading = true;
  bool _isLoadingNutrition = false;
  String? _nutritionResult;
  final _commentController = TextEditingController();
  File? _commentImage;
  bool _isSubmittingComment = false;
  final Set<int> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthService>();
      final futures = <Future>[
        ApiService.getRecipe(widget.recipeId),
        ApiService.listComments(widget.recipeId),
      ];
      if (auth.isAuthenticated && auth.token != null) {
        futures.add(ApiService.getMyRating(auth.token!, widget.recipeId));
      }

      final results = await Future.wait(futures);

      final recipeResponse = results[0] as Map<String, dynamic>;
      final commentsResponse = results[1] as Map<String, dynamic>;

      if (recipeResponse['success'] == true && recipeResponse['recipe'] != null) {
        _recipe = Recipe.fromJson(recipeResponse['recipe']);
      }

      if (commentsResponse['success'] == true && commentsResponse['comments'] is List) {
        _comments = (commentsResponse['comments'] as List)
            .map((c) => Comment.fromJson(c))
            .toList();
      }

      if (results.length > 2) {
        final ratingResponse = results[2] as Map<String, dynamic>;
        if (ratingResponse['success'] == true && ratingResponse['rating'] != null) {
          _myRating = ratingResponse['rating'] is int
              ? ratingResponse['rating']
              : int.tryParse(ratingResponse['rating'].toString());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load recipe')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rateRecipe(int rating) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    try {
      final response = await ApiService.rateRecipe(auth.token!, widget.recipeId, rating);
      if (response['success'] == true) {
        setState(() => _myRating = rating);
        _loadData(); // Reload to get updated avg
      }
    } catch (_) {}
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    setState(() => _isSubmittingComment = true);
    try {
      String? imageUrl;
      if (_commentImage != null) {
        // Upload image first via recipe-image endpoint
        final uploadResponse = await ApiService.uploadRecipeImage(
          auth.token!,
          widget.recipeId,
          _commentImage!.path,
        );
        if (uploadResponse['success'] == true) {
          imageUrl = uploadResponse['image_url'];
        }
      }

      final response = await ApiService.addComment(
        auth.token!,
        widget.recipeId,
        _commentController.text.trim(),
        imageUrl: imageUrl,
      );
      if (response['success'] == true) {
        _commentController.clear();
        _commentImage = null;
        await _loadData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteComment(auth.token!, commentId);
      _loadData();
    } catch (_) {}
  }

  Future<void> _deleteRecipe() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || _recipe == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      Map<String, dynamic> response;
      if (auth.isAdmin) {
        response = await ApiService.deleteRecipe(auth.token!, _recipe!.id);
      } else {
        response = await ApiService.deleteOwnRecipe(auth.token!, _recipe!.id);
      }
      if (response['success'] == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {}
  }

  Future<void> _loadNutrition() async {
    if (_recipe == null) return;
    setState(() => _isLoadingNutrition = true);
    try {
      final ingredientsStr = _recipe!.ingredients
          .map((i) => i['name'] ?? i.toString())
          .join(', ');
      final response = await ApiService.getNutrition(
        _recipe!.title,
        ingredientsStr,
        _recipe!.servings,
      );
      if (response['success'] == true) {
        _nutritionResult = response['result'] ?? response['response'] ?? 'No data available.';
      } else {
        _nutritionResult = response['error'] ?? 'Analysis failed.';
      }
    } catch (_) {
      _nutritionResult = 'Failed to analyze nutrition.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingNutrition = false);
        _showNutritionSheet();
      }
    }
  }

  void _showNutritionSheet() {
    if (_nutritionResult == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Nutritional Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: Markdown(
                  controller: controller,
                  data: _nutritionResult!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCookingMode() {
    if (_recipe == null || _recipe!.steps.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CookingModeScreen(steps: _recipe!.steps, title: _recipe!.title),
      ),
    );
  }

  void _shareRecipe() {
    if (_recipe == null) return;
    final r = _recipe!;
    final text = '''${r.title}
⭐ ${r.avgRating.toStringAsFixed(1)} (${r.ratingCount} ratings)

Ingredients:
${r.ingredients.map((i) => '• ${i['name'] ?? i}').join('\n')}

Steps:
${r.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Tags: ${r.tags}''';
    Share.share(text);
  }

  void _onFavoriteTap() {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(pendingFavoriteRecipeId: _recipe?.id),
        ),
      );
      return;
    }
    if (_recipe != null) auth.toggleFavorite(_recipe!.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Recipe not found')),
      );
    }

    final recipe = _recipe!;
    final isOwner = auth.isAuthenticated && auth.user?.id == recipe.submittedBy;
    final canEdit = isOwner || auth.isAdmin;
    final isFav = auth.isFavorite(recipe.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image + App Bar
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                onPressed: _onFavoriteTap,
              ),
              IconButton(icon: const Icon(Icons.share), onPressed: _shareRecipe),
              if (canEdit)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: recipe)),
                      ).then((edited) { if (edited == true) _loadData(); });
                    } else if (value == 'delete') {
                      _deleteRecipe();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _showFullImage(context, recipe.imageUrl!),
                      child: UbexImage(imageUrl: recipe.imageUrl, fit: BoxFit.cover),
                    )
                  : Container(
                      color: Colors.orange.shade50,
                      child: const Center(child: Icon(Icons.restaurant, size: 80, color: Colors.orange)),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and rating
                  Text(recipe.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StarRating(rating: recipe.avgRating, size: 20),
                      const SizedBox(width: 6),
                      Text('${recipe.avgRating.toStringAsFixed(1)} (${recipe.ratingCount})',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(Icons.timer, '${recipe.prepTime}m prep'),
                      _infoChip(Icons.local_fire_department, '${recipe.cookTime}m cook'),
                      _infoChip(Icons.people, '${recipe.servings} servings'),
                      _infoChip(Icons.signal_cellular_alt, recipe.difficulty),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  if (recipe.description.isNotEmpty) ...[
                    Text(recipe.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                  ],

                  // Author
                  if (recipe.submittedBy != null) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: recipe.submittedBy!),
                        ));
                      },
                      child: Row(
                        children: [
                          UserAvatar(userId: recipe.submittedBy!, userName: '', radius: 14),
                          const SizedBox(width: 8),
                          Text("View chef's recipes", style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openCookingMode,
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Cook'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingNutrition ? null : _loadNutrition,
                          icon: _isLoadingNutrition
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.local_fire_department),
                          label: const Text('Calories'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Ingredients
                  const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...recipe.ingredients.asMap().entries.map((entry) {
                    final i = entry.key;
                    final ingredient = entry.value;
                    final checked = _checkedIngredients.contains(i);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedIngredients.add(i);
                          } else {
                            _checkedIngredients.remove(i);
                          }
                        });
                      },
                      title: Text(
                        ingredient['name'] ?? ingredient.toString(),
                        style: TextStyle(
                          decoration: checked ? TextDecoration.lineThrough : null,
                          color: checked ? Colors.grey : null,
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 32),

                  // Steps
                  const Text('Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...recipe.steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.orange,
                            child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(step, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 32),

                  // Rating (interactive)
                  if (auth.isAuthenticated) ...[
                    const Text('Rate this recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    StarRating(
                      rating: (_myRating ?? 0).toDouble(),
                      size: 36,
                      interactive: true,
                      onRatingChanged: _rateRecipe,
                    ),
                    const Divider(height: 32),
                  ],

                  // Comments
                  Text('Comments (${_comments.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Add comment
                  if (auth.isAuthenticated) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: () async {
                                  final file = await ImageSourcePicker.show(context);
                                  if (file != null) {
                                    setState(() => _commentImage = File(file.path));
                                  }
                                },
                              ),
                            ),
                            maxLines: 3,
                            minLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _isSubmittingComment
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send, color: Colors.orange),
                          onPressed: _isSubmittingComment ? null : _addComment,
                        ),
                      ],
                    ),
                    if (_commentImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_commentImage!, height: 80, width: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _commentImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  ..._comments.map((comment) => CommentTile(
                    comment: comment,
                    canDelete: auth.isAuthenticated &&
                        (auth.user?.id == comment.userId || auth.isAdmin),
                    onDelete: () => _deleteComment(comment.id),
                    onImageTap: comment.imageUrl != null
                        ? () => _showFullImage(context, comment.imageUrl!)
                        : null,
                  )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.orange),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: InteractiveViewer(
            child: UbexImage(imageUrl: imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }
}

// Cooking Mode full-screen
class _CookingModeScreen extends StatefulWidget {
  final List<String> steps;
  final String title;

  const _CookingModeScreen({required this.steps, required this.title});

  @override
  State<_CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<_CookingModeScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.steps.length;
    final progress = ((_currentStep + 1) / total);

    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.orange.shade100,
              color: Colors.orange,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text('Step ${_currentStep + 1} of $total', style: TextStyle(color: Colors.grey.shade600)),
            const Spacer(),
            Text(
              widget.steps[_currentStep],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, height: 1.5),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton(
                  onPressed: _currentStep > 0
                      ? () => setState(() => _currentStep--)
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade300),
                  child: const Text('Previous'),
                ),
                FilledButton(
                  onPressed: _currentStep < total - 1
                      ? () => setState(() => _currentStep++)
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text(_currentStep < total - 1 ? 'Next' : 'Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
