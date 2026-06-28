import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Recipe> _allRecipes = [];
  List<Recipe> _displayedRecipes = [];
  List<RecipeCategory> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  int _displayCount = 10;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.listRecipes(),
        ApiService.listCategories(),
      ]);

      final recipesResponse = results[0];
      final categoriesResponse = results[1];

      if (recipesResponse['success'] == true && recipesResponse['recipes'] is List) {
        _allRecipes = (recipesResponse['recipes'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList();
      }

      if (categoriesResponse['success'] == true &&
          categoriesResponse['categories'] is List) {
        _categories = (categoriesResponse['categories'] as List)
            .map((c) => RecipeCategory.fromJson(c))
            .toList();
      }

      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load recipes')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var filtered = _allRecipes.toList();

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((r) => r.category.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q) ||
            r.category.toLowerCase().contains(q) ||
            r.tags.toLowerCase().contains(q);
      }).toList();
    }

    _displayCount = 10;
    _displayedRecipes = filtered.take(_displayCount).toList();
    setState(() {});
  }

  void _loadMore() {
    var filtered = _allRecipes.toList();
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((r) => r.category.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q) ||
            r.category.toLowerCase().contains(q) ||
            r.tags.toLowerCase().contains(q);
      }).toList();
    }

    if (_displayCount < filtered.length) {
      setState(() {
        _displayCount += 10;
        _displayedRecipes = filtered.take(_displayCount).toList();
      });
    }
  }

  Future<void> _surpriseMe() async {
    try {
      final response = await ApiService.randomRecipe();
      if (!mounted) return;
      if (response['success'] == true && response['recipe'] != null) {
        final recipe = Recipe.fromJson(response['recipe']);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load random recipe')),
        );
      }
    }
  }

  void _onFavoriteTap(Recipe recipe) {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(pendingFavoriteRecipeId: recipe.id),
        ),
      );
      return;
    }
    auth.toggleFavorite(recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              title: const Text('Recipe App'),
              actions: [
                TextButton.icon(
                  onPressed: _surpriseMe,
                  icon: const Icon(Icons.casino, color: Colors.orange),
                  label: const Text('Surprise Me!',
                      style: TextStyle(color: Colors.orange)),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ),

            // Category filter
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildCategoryChip(null, 'All'),
                    ..._categories.map(
                      (c) => _buildCategoryChip(c.name, c.name),
                    ),
                  ],
                ),
              ),
            ),

            // Recipe grid
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Colors.orange)),
              )
            else if (_displayedRecipes.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No recipes found', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _displayedRecipes.length) return null;
                      final recipe = _displayedRecipes[index];
                      return RecipeCard(
                        recipe: recipe,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
                            ),
                          ).then((_) => _loadData());
                        },
                        onFavoriteTap: () => _onFavoriteTap(recipe),
                      );
                    },
                    childCount: _displayedRecipes.length,
                  ),
                ),
              ),

            // Loading indicator at bottom
            if (!_isLoading && _displayedRecipes.length < _allRecipes.length)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategory = value);
          _applyFilters();
        },
        selectedColor: Colors.orange.shade100,
        checkmarkColor: Colors.orange,
      ),
    );
  }
}
