import 'package:flutter/material.dart';

import '../../widgets/weekday_strip.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../services/meal_plan_service.dart';
import '../../services/recipe_service.dart';
import '../groceries/grocery_list_screen.dart';
import '../recipes/recipe_catalog_screen.dart';
import '../../models/meal_recipe_selection.dart';
import 'planned_servings_dialog.dart';
import 'planned_meal_card.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/kitchen_destinations.dart';

class WeeklyMealPlannerScreen extends StatefulWidget {
  final MealPlanService? mealPlanService;
  final RecipeService? recipeService;
  final DateTime? initialDate;

  const WeeklyMealPlannerScreen({
    super.key,
    this.mealPlanService,
    this.recipeService,
    this.initialDate,
  });

  @override
  State<WeeklyMealPlannerScreen> createState() =>
      _WeeklyMealPlannerScreenState();
}

class _WeeklyMealPlannerScreenState extends State<WeeklyMealPlannerScreen> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  late final MealPlanService _mealPlanService;
  late final RecipeService _recipeService;
  late DateTime _monday;
  List<MealPlan> _meals = [];
  bool _loading = true;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  int _weekRequest = 0;
  late DateTime _selected;

  bool? _wasActive;
  int _plannerRequest = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final destinations = KitchenDestinations.maybeOf(context);
    final active = destinations?.selectedIndex == 2;
    if (destinations != null &&
        destinations.plannerRequest != _plannerRequest &&
        destinations.plannerDate != null) {
      _plannerRequest = destinations.plannerRequest;
      _selected = mealPlanDay(destinations.plannerDate!);
      _monday = mealPlanWeekStart(_selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy) _loadWeek();
      });
      _wasActive = active;
      return;
    }
    if (active && _wasActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_busy && !_loading) _loadWeek();
      });
    }
    _wasActive = active;
  }

  @override
  void initState() {
    super.initState();
    _mealPlanService = widget.mealPlanService ?? MealPlanService();
    _recipeService = widget.recipeService ?? RecipeService();
    _monday = mealPlanWeekStart(widget.initialDate ?? DateTime.now());
    _selected = mealPlanDay(widget.initialDate ?? DateTime.now());
    _loadWeek();
  }

  String _dateLabel(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  bool _redirectIfUnauthorized(Object error) {
    if (error is! ApiException || error.statusCode != 401) return false;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (_) => false,
    );
    return true;
  }

  Future<void> _loadWeek() async {
    final request = ++_weekRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meals = await _mealPlanService.getWeek(_monday);
      if (!mounted || request != _weekRequest) return;
      setState(() {
        _meals = meals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _weekRequest) return;
      if (_redirectIfUnauthorized(error)) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your meal plan. Please check your connection and try again.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy || _loading) return;
    await _loadWeek();
  }

  void _changeWeek(DateTime monday) {
    if (_busy || _loading) return;
    setState(() {
      _monday = monday;
      _selected = mealPlanDay(monday, _selected.weekday - 1);
    });
    _loadWeek();
  }

  Future<void> _addMeal(DateTime date, MealType type) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final recipe = await Navigator.push<Recipe>(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeCatalogScreen(
            recipeService: _recipeService,
            selection: MealRecipeSelection(date: date, mealType: type),
          ),
        ),
      );
      if (!mounted || recipe == null) return;
      if (recipe.servings == null || recipe.servings! <= 0) {
        _showMessage(
          'This recipe needs a valid serving count before it can be planned.',
        );
        return;
      }
      final plannedServings = await showDialog<int>(
        context: context,
        builder: (_) => PlannedServingsDialog(
          title: 'Add planned meal?',
          description:
              'Add ${recipe.name} for ${type.label.toLowerCase()} on ${_dateLabel(date)}?',
          initialServings: recipe.servings!,
          confirmLabel: 'Add meal',
        ),
      );
      if (!mounted || plannedServings == null) return;
      setState(() => _saving = true);
      await _mealPlanService.addMeal(
        recipeId: recipe.id,
        date: date,
        mealType: type,
        plannedServings: plannedServings,
      );
      if (!mounted) return;
      await _loadWeek();
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      _showMessage(
        error is ApiException && error.statusCode == 400
            ? 'This meal could not be added. The slot may already be taken. Refresh and try again.'
            : 'Could not confirm the new meal. Refresh your plan before trying again.',
      );
      // A network/response failure can happen after the server saved the meal.
      await _loadWeek();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _removeMeal(MealPlan meal) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove planned meal?'),
          content: Text(
            'Remove ${meal.recipeName} from ${meal.mealType.label.toLowerCase()} on ${_dateLabel(meal.date)}? Your recipe will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove meal'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() => _saving = true);
      await _mealPlanService.removeMeal(meal.id);
      if (!mounted) return;
      await _loadWeek();
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      _showMessage(
        'Could not confirm removal. Refresh your plan before trying again.',
      );
      await _loadWeek();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _editServings(MealPlan meal) async {
    if (_busy || _loading) return;
    final initial = meal.plannedServings ?? meal.recipeBaseServings;
    if (initial == null || initial <= 0) {
      _showMessage(
        'This recipe needs a valid serving count before this meal can be updated.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final servings = await showDialog<int>(
        context: context,
        builder: (_) => PlannedServingsDialog(
          title: 'Edit planned servings',
          description: meal.recipeName,
          initialServings: initial,
          confirmLabel: 'Save servings',
        ),
      );
      if (!mounted || servings == null || servings == meal.plannedServings) {
        return;
      }
      setState(() => _saving = true);
      await _mealPlanService.updateServings(meal, servings);
      if (!mounted) return;
      await _loadWeek();
      if (mounted) {
        _showMessage(
          'Servings updated. Regenerate groceries to update quantities.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (_redirectIfUnauthorized(error)) return;
      _showMessage(
        'Could not confirm serving changes. Refresh your plan before trying again.',
      );
      await _loadWeek();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGroceries() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroceryListScreen(initialDate: _monday),
        ),
      );
      if (!mounted) return;
      await _loadWeek();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replaceMeal(MealPlan meal) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final recipe = await Navigator.push<Recipe>(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeCatalogScreen(
            recipeService: _recipeService,
            selection: MealRecipeSelection(
              date: meal.date,
              mealType: meal.mealType,
              replacing: meal.recipeName,
            ),
          ),
        ),
      );
      if (!mounted || recipe == null) return;
      if (recipe.id == meal.recipeId) {
        _showMessage('Choose a different recipe to replace this meal.');
        return;
      }
      if ((recipe.servings ?? 0) <= 0) {
        _showMessage(
          'This recipe needs a valid serving count before it can be planned.',
        );
        return;
      }
      final servings = await showDialog<int>(
        context: context,
        builder: (_) => PlannedServingsDialog(
          title: 'Change planned recipe?',
          description:
              'Replace ${meal.recipeName} with ${recipe.name}? A new meal snapshot will be saved.',
          initialServings: recipe.servings!,
          confirmLabel: 'Change recipe',
        ),
      );
      if (!mounted || servings == null) return;
      setState(() => _saving = true);
      await _mealPlanService.replaceRecipe(meal, recipe.id, servings);
      if (!mounted) return;
      await _loadWeek();
      if (mounted) {
        _showMessage(
          'Recipe changed. Regenerate groceries to update quantities.',
        );
      }
    } catch (error) {
      if (!mounted || _redirectIfUnauthorized(error)) return;
      _showMessage(
        'Could not confirm the change. Refresh your plan before trying again.',
      );
      await _loadWeek();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || _loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Akletna اكلتنا')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    const Text(
                      'FAMILY TABLE ROUTINE',
                      style: TextStyle(
                        color: AppColors.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Weekly Meal Plan',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous week',
                          onPressed: disabled
                              ? null
                              : () => _changeWeek(mealPlanDay(_monday, -7)),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${_dateLabel(_monday)} – ${_dateLabel(mealPlanDay(_monday, 6))}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next week',
                          onPressed: disabled
                              ? null
                              : () => _changeWeek(mealPlanDay(_monday, 7)),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: disabled
                            ? null
                            : () {
                                _selected = mealPlanDay(DateTime.now());
                                _changeWeek(mealPlanWeekStart(DateTime.now()));
                              },
                        child: const Text('This week'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    WeekdayStrip(
                      days: [
                        for (var i = 0; i < 7; i++)
                          _dateButton(mealPlanDay(_monday, i)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_saving) const LinearProgressIndicator(),
                    if (_error != null) ...[
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _busy ? null : _loadWeek,
                        child: const Text('Retry'),
                      ),
                    ] else ...[
                      HearthSection('${_days[_selected.weekday - 1]} Schedule'),
                      const SizedBox(height: 4),
                      Text(
                        _dateLabel(_selected),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      for (final type in MealType.values) _slot(type),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const HearthSection('Your Weekly Table'),
                              const SizedBox(height: 12),
                              Text(
                                _meals.isEmpty
                                    ? 'Your week is empty. Tap an empty slot to plan a meal.'
                                    : '${_meals.length} planned ${_meals.length == 1 ? 'meal' : 'meals'} this week',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final type in MealType.values)
                                    HearthBadge(
                                      '${type.label}: ${_meals.where((m) => m.mealType == type).length}',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: disabled ? null : _openGroceries,
                        icon: const Icon(Icons.shopping_basket_outlined),
                        label: const Text('Generate Grocery List'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Review your grocery list and confirm generation for this week.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _dateButton(DateTime date) {
    final selected = mealPlanDate(date) == mealPlanDate(_selected);
    final hasMeals = _meals.any(
      (m) => mealPlanDate(m.date) == mealPlanDate(date),
    );
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey('select-date-${mealPlanDate(date)}'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 80),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          backgroundColor: selected ? AppColors.primaryDark : AppColors.surface,
          foregroundColor: selected ? Colors.white : AppColors.textPrimary,
          side: BorderSide(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        onPressed: _busy ? null : () => setState(() => _selected = date),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _days[date.weekday - 1].substring(0, 3),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              hasMeals ? Icons.circle : Icons.circle_outlined,
              size: 7,
              color: selected ? AppColors.accent : AppColors.sage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(MealType type) {
    final entries = _meals
        .where(
          (m) =>
              m.mealType == type &&
              mealPlanDate(m.date) == mealPlanDate(_selected),
        )
        .toList();
    if (entries.isEmpty) {
      return Card(
        child: ListTile(
          key: ValueKey('add-${mealPlanDate(_selected)}-${type.apiValue}'),
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(
            Icons.add_circle_outline,
            color: AppColors.primary,
          ),
          title: Text(type.label),
          subtitle: const Text('Add a meal'),
          enabled: !_busy,
          onTap: () => _addMeal(_selected, type),
        ),
      );
    }
    return Column(
      children: [
        for (final meal in entries)
          PlannedMealCard(
            meal: meal,
            busy: _busy,
            onServings: () => _editServings(meal),
            onReplace: () => _replaceMeal(meal),
            onRemove: () => _removeMeal(meal),
          ),
      ],
    );
  }
}
