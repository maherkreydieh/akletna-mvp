import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';
import '../../widgets/hearth_components.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/recipe_card.dart';
import 'create_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class MyRecipesScreen extends StatefulWidget {
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  const MyRecipesScreen({
    super.key,
    this.recipeService,
    this.authService,
    this.ingredientService,
  });
  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  late final _service = widget.recipeService ?? RecipeService();
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await _service.getMyRecipes();
      if (mounted) {
        setState(() => _recipes = recipes);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load your recipes. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          recipeService: _service,
          authService: widget.authService,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _create() async {
    final recipe = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(
          recipeService: _service,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (recipe == null || !mounted) {
      return;
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Recipe created.')));
      await _open(recipe);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Recipes'),
      actions: [
        IconButton(
          tooltip: 'Create Recipe',
          onPressed: _loading ? null : _create,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Refresh recipes',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  HearthPageIntro(
                    title: 'Your family recipe book',
                    subtitle: _error != null
                        ? 'Your recipe library could not be loaded.'
                        : '${_recipes.length} recipes in your kitchen. Manage private recipes and community contributions.',
                    icon: Icons.menu_book_outlined,
                  ),
                  if (_error != null) ...[
                    Text(_error!, textAlign: TextAlign.center),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Recipe'),
                    ),
                    const SizedBox(height: 16),
                    if (_recipes.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.edit_note, size: 40),
                              SizedBox(height: 12),
                              Text(
                                "You haven't created any recipes yet.",
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create your first recipe and it will appear here.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final recipe in _recipes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HearthBadge(
                              recipe.visibility == RecipeVisibility.public
                                  ? 'Public'
                                  : 'Private',
                            ),
                            const SizedBox(height: 6),
                            RecipeCard(
                              recipe: recipe,
                              onTap: () => _open(recipe),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
  );
}
