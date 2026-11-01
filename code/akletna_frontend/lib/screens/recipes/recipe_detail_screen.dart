
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe.dart';
import '../../models/meal_recipe_selection.dart';
import '../../widgets/recipe_image.dart';
import '../../widgets/recipe_nutrition_card.dart';
import '../../models/recipe_nutrition.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import 'create_recipe_screen.dart';
import '../../widgets/recipe_compatibility_view.dart';
import '../groceries/recipe_shortage_screen.dart';
import '../../services/grocery_list_service.dart';
import '../../services/meal_plan_service.dart';
import '../../widgets/hearth_components.dart';
import 'recipe_steps_view.dart';
import 'recipe_plan_sheet.dart';
import 'recipe_ingredients_view.dart';

class RecipeDetailScreen extends StatefulWidget {
  final MealRecipeSelection? selection;
  final Recipe recipe;
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  final GroceryListService? groceryListService;
  final MealPlanService? mealPlanService;

  const RecipeDetailScreen({
    super.key,
    this.selection,
    required this.recipe,
    this.recipeService,
    this.authService,
    this.ingredientService,
    this.groceryListService,
    this.mealPlanService,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeService _recipeService;

  late Recipe _recipe;
  bool _isLoadingDetails = false;
  String? _errorMessage;
  int? _currentUserId;
  bool _deleting = false;
  bool _returningSelection = false;
  void _selectForMeal() {
    if (_returningSelection || !_ready || !_hasServings || _saving) return;
    setState(() => _returningSelection = true);
    Navigator.pop(context, _recipe);
  }

  bool _saving = false;
  bool _saved = false;
  int _tab = 0;
  int? _servings;
  RecipeNutrition? _nutrition;
  int _nutritionRequest = 0;
  bool _nutritionLoading = true;
  bool _nutritionFailed = false;
  bool get _canManage =>
      !_isLoadingDetails &&
      _errorMessage == null &&
      _recipe.origin == RecipeOrigin.user &&
      _currentUserId != null &&
      _recipe.userId == _currentUserId;

  // Local UI state for ticking off ingredients while cooking
  final Set<int> _checkedIngredientIndices = {};

  @override
  void initState() {
    super.initState();
    _recipeService = widget.recipeService ?? RecipeService();
    _recipe = widget.recipe;

    _fetchFullRecipe();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await (widget.authService ?? AuthService()).getCurrentUser();
      if (mounted) setState(() => _currentUserId = user.id);
    } catch (_) {
      /* Unverified identity cannot manage recipes. */
    }
  }

  Future<void> _editRecipe() async {
    final saved = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(
          recipe: _recipe,
          recipeService: _recipeService,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (saved != null && mounted) {
      await _fetchFullRecipe();
      if (mounted && _errorMessage == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Recipe updated.')));
      }
    }
  }

  void _authenticationFailure() => Navigator.pushNamedAndRemoveUntil(
    context,
    AppConstants.loginRoute,
    (_) => false,
  );

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text('This will permanently delete this recipe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _recipeService.deleteRecipe(_recipe.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Recipe deleted.')));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _authenticationFailure();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _fetchFullRecipe() async {
    if (_saving) return;
    setState(() {
      _isLoadingDetails = true;
      _errorMessage = null;
    });

    try {
      final fullRecipe = await _recipeService.getRecipeById(_recipe.id);
      if (!mounted) return;
      setState(() {
        _recipe = fullRecipe;
        _saved = fullRecipe.saved;
        _servings = fullRecipe.servings;
        _checkedIngredientIndices.clear();
        _isLoadingDetails = false;
      });
      await _fetchNutrition();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _authenticationFailure();
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load complete recipe details.';
        _isLoadingDetails = false;
      });
    }
  }

  void _toggleIngredient(int index) {
    setState(() {
      if (_checkedIngredientIndices.contains(index)) {
        _checkedIngredientIndices.remove(index);
      } else {
        _checkedIngredientIndices.add(index);
      }
    });
  }

  Future<void> _toggleSaved() async {
    if (_saving || _isLoadingDetails || _deleting || _errorMessage != null) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_saved) {
        await _recipeService.unsaveRecipe(_recipe.id);
      } else {
        await _recipeService.saveRecipe(_recipe.id);
      }
      if (mounted) setState(() => _saved = !_saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _authenticationFailure();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update saved recipe. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addToPlan() async {
    if (_servings == null || _servings! <= 0) return;
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecipePlanSheet(
        recipeId: _recipe.id,
        servings: _servings!,
        service: widget.mealPlanService ?? MealPlanService(),
        onUnauthorized: _authenticationFailure,
      ),
    );
    if (mounted && added == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Meal added. Regenerate groceries to update your list.',
          ),
        ),
      );
    }
  }

  void _shortages() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeShortageScreen(
        recipeId: _recipe.id,
        recipeName: _recipe.name,
        initialServings: _servings!,
        service: widget.groceryListService,
      ),
    ),
  );

  bool get _ready => !_isLoadingDetails && _errorMessage == null && !_deleting;
  bool get _hasServings => (_servings ?? 0) > 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      forceMaterialTransparency: true,
      leading: IconButton.filledTonal(
        tooltip: 'Back',
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .94),
        ),
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .94),
          ),
          tooltip: _saved ? 'Unsave recipe' : 'Save recipe',
          onPressed: !_ready || _saving ? null : _toggleSaved,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
        ),
        if (_canManage) ...[
          IconButton.filledTonal(
            tooltip: 'Edit recipe',
            onPressed: _deleting || _saving ? null : _editRecipe,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton.filledTonal(
            tooltip: 'Delete recipe',
            onPressed: _deleting || _saving ? null : _deleteRecipe,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        const SizedBox(width: 12),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Ingredient checklist',
              onPressed: _ready ? () => setState(() => _tab = 1) : null,
              icon: const Icon(Icons.checklist_outlined),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _ready && _hasServings && !_saving && !_returningSelection
                    ? widget.selection == null
                          ? _addToPlan
                          : _selectForMeal
                    : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  widget.selection == null
                      ? 'Add to Meal Plan'
                      : 'Select for ${widget.selection!.label}',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _fetchFullRecipe,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RecipeImage(
                  url: _recipe.imageUrl,
                  recipeName: _recipe.name,
                  height: 320,
                ),
                PositionedDirectional(
                  bottom: 16,
                  start: 20,
                  end: 20,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HearthBadge(
                        _recipe.origin == RecipeOrigin.curated
                            ? 'Curated Kitchen'
                            : _recipe.visibility == RecipeVisibility.private
                            ? 'Private recipe'
                            : 'Community recipe',
                      ),
                      if (_recipe.category.trim().isNotEmpty)
                        HearthBadge(_recipe.category, spice: true),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipe.name,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 32, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'صحتين وهنا',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  HearthTabs(
                    labels: const ['Recipe', 'Ingredients', 'Steps'],
                    selected: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingDetails)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Could not load complete recipe details. Check your connection.',
                            ),
                            TextButton(
                              onPressed: _fetchFullRecipe,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_tab == 0) ...[
                    if (_recipe.description.trim().isNotEmpty) ...[
                      const HearthSection('About this Dish'),
                      const SizedBox(height: 12),
                      Text(
                        _recipe.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildMetadataRow(),
                    const SizedBox(height: 16),
                    _buildNutritionSection(),
                    const SizedBox(height: 16),
                    RecipeCompatibilityView(evaluation: _recipe.evaluation),
                    if (_hasServings)
                      OutlinedButton.icon(
                        onPressed: _shortages,
                        icon: const Icon(Icons.shopping_basket_outlined),
                        label: const Text('Check missing ingredients'),
                      ),
                  ] else if (_tab == 1) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HearthSection('Portions & Yield'),
                            const Text(
                              'Ingredient amounts scale with servings.',
                            ),
                            if (_hasServings)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease servings',
                                    onPressed: _servings! <= 1
                                        ? null
                                        : () => setState(() {
                                            _servings = _servings! - 1;
                                            _checkedIngredientIndices.clear();
                                          }),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Servings: $_servings',
                                      key: const ValueKey('recipe-servings'),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Increase servings',
                                    onPressed: _servings! >= 2147483647
                                        ? null
                                        : () => setState(() {
                                            _servings = _servings! + 1;
                                            _checkedIngredientIndices.clear();
                                          }),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              )
                            else
                              const Text('Serving information is unavailable.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_hasServings)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _shortages,
                          icon: const Icon(Icons.shopping_basket_outlined),
                          label: const Text('Check missing ingredients'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildIngredientsSection(),
                  ] else ...[
                    _buildMetadataRow(),
                    const SizedBox(height: 24),
                    RecipeStepsView(instructions: _recipe.instructions),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildMetadataRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Category Pill
        if (_recipe.category.trim().isNotEmpty)
          _buildPill(
            icon: Icons.category_outlined,
            text: _recipe.category.trim(),
            color: AppColors.primary,
          ),

        // Cooking Time Pill
        if (_recipe.cookingTime > 0)
          _buildPill(
            icon: Icons.timer_outlined,
            text: '${_recipe.cookingTime} mins',
            color: AppColors.secondary,
          ),

        // Servings Pill
        if ((_recipe.servings ?? 0) > 0)
          _buildPill(
            icon: Icons.people_outline,
            text:
                '${_recipe.servings} ${_recipe.servings == 1 ? "serving" : "servings"}',
            color: AppColors.secondary,
          ),
      ],
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() => RecipeIngredientsView(
    recipe: _recipe,
    servings: _servings,
    checkedIndices: _checkedIngredientIndices,
    onToggle: _toggleIngredient,
  );
  Future<void> _fetchNutrition() async {
    final request = ++_nutritionRequest;
    setState(() {
      _nutritionLoading = true;
      _nutritionFailed = false;
      _nutrition = null;
    });
    try {
      final value = await _recipeService.getNutrition(_recipe.id);
      if (mounted && request == _nutritionRequest) {
        setState(() => _nutrition = value);
      }
    } on ApiException catch (e) {
      if (!mounted || request != _nutritionRequest) return;
      if (e.statusCode == 401) {
        _authenticationFailure();
      } else {
        setState(() => _nutritionFailed = true);
      }
    } catch (_) {
      if (mounted && request == _nutritionRequest) {
        setState(() => _nutritionFailed = true);
      }
    } finally {
      if (mounted && request == _nutritionRequest) {
        setState(() => _nutritionLoading = false);
      }
    }
  }

  Widget _buildNutritionSection() => RecipeNutritionCard(
    nutrition: _nutrition,
    loading: _nutritionLoading,
    failed: _nutritionFailed,
    onRetry: _fetchNutrition,
    baseServings: _recipe.servings,
    selectedServings: _servings,
    ingredientNames: {
      for (final line in _recipe.ingredients) line.id: line.name,
    },
  );
}
