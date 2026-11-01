import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../widgets/recipe_card.dart';

class MealRecipePickerScreen extends StatefulWidget {
  final RecipeService recipeService;

  const MealRecipePickerScreen({super.key, required this.recipeService});

  @override
  State<MealRecipePickerScreen> createState() => _MealRecipePickerScreenState();
}

class _MealRecipePickerScreenState extends State<MealRecipePickerScreen> {
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await widget.recipeService.getAvailableRecipes();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Could not load your recipes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _recipes.where((recipe) {
      final query = _query.trim().toLowerCase();
      return recipe.name.toLowerCase().contains(query) ||
          recipe.description.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a recipe')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search your recipes',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRecipes,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _recipes.isEmpty
                              ? 'No recipes available yet. Add a recipe before planning a meal.'
                              : 'No recipes match your search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final recipe = filtered[index];
                        return RecipeCard(
                          recipe: recipe,
                          onTap: () => Navigator.pop(context, recipe),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
