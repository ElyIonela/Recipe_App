import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://workflow.ubex.ai/api/v1';

  // Workflow endpoint IDs from documentation
  static const String _authRegister = 'NTp7L';
  static const String _authLogin = 'NTp7g';
  static const String _authChangePassword = 'NTp7R';
  static const String _authProfilePicture = 'NTp7u';
  static const String _authManageUsers = 'NTp7C';
  static const String _recipes = 'NTp70';
  static const String _categories = 'NTp7i';
  static const String _favorites = 'NTp7y';
  static const String _comments = 'NTp7V';
  static const String _ratings = 'NTp75';
  static const String _recipeImage = 'NTp72';
  static const String _recipeNutrition = 'NTp7K';

  static Future<Map<String, dynamic>> _post(
    String endpointId,
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl/$endpointId/$path');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
  }

  /// Normalize list responses: API returns {success, data: [...]}
  /// but app expects {success, <key>: [...]}
  static Map<String, dynamic> _normalizeList(Map<String, dynamic> response, String key) {
    if (response.containsKey('data') && !response.containsKey(key)) {
      response[key] = response['data'];
    }
    return response;
  }

  /// Normalize single-object responses: API returns {success, data: {...}}
  /// but app expects {success, <key>: {...}}
  static Map<String, dynamic> _normalizeSingle(Map<String, dynamic> response, String key) {
    if (response.containsKey('data') && !response.containsKey(key)) {
      response[key] = response['data'];
    }
    return response;
  }

  // ─── Auth ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    return _post(_authRegister, 'auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return _post(_authLogin, 'auth/login', {
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> changePassword(
    String token,
    String currentPassword,
    String newPassword,
  ) async {
    return _post(_authChangePassword, 'auth/change-password', {
      'token': token,
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  static Future<Map<String, dynamic>> getProfilePicture(
    String userId,
  ) async {
    return _post(_authProfilePicture, 'auth/profile-picture', {
      'action': 'get',
      'user_id': userId,
    });
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(
    String token,
    String filePath,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/$_authProfilePicture/auth/profile-picture',
    );
    final request = http.MultipartRequest('POST', url);
    request.fields['action'] = 'upload';
    request.fields['token'] = token;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─── Manage Users (Admin) ──────────────────────────────────────

  static Future<Map<String, dynamic>> listUsers(String token) async {
    final response = await _post(_authManageUsers, 'auth/manage-users', {
      'token': token,
      'action': 'list',
    });
    return _normalizeList(response, 'users');
  }

  static Future<Map<String, dynamic>> changeUserRole(
    String token,
    String userId,
    String newRole,
  ) async {
    return _post(_authManageUsers, 'auth/manage-users', {
      'token': token,
      'action': 'change_role',
      'user_id': userId,
      'new_role': newRole,
    });
  }

  static Future<Map<String, dynamic>> deleteUser(
    String token,
    String userId,
  ) async {
    return _post(_authManageUsers, 'auth/manage-users', {
      'token': token,
      'action': 'delete',
      'user_id': userId,
    });
  }

  // ─── Recipes ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listRecipes({String? category}) async {
    final body = <String, dynamic>{'action': 'list'};
    if (category != null) body['category'] = category;
    final response = await _post(_recipes, 'recipes', body);
    return _normalizeList(response, 'recipes');
  }

  static Future<Map<String, dynamic>> getRecipe(String recipeId) async {
    final response = await _post(_recipes, 'recipes', {
      'action': 'get',
      'recipe_id': recipeId,
    });
    return _normalizeSingle(response, 'recipe');
  }

  static Future<Map<String, dynamic>> searchRecipes(String query) async {
    final response = await _post(_recipes, 'recipes', {
      'action': 'search',
      'query': query,
    });
    return _normalizeList(response, 'recipes');
  }

  static Future<Map<String, dynamic>> randomRecipe() async {
    final response = await _post(_recipes, 'recipes', {'action': 'random'});
    return _normalizeSingle(response, 'recipe');
  }

  static Future<Map<String, dynamic>> submitRecipe(
    String token,
    Map<String, dynamic> recipeData,
  ) async {
    final body = <String, dynamic>{
      'action': 'submit',
      'token': token,
      ...recipeData,
    };
    final response = await _post(_recipes, 'recipes', body);
    // Normalize: recipe_id might be in 'data'
    if (response['data'] != null && response['recipe_id'] == null) {
      final data = response['data'];
      if (data is Map) {
        response['recipe_id'] = data['_id'] ?? data['id'];
        response['recipe'] = data;
      }
    }
    return response;
  }

  static Future<Map<String, dynamic>> myRecipes(String token) async {
    final response = await _post(_recipes, 'recipes', {
      'action': 'my_recipes',
      'token': token,
    });
    return _normalizeList(response, 'recipes');
  }

  static Future<Map<String, dynamic>> pendingRecipes(String token) async {
    final response = await _post(_recipes, 'recipes', {
      'action': 'pending',
      'token': token,
    });
    return _normalizeList(response, 'recipes');
  }

  static Future<Map<String, dynamic>> approveRecipe(
    String token,
    String recipeId,
  ) async {
    return _post(_recipes, 'recipes', {
      'action': 'approve',
      'token': token,
      'recipe_id': recipeId,
    });
  }

  static Future<Map<String, dynamic>> rejectRecipe(
    String token,
    String recipeId,
    String reason,
  ) async {
    return _post(_recipes, 'recipes', {
      'action': 'reject',
      'token': token,
      'recipe_id': recipeId,
      'rejection_reason': reason,
    });
  }

  static Future<Map<String, dynamic>> editRecipe(
    String token,
    String recipeId,
    Map<String, dynamic> recipeData,
  ) async {
    final body = <String, dynamic>{
      'action': 'edit',
      'token': token,
      'recipe_id': recipeId,
      ...recipeData,
    };
    return _post(_recipes, 'recipes', body);
  }

  static Future<Map<String, dynamic>> editOwnRecipe(
    String token,
    String recipeId,
    Map<String, dynamic> recipeData,
  ) async {
    final body = <String, dynamic>{
      'action': 'edit_own',
      'token': token,
      'recipe_id': recipeId,
      ...recipeData,
    };
    return _post(_recipes, 'recipes', body);
  }

  static Future<Map<String, dynamic>> deleteRecipe(
    String token,
    String recipeId,
  ) async {
    return _post(_recipes, 'recipes', {
      'action': 'delete',
      'token': token,
      'recipe_id': recipeId,
    });
  }

  static Future<Map<String, dynamic>> deleteOwnRecipe(
    String token,
    String recipeId,
  ) async {
    return _post(_recipes, 'recipes', {
      'action': 'delete_own',
      'token': token,
      'recipe_id': recipeId,
    });
  }

  // ─── Categories ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listCategories() async {
    final response = await _post(_categories, 'categories', {'action': 'list'});
    return _normalizeList(response, 'categories');
  }

  static Future<Map<String, dynamic>> addCategory(
    String token,
    String name,
    String icon,
    int sortOrder,
  ) async {
    return _post(_categories, 'categories', {
      'action': 'add',
      'token': token,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    });
  }

  static Future<Map<String, dynamic>> editCategory(
    String token,
    String categoryId,
    String name,
    String icon,
    int sortOrder,
  ) async {
    return _post(_categories, 'categories', {
      'action': 'edit',
      'token': token,
      'category_id': categoryId,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    });
  }

  static Future<Map<String, dynamic>> deleteCategory(
    String token,
    String categoryId,
  ) async {
    return _post(_categories, 'categories', {
      'action': 'delete',
      'token': token,
      'category_id': categoryId,
    });
  }

  // ─── Favorites ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> addFavorite(
    String token,
    String recipeId,
  ) async {
    return _post(_favorites, 'favorites', {
      'action': 'add',
      'token': token,
      'recipe_id': recipeId,
    });
  }

  static Future<Map<String, dynamic>> removeFavorite(
    String token,
    String recipeId,
  ) async {
    return _post(_favorites, 'favorites', {
      'action': 'remove',
      'token': token,
      'recipe_id': recipeId,
    });
  }

  static Future<Map<String, dynamic>> listFavorites(String token) async {
    final response = await _post(_favorites, 'favorites', {
      'action': 'list',
      'token': token,
    });
    return _normalizeList(response, 'favorites');
  }

  // ─── Comments ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> addComment(
    String token,
    String recipeId,
    String text, {
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{
      'action': 'add',
      'token': token,
      'recipe_id': recipeId,
      'text': text,
    };
    if (imageUrl != null) body['image_url'] = imageUrl;
    return _post(_comments, 'comments', body);
  }

  static Future<Map<String, dynamic>> listComments(String recipeId) async {
    final response = await _post(_comments, 'comments', {
      'action': 'list',
      'recipe_id': recipeId,
    });
    return _normalizeList(response, 'comments');
  }

  static Future<Map<String, dynamic>> deleteComment(
    String token,
    String commentId,
  ) async {
    return _post(_comments, 'comments', {
      'action': 'delete',
      'token': token,
      'comment_id': commentId,
    });
  }

  // ─── Ratings ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> rateRecipe(
    String token,
    String recipeId,
    int rating,
  ) async {
    return _post(_ratings, 'ratings', {
      'action': 'rate',
      'token': token,
      'recipe_id': recipeId,
      'rating': rating,
    });
  }

  static Future<Map<String, dynamic>> getMyRating(
    String token,
    String recipeId,
  ) async {
    final response = await _post(_ratings, 'ratings', {
      'action': 'get_my_rating',
      'token': token,
      'recipe_id': recipeId,
    });
    // Normalize: rating value might be in 'data'
    if (response['data'] != null && response['rating'] == null) {
      final data = response['data'];
      if (data is Map && data['rating'] != null) {
        response['rating'] = data['rating'];
      } else if (data is int || data is double) {
        response['rating'] = data;
      }
    }
    return response;
  }

  // ─── Recipe Image ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRecipeImage(
    String imagePath,
  ) async {
    return _post(_recipeImage, 'recipe-image', {
      'action': 'get',
      'image_path': imagePath,
    });
  }

  static Future<Map<String, dynamic>> uploadRecipeImage(
    String token,
    String recipeId,
    String filePath,
  ) async {
    final url = Uri.parse('$_baseUrl/$_recipeImage/recipe-image');
    final request = http.MultipartRequest('POST', url);
    request.fields['action'] = 'upload';
    request.fields['token'] = token;
    request.fields['recipe_id'] = recipeId;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─── Nutrition ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNutrition(
    String title,
    String ingredients,
    int servings,
  ) async {
    final response = await _post(_recipeNutrition, 'recipe-nutrition', {
      'title': title,
      'ingredients': ingredients,
      'servings': servings,
    });
    // Normalize: the response text might be in 'data', 'result', or 'response'
    if (response['data'] != null && response['result'] == null && response['response'] == null) {
      response['result'] = response['data'];
    }
    return response;
  }
}
