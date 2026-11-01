
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe.dart';
import '../../models/meal_recipe_selection.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'create_recipe_screen.dart';
import '../../models/food_preferences.dart';
import '../../models/recipe_evaluation.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/recipe_spotlight.dart';
import 'saved_recipes_screen.dart';
import '../../widgets/kitchen_destinations.dart';
import '../../widgets/recipe_compatibility_view.dart';

class RecipeCatalogScreen extends StatefulWidget {
  final MealRecipeSelection? selection;
  final bool community;
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  final String initialQuery;
  final bool showFiltersInitially;
  const RecipeCatalogScreen({
    super.key,
    this.selection,
    this.community = false,
    this.recipeService,
    this.authService,
    this.ingredientService,
    this.initialQuery = '',
    this.showFiltersInitially = false,
  });

  @override
  State<RecipeCatalogScreen> createState() => _RecipeCatalogScreenState();
}

class _RecipeCatalogScreenState extends State<RecipeCatalogScreen> {
  late final RecipeService _recipeService =
      widget.recipeService ?? RecipeService();
  final TextEditingController _searchController = TextEditingController();

  late final ScrollController _scrollController = ScrollController(
    onAttach: (_) => _syncScrollVisibilityAfterLayout(),
  );
  void _syncScrollVisibilityAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  bool _showBackToTop = false;

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 400;
    if (show != _showBackToTop) setState(() => _showBackToTop = show);
  }

  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<MealGoal> _selectedGoals = {};
  DietaryPreference? _selectedDiet;
  late bool _community = widget.community;
  late bool _showFilters = widget.showFiltersInitially;
  Set<int>? _savedIds;
  final Set<int> _savingIds = {};
  int _requestId = 0;
  int _savedRevision = 0;
  bool? _wasActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = KitchenDestinations.maybeOf(context)?.selectedIndex == 1;
    if (active && _wasActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchRecipes();
      });
    }
    _wasActive = active;
  }

  void _clearFilters() => setState(() {
    _searchController.clear();
    _searchQuery = '';
    _selectedCategory = 'All';
    _selectedGoals.clear();
    _selectedDiet = null;
  });
  @override
  void didUpdateWidget(covariant RecipeCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.community != widget.community) {
      _community = widget.community;
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'All';
      _selectedGoals.clear();
      _selectedDiet = null;
      _fetchRecipes();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.text = widget.initialQuery;
    _searchQuery = widget.initialQuery.trim();
    _fetchRecipes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecipes() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recipes = widget.selection != null
          ? await _recipeService.getAvailableRecipes()
          : _community
          ? await _recipeService.getCommunityRecipes()
          : await _recipeService.getRecipes();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _recipes = recipes
            .where(
              (recipe) => widget.selection != null
                  ? true
                  : _community
                  ? recipe.origin == RecipeOrigin.user &&
                        recipe.visibility == RecipeVisibility.public
                  : recipe.origin == RecipeOrigin.curated &&
                        recipe.visibility == RecipeVisibility.public,
            )
            .toList();
        _isLoading = false;
        if (_selectedCategory != 'All' &&
            !_recipes.any(
              (r) =>
                  r.category.trim().toLowerCase() ==
                  _selectedCategory.toLowerCase(),
            )) {
          _selectedCategory = 'All';
        }
      });
      _loadSaved();
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      if (e.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _errorMessage = 'Could not load recipes. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openRecipe(Recipe recipe) async {
    final selected = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          selection: widget.selection,
          recipeService: _recipeService,
          authService: widget.authService,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (mounted && widget.selection != null && selected is Recipe) {
      Navigator.pop(context, selected);
      return;
    }
    if (mounted) {
      await _fetchRecipes();
    }
  }

  /// Standard categories shown on both Curated and Community tabs so the
  /// filter row looks the same whichever tab is open.
  static const _standardCategories = [
    'Mezze',
    'Salad',
    'Main Dish',
    'Soup',
    'Side Dish',
    'Yakhnet',
    'Breakfast',
  ];

  /// Standard categories first, then any other category found in the loaded
  /// recipes (for example a new category on a community recipe).
  List<String> get _availableCategories {
    final categoriesSet = <String>{..._standardCategories};
    for (final recipe in _recipes) {
      if (recipe.category.trim().isNotEmpty) {
        categoriesSet.add(recipe.category.trim());
      }
    }
    return ['All', ...categoriesSet];
  }

  /// Client-side filtering by name/description and category
  List<Recipe> get _filteredRecipes {
    return _recipes.where((recipe) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          recipe.category.trim().toLowerCase() ==
              _selectedCategory.toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty ||
          recipe.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recipe.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesGoals = _selectedGoals.every(
        (goal) => recipe.evaluation?.goals[goal] == GoalQualification.qualifies,
      );
      final matchesDiet =
          _selectedDiet == null ||
          recipe.evaluation?.diets[_selectedDiet] ==
              DietaryCompatibility.compatible;
      return matchesCategory && matchesSearch && matchesGoals && matchesDiet;
    }).toList();
  }

  Future<void> _loadSaved() async {
    if (_savingIds.isNotEmpty) return;
    final revision = ++_savedRevision;
    try {
      final saved = await _recipeService.getSavedRecipes();
      if (mounted && revision == _savedRevision) {
        setState(() => _savedIds = saved.map((r) => r.id).toSet());
      }
    } catch (e) {
      if (!mounted || revision != _savedRevision) return;
      if (e is ApiException && e.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        setState(() => _savedIds = null);
      }
    }
  }

  Future<void> _bookmark(Recipe recipe) async {
    if (_savedIds == null || _savingIds.contains(recipe.id)) return;
    setState(() {
      _savedRevision++;
      _savingIds.add(recipe.id);
    });
    final saved = _savedIds!.contains(recipe.id);
    try {
      if (saved) {
        await _recipeService.unsaveRecipe(recipe.id);
      } else {
        await _recipeService.saveRecipe(recipe.id);
      }
      if (mounted) {
        setState(() {
          if (saved) {
            _savedIds?.remove(recipe.id);
          } else {
            _savedIds?.add(recipe.id);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update saved recipe. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(recipe.id));
    }
  }

  Widget _bookmarkButton(Recipe recipe) => IconButton.filledTonal(
    tooltip: _savedIds == null
        ? 'Open recipe to check bookmark'
        : _savedIds!.contains(recipe.id)
        ? 'Unsave recipe'
        : 'Save recipe',
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .94),
    ),
    onPressed: _savingIds.contains(recipe.id)
        ? null
        : _savedIds == null
        ? () => _openRecipe(recipe)
        : () => _bookmark(recipe),
    icon: _savingIds.contains(recipe.id)
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            _savedIds?.contains(recipe.id) == true
                ? Icons.bookmark
                : _savedIds == null
                ? Icons.bookmark_add_outlined
                : Icons.bookmark_border,
            color: AppColors.primary,
          ),
  );
  Future<void> _createRecipe() async {
    final recipe = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(
          recipeService: _recipeService,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (recipe == null || !mounted) return;
    await _fetchRecipes();
    if (mounted) await _openRecipe(recipe);
  }

  @override
  Widget build(BuildContext context) {
    _syncScrollVisibilityAfterLayout();
    return _catalog(context);
  }

  Widget _catalog(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.selection == null
            ? 'Akletna اكلتنا'
            : 'Discover · Choose recipe',
      ),
      actions: [
        if (widget.selection == null)
          IconButton(
            tooltip: 'Saved Recipes',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SavedRecipesScreen(
                    recipeService: _recipeService,
                    authService: widget.authService,
                  ),
                ),
              );
              if (mounted) _loadSaved();
            },
          ),
        if (widget.selection == null)
          IconButton(
            tooltip: 'Create Recipe',
            onPressed: _createRecipe,
            icon: const Icon(Icons.add),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _fetchRecipes,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: _showBackToTop
        ? FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Back to top',
            onPressed: () => _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
            ),
            child: const Icon(Icons.arrow_upward),
          )
        : null,
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRecipes,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: _community
                            ? 'Search community recipes…'
                            : 'Search Lebanese recipes…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }),
                              ),
                            IconButton(
                              tooltip: 'Recipe filters',
                              icon: const Icon(Icons.tune),
                              onPressed: () =>
                                  setState(() => _showFilters = !_showFilters),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final category in _availableCategories)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: _selectedCategory == category,
                                selectedColor: AppColors.primaryDark,
                                labelStyle: TextStyle(
                                  color: _selectedCategory == category
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                onSelected: (_) => setState(
                                  () => _selectedCategory = category,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.selection != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.selection!.replacing == null
                              ? 'Choose ${widget.selection!.label}'
                              : 'Replace ${widget.selection!.replacing} · ${widget.selection!.label}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    if (widget.selection == null)
                      HearthTabs(
                        labels: const ['Curated Kitchen', 'Community Recipes'],
                        selected: _community ? 1 : 0,
                        onSelected: (index) {
                          if (_community == (index == 1)) return;
                          setState(() {
                            _community = index == 1;
                            _selectedCategory = 'All';
                          });
                          _fetchRecipes();
                        },
                      ),
                    if (_showFilters)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final goal in MealGoal.values)
                              FilterChip(
                                label: Text(goal.label),
                                selected: _selectedGoals.contains(goal),
                                onSelected: (s) => setState(() {
                                  s
                                      ? _selectedGoals.add(goal)
                                      : _selectedGoals.remove(goal);
                                }),
                              ),
                            for (final diet in DietaryPreference.values)
                              FilterChip(
                                label: Text(diet.label),
                                selected: _selectedDiet == diet,
                                onSelected: (s) => setState(
                                  () => _selectedDiet = s ? diet : null,
                                ),
                              ),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedGoals.isNotEmpty || _selectedDiet != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Filters show verified classifications only. Unverified recipes remain visible when filters are cleared.',
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear active filters'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!_isLoading && _errorMessage == null)
                      Text(
                        '${_filteredRecipes.length} recipes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_errorMessage != null)
              SliverToBoxAdapter(
                child: _state(_errorMessage!, 'Retry', _fetchRecipes),
              )
            else if (_recipes.isEmpty)
              SliverToBoxAdapter(
                child: _state(
                  widget.selection != null
                      ? 'No recipes available for planning'
                      : _community
                      ? 'No community recipes yet'
                      : 'No curated recipes yet',
                  'Refresh',
                  _fetchRecipes,
                ),
              )
            else if (_filteredRecipes.isEmpty)
              SliverToBoxAdapter(
                child: _state(
                  'No matching recipes',
                  'Reset Filters',
                  _clearFilters,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final recipe = _filteredRecipes[index];
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RecipeSpotlight(
                            insetTitle: true,
                            title: recipe.name,
                            description: recipe.description,
                            imageUrl: recipe.imageUrl,
                            badge: widget.selection != null
                                ? 'Available recipe'
                                : _community
                                ? 'Community'
                                : 'Curated Kitchen',
                            bookmark: _bookmarkButton(recipe),
                            metadata: [
                              if (recipe.cookingTime > 0)
                                '${recipe.cookingTime} min',
                              if ((recipe.servings ?? 0) > 0)
                                '${recipe.servings} servings',
                              if (recipe.category.isNotEmpty) recipe.category,
                            ],
                            onOpen: () => _openRecipe(recipe),
                          ),
                          RecipeCompatibilityView(
                            evaluation: recipe.evaluation,
                            compact: true,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _community
                                ? 'From home cooks'
                                : 'For your Lebanese table',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RecipeCard(
                        recipe: recipe,
                        imageAction: _bookmarkButton(recipe),
                        showOpenAction: true,
                        onTap: () => _openRecipe(recipe),
                      ),
                    );
                  }, childCount: _filteredRecipes.length),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _state(String message, String action, VoidCallback retry) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.restaurant_menu, size: 40, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (message == 'No community recipes yet')
          const Text(
            'Public recipes shared by the Akletna community will appear here.',
            textAlign: TextAlign.center,
          ),
        TextButton(onPressed: retry, child: Text(action)),
      ],
    ),
  );
}
