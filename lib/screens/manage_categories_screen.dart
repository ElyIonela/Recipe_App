import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<RecipeCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.listCategories();
      if (response['success'] == true && response['categories'] is List) {
        _categories = (response['categories'] as List)
            .map((c) => RecipeCategory.fromJson(c))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addCategory() async {
    final result = await _showCategoryDialog();
    if (result == null) return;

    final auth = context.read<AuthService>();
    try {
      final response = await ApiService.addCategory(
        auth.token!, result['name'], result['icon'], result['sort_order'],
      );
      if (response['success'] == true) _loadCategories();
    } catch (_) {}
  }

  Future<void> _editCategory(RecipeCategory category) async {
    final result = await _showCategoryDialog(
      name: category.name,
      icon: category.icon,
      sortOrder: category.sortOrder,
    );
    if (result == null) return;

    final auth = context.read<AuthService>();
    try {
      final response = await ApiService.editCategory(
        auth.token!, category.id, result['name'], result['icon'], result['sort_order'],
      );
      if (response['success'] == true) _loadCategories();
    } catch (_) {}
  }

  Future<void> _deleteCategory(RecipeCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final auth = context.read<AuthService>();
    try {
      final response = await ApiService.deleteCategory(auth.token!, category.id);
      if (response['success'] == true) _loadCategories();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _showCategoryDialog({
    String? name,
    String? icon,
    int? sortOrder,
  }) async {
    final nameController = TextEditingController(text: name ?? '');
    String selectedIcon = icon ?? 'restaurant';
    final sortController = TextEditingController(text: (sortOrder ?? _categories.length).toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(name == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort Order', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  width: 300,
                  child: GridView.count(
                    crossAxisCount: 5,
                    children: _availableIcons.map((iconName) {
                      final isUsed = _categories.any((c) => c.icon == iconName && c.icon != icon);
                      final isSelected = selectedIcon == iconName;
                      return GestureDetector(
                        onTap: isUsed ? null : () {
                          setDialogState(() => selectedIcon = iconName);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange.shade100 : null,
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color: isUsed ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'name': nameController.text.trim(),
                  'icon': selectedIcon,
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    sortController.dispose();
    return result;
  }

  static const List<String> _availableIcons = [
    'free_breakfast', 'lunch_dining', 'dinner_dining', 'icecream', 'cookie',
    'local_pizza', 'ramen_dining', 'bakery_dining', 'set_meal', 'restaurant',
    'emoji_food_beverage', 'local_cafe', 'cake', 'liquor', 'local_bar',
    'rice_bowl', 'kebab_dining', 'soup_kitchen', 'tapas', 'brunch_dining',
  ];

  static IconData _getIconData(String name) {
    switch (name) {
      case 'free_breakfast': return Icons.free_breakfast;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'icecream': return Icons.icecream;
      case 'cookie': return Icons.cookie;
      case 'local_pizza': return Icons.local_pizza;
      case 'ramen_dining': return Icons.ramen_dining;
      case 'bakery_dining': return Icons.bakery_dining;
      case 'set_meal': return Icons.set_meal;
      case 'restaurant': return Icons.restaurant;
      case 'emoji_food_beverage': return Icons.emoji_food_beverage;
      case 'local_cafe': return Icons.local_cafe;
      case 'cake': return Icons.cake;
      case 'liquor': return Icons.liquor;
      case 'local_bar': return Icons.local_bar;
      case 'rice_bowl': return Icons.rice_bowl;
      case 'kebab_dining': return Icons.kebab_dining;
      case 'soup_kitchen': return Icons.soup_kitchen;
      case 'tapas': return Icons.tapas;
      case 'brunch_dining': return Icons.brunch_dining;
      default: return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addCategory),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _categories.isEmpty
              ? const Center(child: Text('No categories yet'))
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ListTile(
                        leading: Icon(_getIconData(category.icon), color: Colors.orange),
                        title: Text(category.name),
                        subtitle: Text('Order: ${category.sortOrder}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editCategory(category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _deleteCategory(category),
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
