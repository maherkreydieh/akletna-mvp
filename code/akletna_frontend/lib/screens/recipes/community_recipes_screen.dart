import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../services/recipe_service.dart';
import 'recipe_catalog_screen.dart';

/// Shares the catalog's cards, search, loading, retry and detail navigation.
class CommunityRecipesScreen extends StatelessWidget {
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  const CommunityRecipesScreen({
    super.key,
    this.recipeService,
    this.authService,
    this.ingredientService,
  });
  @override
  Widget build(BuildContext context) => RecipeCatalogScreen(
    community: true,
    recipeService: recipeService,
    authService: authService,
    ingredientService: ingredientService,
  );
}
