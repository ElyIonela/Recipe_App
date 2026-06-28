import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AiResultsScreen extends StatefulWidget {
  const AiResultsScreen({super.key});

  @override
  State<AiResultsScreen> createState() => _AiResultsScreenState();
}

class _AiResultsScreenState extends State<AiResultsScreen> {
  final _searchController = TextEditingController();
  final _speechService = SpeechService();
  List<Recipe> _results = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final response = await ApiService.searchRecipes(query.trim());
      if (response['success'] == true && response['recipes'] is List) {
        _results = (response['recipes'] as List)
            .map((r) => Recipe.fromJson(r))
            .toList();
      } else {
        _results = [];
      }
    } catch (_) {
      _results = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startVoiceSearch() async {
    setState(() => _isListening = true);
    await _speechService.startListening(
      onResult: (text) {
        _searchController.text = text;
        _search(text);
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  Future<void> _stopVoiceSearch() async {
    await _speechService.stopListening();
    setState(() => _isListening = false);
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
      appBar: AppBar(
        title: const Text('Search Recipes'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by ingredients, type, mood...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.orange,
                    size: 28,
                  ),
                  onPressed: _isListening ? _stopVoiceSearch : _startVoiceSearch,
                ),
              ],
            ),
          ),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Listening...',
                style: TextStyle(color: Colors.red.shade400, fontStyle: FontStyle.italic),
              ),
            ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Search for recipes using text or voice',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try "something light for dinner" or "pasta with tomatoes"',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(child: Text('No recipes found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final recipe = _results[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RecipeCard(
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
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
