import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/ai_results_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/my_favorites_screen.dart';
import 'screens/admin_review_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/submit_recipe_screen.dart';

void main() {
  runApp(const RecipeApp());
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..init(),
      child: MaterialApp(
        title: 'Recipe App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.orange,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
          ),
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _pollPendingCount);
  }

  Future<void> _pollPendingCount() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (auth.isAdmin && auth.token != null) {
      try {
        final response = await ApiService.pendingRecipes(auth.token!);
        if (response['success'] == true && response['recipes'] is List) {
          if (mounted) {
            setState(() => _pendingCount = (response['recipes'] as List).length);
          }
        }
      } catch (_) {}
    }
    // Poll every 5 minutes
    if (mounted) {
      Future.delayed(const Duration(minutes: 5), _pollPendingCount);
    }
  }

  List<Widget> _buildScreens(AuthService auth) {
    if (auth.isAdmin) {
      return const [
        HomeScreen(),
        AiResultsScreen(),
        MyRecipesScreen(),
        MyFavoritesScreen(),
        AdminReviewScreen(),
        ProfileScreen(),
      ];
    } else if (auth.isAuthenticated) {
      return const [
        HomeScreen(),
        AiResultsScreen(),
        MyRecipesScreen(),
        MyFavoritesScreen(),
        ProfileScreen(),
      ];
    } else {
      return const [
        HomeScreen(),
        AiResultsScreen(),
        ProfileScreen(),
      ];
    }
  }

  List<NavigationDestination> _buildDestinations(AuthService auth) {
    if (auth.isAdmin) {
      return [
        const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        const NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
        const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'My Recipes'),
        const NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _pendingCount > 0,
            label: Text('$_pendingCount'),
            child: const Icon(Icons.rate_review_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: _pendingCount > 0,
            label: Text('$_pendingCount'),
            child: const Icon(Icons.rate_review),
          ),
          label: 'Review',
        ),
        const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (auth.isAuthenticated) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'My Recipes'),
        NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final screens = _buildScreens(auth);
    final destinations = _buildDestinations(auth);

    // Clamp index if tabs changed
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: destinations,
      ),
      floatingActionButton: auth.isAuthenticated
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitRecipeScreen()),
                );
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
