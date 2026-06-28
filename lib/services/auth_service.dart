import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  Set<String> _favoriteIds = {};
  bool _initialized = false;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isInitialized => _initialized;
  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String recipeId) => _favoriteIds.contains(recipeId);

  /// Initialize auth state from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    final userJson = prefs.getString('user_data');

    if (_token != null && userJson != null) {
      try {
        _user = User.fromJson(jsonDecode(userJson));
        await _loadFavorites();
      } catch (_) {
        await _clearStorage();
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Login and store credentials
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiService.login(email, password);
    if (response['success'] == true) {
      _token = response['token'];
      _user = User.fromJson(response['user']);
      await _saveToStorage();
      await _loadFavorites();
      notifyListeners();
    }
    return response;
  }

  /// Register and store credentials
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await ApiService.register(name, email, password);
    if (response['success'] == true) {
      _token = response['token'];
      _user = User.fromJson(response['user']);
      await _saveToStorage();
      await _loadFavorites();
      notifyListeners();
    }
    return response;
  }

  /// Logout and clear state
  Future<void> logout() async {
    _user = null;
    _token = null;
    _favoriteIds = {};
    await _clearStorage();
    notifyListeners();
  }

  /// Add recipe to favorites (optimistic)
  Future<bool> addFavorite(String recipeId) async {
    if (_token == null) return false;
    _favoriteIds.add(recipeId);
    notifyListeners();

    final response = await ApiService.addFavorite(_token!, recipeId);
    if (response['success'] != true) {
      _favoriteIds.remove(recipeId);
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Remove recipe from favorites (optimistic)
  Future<bool> removeFavorite(String recipeId) async {
    if (_token == null) return false;
    _favoriteIds.remove(recipeId);
    notifyListeners();

    final response = await ApiService.removeFavorite(_token!, recipeId);
    if (response['success'] != true) {
      _favoriteIds.add(recipeId);
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String recipeId) async {
    if (isFavorite(recipeId)) {
      return removeFavorite(recipeId);
    } else {
      return addFavorite(recipeId);
    }
  }

  /// Load favorites from API
  Future<void> _loadFavorites() async {
    if (_token == null) return;
    try {
      final response = await ApiService.listFavorites(_token!);
      if (response['success'] == true && response['favorites'] is List) {
        _favoriteIds = (response['favorites'] as List)
            .map((f) => f['recipe_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      // Silently fail - favorites will just be empty
    }
  }

  /// Reload favorites (public method for pull-to-refresh)
  Future<void> reloadFavorites() async {
    await _loadFavorites();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) prefs.setString('jwt_token', _token!);
    if (_user != null) {
      prefs.setString('user_data', jsonEncode(_user!.toJson()));
    }
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('jwt_token');
    prefs.remove('user_data');
  }
}
