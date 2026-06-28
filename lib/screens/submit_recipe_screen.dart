import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/image_source_picker.dart';

class SubmitRecipeScreen extends StatefulWidget {
  const SubmitRecipeScreen({super.key});

  @override
  State<SubmitRecipeScreen> createState() => _SubmitRecipeScreenState();
}

class _SubmitRecipeScreenState extends State<SubmitRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController(text: '4');

  final List<TextEditingController> _ingredientControllers = [TextEditingController()];
  final List<TextEditingController> _stepControllers = [TextEditingController()];

  List<RecipeCategory> _categories = [];
  String? _selectedCategory;
  String _difficulty = 'medium';
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
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

  Future<void> _submit() async {
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

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step')),
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
        'image_url': _imageUrlController.text.trim(),
      };

      final response = await ApiService.submitRecipe(auth.token!, recipeData);

      if (response['success'] == true) {
        final recipeId = response['recipe_id'] ?? response['recipe']?['_id'];
        // Upload image if selected
        if (_imageFile != null && recipeId != null) {
          await ApiService.uploadRecipeImage(auth.token!, recipeId.toString(), _imageFile!.path);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe submitted for review!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Failed to submit recipe')),
          );
        }
      }
    } catch (e) {
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
      appBar: AppBar(title: const Text('Submit Recipe')),
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
                          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Add Photo', style: TextStyle(color: Colors.grey.shade500)),
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
            const SizedBox(height: 8),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Or paste image URL',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Category + Difficulty
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

            // Times + Servings
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prep (min)', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cook (min)', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Servings', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tags
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
                      child: TextFormField(
                        controller: c,
                        decoration: InputDecoration(
                          hintText: 'Ingredient ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_ingredientControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _ingredientControllers[i].dispose();
                            _ingredientControllers.removeAt(i);
                          });
                        },
                      ),
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
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.orange,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: c,
                        decoration: InputDecoration(
                          hintText: 'Step ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    if (_stepControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _stepControllers[i].dispose();
                            _stepControllers.removeAt(i);
                          });
                        },
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Submit button
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Recipe', style: TextStyle(fontSize: 16)),
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
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
