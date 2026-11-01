import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class SavedRecipesScreen extends StatefulWidget {
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  const SavedRecipesScreen({
    super.key,
    this.recipeService,
    this.authService,
    this.ingredientService,
  });
  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
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
      final recipes = await _service.getSavedRecipes();
      if (mounted) setState(() => _recipes = recipes);
    } on ApiException catch (e) {
      if (!mounted) return;
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
          () => _error = 'Could not load saved recipes. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Saved Recipes'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                HearthPageIntro(
                  title: 'Saved for your table',
                  subtitle: _error != null
                      ? 'Your saved library could not be loaded.'
                      : '${_recipes.length} saved recipes. Open a recipe to cook, plan or update its bookmark.',
                  icon: Icons.bookmark_outline,
                ),
                ...(_error != null
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                        Center(
                          child: OutlinedButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ),
                      ]
                    : _recipes.isEmpty
                    ? const [
                        SizedBox(height: 64),
                        Icon(Icons.bookmark_border, size: 56),
                        SizedBox(height: 16),
                        Text(
                          'No saved recipes yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Save recipes from Recipes or Community to find them here.',
                          textAlign: TextAlign.center,
                        ),
                      ]
                    : _recipes
                          .map(
                            (recipe) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RecipeCard(
                                recipe: recipe,
                                onTap: () => _open(recipe),
                              ),
                            ),
                          )
                          .toList()),
              ],
            ),
          ),
  );
}
