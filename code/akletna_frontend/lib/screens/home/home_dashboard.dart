import 'package:flutter/material.dart';

import '../../widgets/weekday_strip.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/grocery_list.dart';
import '../../models/meal_plan.dart';
import '../../models/pantry_matches.dart';
import '../../models/recipe.dart';
import '../../models/recommendations.dart';
import '../../services/recommendation_service.dart';
import '../../services/auth_service.dart';
import '../../services/grocery_list_service.dart';
import '../../services/meal_plan_service.dart';
import '../../services/pantry_matching_service.dart';
import '../../services/recipe_service.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/recipe_spotlight.dart';
import '../recipes/recipe_detail_screen.dart';

/// Independent requests keep one unavailable module from hiding the kitchen.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.openPlanner,
    required this.openGroceries,
    required this.openPantryMatches,
    required this.openDiscover,
    required this.openPreferences,
    required this.recommendationService,
    required this.recipeService,
    required this.mealPlanService,
    required this.groceryService,
    required this.matchingService,
    required this.authService,
    required this.refreshToken,
    required this.selectedDate,
    required this.onDateSelected,
  });
  final ValueChanged<DateTime> openPlanner;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback openGroceries,
      openPantryMatches,
      openDiscover,
      openPreferences;
  final RecommendationService recommendationService;
  final RecipeService recipeService;
  final MealPlanService mealPlanService;
  final GroceryListService groceryService;
  final PantryMatchingService matchingService;
  final AuthService authService;
  final int refreshToken;
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late Future<List<MealPlan>> _plans;
  late Future<GroceryList> _groceries;
  late Future<PantryMatches> _matches;
  late Future<HomeRecommendations> _recommendations;
  late DateTime _selected = mealPlanDay(widget.selectedDate);
  bool _redirected = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _selected = mealPlanDay(widget.selectedDate);
    }
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401 && mounted && !_redirected) {
        _redirected = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      }
      rethrow;
    }
  }

  void _load() {
    _plans = _guard(() => widget.mealPlanService.getWeek(_selected));
    _groceries = _guard(widget.groceryService.getList);
    _matches = _guard(widget.matchingService.getMatches);
    _recommendations = _guard(
      widget.recommendationService.getHomeRecommendations,
    );
  }

  Widget _request<T>(
    Future<T> future,
    Widget Function(T) builder,
    VoidCallback retry,
  ) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Row(
          children: [
            const Expanded(child: Text('Unavailable. Check your connection.')),
            TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        );
      }
      return builder(snapshot.requireData);
    },
  );
  Future<void> _detail(Recipe recipe) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          recipeService: widget.recipeService,
          authService: widget.authService,
          groceryListService: widget.groceryService,
          mealPlanService: widget.mealPlanService,
        ),
      ),
    );
    if (mounted) setState(_load);
  }

  Future<void> _toggle(GroceryItem item) async {
    setState(() => _toggling = true);
    try {
      await _guard(() => widget.groceryService.toggleItem(item.id));
    } catch (_) {
      if (mounted && !_redirected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not confirm the update. Refresh your grocery list.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _toggling = false;
          _groceries = _guard(widget.groceryService.getList);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HearthSection(
        'Recommended for You',
        action: 'See all',
        onAction: widget.openDiscover,
      ),
      const SizedBox(height: 12),
      _request(
        _recommendations,
        (result) {
          final seen = <int>{};
          final recipes = result.selection.items
              .map((item) => item.recipe)
              .where((recipe) => seen.add(recipe.id))
              .toList();
          // Intrinsic horizontal sizing lets descriptions and enlarged text grow.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipes.isEmpty)
                TextButton(
                  onPressed: widget.openPreferences,
                  child: Text(
                    result.preferencesConfigured
                        ? 'Review Food Preferences'
                        : 'Set Food Preferences',
                  ),
                ),
              if (recipes.isEmpty)
                for (final limitation in result.limitations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      limitation,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              if (recipes.isEmpty)
                Text(
                  result.preferencesConfigured
                      ? 'No recipes meet your saved preferences with the available information. Review Food Preferences or try again as recipe information improves.'
                      : 'No recipes with complete ingredient requirements are available yet.',
                ),
              if (recipes.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final recipe in recipes.take(8))
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width < 360
                                  ? 240
                                  : 260,
                              child: RecipeCard(
                                recipe: recipe,
                                showEvaluation: false,
                                onTap: () => _detail(recipe),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (recipes.isNotEmpty && !result.preferencesConfigured)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('General recipe selection'),
                ),
            ],
          );
        },
        () => setState(() {
          _recommendations = _guard(
            widget.recommendationService.getHomeRecommendations,
          );
        }),
      ),
      const SizedBox(height: 24),
      HearthSection(
        "This Week's Table",
        action: 'Full plan',
        onAction: () => widget.openPlanner(_selected),
      ),
      _request(
        _plans,
        _week,
        () => setState(() {
          _plans = _guard(() => widget.mealPlanService.getWeek(_selected));
        }),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HearthSection(
                'Pantry Ready',
                action: 'Explore',
                onAction: widget.openPantryMatches,
              ),
              _request(
                _matches,
                (matches) {
                  final count = matches.matches
                      .where((m) => m.status == PantryMatchStatus.readyToCook)
                      .length;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      HearthBadge('$count ready', spice: true),
                      Text(
                        matches.pantryEmpty
                            ? 'Add ingredients to your pantry to find matches.'
                            : 'Recipes with confirmed ingredient quantities.',
                      ),
                    ],
                  );
                },
                () => setState(() {
                  _matches = _guard(widget.matchingService.getMatches);
                }),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HearthSection(
                'Your Grocery List',
                action: 'View all',
                onAction: widget.openGroceries,
              ),
              _request(
                _groceries,
                (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${list.items.where((i) => !i.checked).length} ${list.items.where((i) => !i.checked).length == 1 ? 'item' : 'items'} remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (list.items.isEmpty)
                      const Text(
                        'Your list is empty. Generate groceries from your meal plan.',
                      ),
                    for (final item in list.items.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                          child: CheckboxListTile(
                            key: ValueKey('home-grocery-${item.id}'),
                            value: item.checked,
                            onChanged: _toggling ? null : (_) => _toggle(item),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(item.quantityLabel),
                          ),
                        ),
                      ),
                  ],
                ),
                () => setState(() {
                  _groceries = _guard(widget.groceryService.getList);
                }),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _week(List<MealPlan> plans) {
    final monday = mealPlanWeekStart(_selected);
    final selectedMeals =
        plans
            .where((p) => mealPlanDate(p.date) == mealPlanDate(_selected))
            .toList()
          ..sort((a, b) => a.mealType.index.compareTo(b.mealType.index));
    final meal = selectedMeals.isEmpty ? null : selectedMeals.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeekdayStrip(
          days: [
            for (var i = 0; i < 7; i++) _day(mealPlanDay(monday, i), plans),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Icon(Icons.circle, size: 10, color: AppColors.accent),
            Text(
              'ON YOUR TABLE · ${mealPlanDate(_selected)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (meal == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('A little room for something delicious.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => widget.openPlanner(_selected),
                    icon: const Icon(Icons.add),
                    label: const Text('Plan a meal'),
                  ),
                ],
              ),
            ),
          )
        else
          RecipeSpotlight(
            title: meal.recipeName,
            imageUrl: meal.recipeImageUrl,
            badge: meal.mealType.label,
            metadata: [
              if (meal.plannedServings != null)
                '${meal.plannedServings} servings',
              if (meal.recipeCategory?.isNotEmpty ?? false)
                meal.recipeCategory!,
            ],
            actionLabel: 'View planned meal',
            onOpen: () => widget.openPlanner(_selected),
          ),
        if (meal != null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'From your saved meal plan',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _day(DateTime date, List<MealPlan> plans) {
    final selected = mealPlanDate(date) == mealPlanDate(_selected);
    final hasMeal = plans.any(
      (p) => mealPlanDate(p.date) == mealPlanDate(date),
    );
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey('home-date-${mealPlanDate(date)}'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 78),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
        ),
        onPressed: () {
          widget.onDateSelected(date);
          setState(() => _selected = date);
        },
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                days[date.weekday - 1],
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              hasMeal ? Icons.circle : Icons.circle_outlined,
              size: 7,
              color: selected ? AppColors.accent : AppColors.sage,
            ),
          ],
        ),
      ),
    );
  }
}
