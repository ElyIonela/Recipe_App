import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/image_source_picker.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_users_screen.dart';
import 'manage_recipes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _recipesCount = 0;
  int _favoritesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    setState(() {});
    try {
      final results = await Future.wait([
        ApiService.myRecipes(auth.token!),
        ApiService.listFavorites(auth.token!),
      ]);

      final recipesResponse = results[0];
      final favoritesResponse = results[1];

      if (recipesResponse['success'] == true && recipesResponse['recipes'] is List) {
        _recipesCount = (recipesResponse['recipes'] as List).length;
      }
      if (favoritesResponse['success'] == true && favoritesResponse['favorites'] is List) {
        _favoritesCount = (favoritesResponse['favorites'] as List).length;
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _changeAvatar() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    final file = await ImageSourcePicker.show(context);
    if (file == null) return;

    try {
      final response = await ApiService.uploadProfilePicture(auth.token!, file.path);
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
        setState(() {}); // Refresh avatar
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload picture')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('Login to access your profile'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _changeAvatar,
                child: Stack(
                  children: [
                    UserAvatar(userId: user.id, userName: user.name, radius: 50),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name & email
            Center(
              child: Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Center(
              child: Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.isAdmin ? 'Admin' : 'Member',
                  style: TextStyle(
                    color: user.isAdmin ? Colors.purple : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _statCard('Recipes', _recipesCount, Icons.menu_book),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('Favorites', _favoritesCount, Icons.favorite),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Settings
            const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            _settingsTile(
              Icons.lock_outline,
              'Change Password',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),

            if (auth.isAdmin) ...[
              _settingsTile(
                Icons.category_outlined,
                'Manage Categories',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen())),
              ),
              _settingsTile(
                Icons.people_outline,
                'Manage Users',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
              ),
              _settingsTile(
                Icons.restaurant_menu,
                'Manage Recipes',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRecipesScreen())),
              ),
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            const SizedBox(height: 8),
            Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
