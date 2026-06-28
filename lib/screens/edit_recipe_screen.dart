import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/image_source_picker.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _servingsController;

  late List<TextEditingController> _ingredientControllers;
  late List<TextEditingController> _stepControllers;

  List<RecipeCategory> _categories = [];
  String? _selectedCategory;
  late String _difficulty;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleController = TextEditingController(text: r.title);
    _descriptionController = TextEditingController(text: r.description);
    _tagsController = TextEditingController(text: r.tags);
    _prepTimeController = TextEditingController(text: r.prepTime.toString());
    _cookTimeController = TextEditingController(text: r.cookTime.toString());
    _servingsController = TextEditingController(text: r.servings.toString());
    _selectedCategory = r.category.isNotEmpty ? r.category : null;
    _difficulty = r.difficulty;

    _ingredientControllers = r.ingredients.isNotEmpty
        ? r.ingredients.map((i) => TextEditingController(text: i['name'] ?? i.toString())).toList()
        : [TextEditingController()];

    _stepControllers = r.steps.isNotEmpty
        ? r.steps.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];

    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (final c in _ingredientControllers) { c.dispose(); }
    for (final c in _stepControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.listCategories();
      if (response['success'] == true && response['categories'] is List) {
        setState(() {
          _categories = (response['categories'] as List)
              .map((c) => RecipeCategory.fromJson(c))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;

    final ingredients = _ingredientControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => {'name': c.text.trim()})
        .toList();

    final steps = _stepControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    if (ingredients.isEmpty || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add ingredients and steps')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final recipeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ingredients': ingredients,
        'steps': steps,
        'category': _selectedCategory ?? '',
        'difficulty': _difficulty,
        'prep_time': int.tryParse(_prepTimeController.text) ?? 0,
        'cook_time': int.tryParse(_cookTimeController.text) ?? 0,
        'servings': int.tryParse(_servingsController.text) ?? 4,
        'tags': _tagsController.text.trim(),
      };

      Map<String, dynamic> response;
      if (auth.isAdmin) {
        response = await ApiService.editRecipe(auth.token!, widget.recipe.id, recipeData);
      } else {
        response = await ApiService.editOwnRecipe(auth.token!, widget.recipe.id, recipeData);
      }

      if (response['success'] == true) {
        // Upload new image if selected
        if (_imageFile != null) {
          await ApiService.uploadRecipeImage(auth.token!, widget.recipe.id, _imageFile!.path);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe updated!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Failed to update')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image
            GestureDetector(
              onTap: () async {
                final file = await ImageSourcePicker.show(context);
                if (file != null) setState(() => _imageFile = File(file.path));
              },
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  image: _imageFile != null
                      ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Change Photo', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () => setState(() => _imageFile = null),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                    items: _categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: TextFormField(controller: _prepTimeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prep (min)', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _cookTimeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cook (min)', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _servingsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Servings', border: OutlineInputBorder(), isDense: true))),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Tags (comma separated)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // Ingredients
            _buildSectionHeader('Ingredients', onAdd: () {
              setState(() => _ingredientControllers.add(TextEditingController()));
            }),
            ..._ingredientControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(controller: c, decoration: InputDecoration(hintText: 'Ingredient ${i + 1}', border: const OutlineInputBorder(), isDense: true)),
                    ),
                    if (_ingredientControllers.length > 1)
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () {
                        setState(() { _ingredientControllers[i].dispose(); _ingredientControllers.removeAt(i); });
                      }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Steps
            _buildSectionHeader('Steps', onAdd: () {
              setState(() => _stepControllers.add(TextEditingController()));
            }),
            ..._stepControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: Colors.orange, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: c, decoration: InputDecoration(hintText: 'Step ${i + 1}', border: const OutlineInputBorder(), isDense: true), maxLines: 3, minLines: 1)),
                    if (_stepControllers.length > 1)
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () {
                        setState(() { _stepControllers[i].dispose(); _stepControllers.removeAt(i); });
                      }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onAdd}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
      ],
    );
  }
}
