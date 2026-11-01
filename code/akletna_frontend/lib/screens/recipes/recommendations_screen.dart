import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/presentation/quantity_label.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/food_preferences.dart';
import '../../models/recommendations.dart';
import '../../models/recipe_evaluation.dart';
import '../../services/recommendation_service.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/ingredient_service.dart';
import '../../services/pantry_service.dart';
import '../../services/preferences_service.dart';
import '../../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import '../pantry/my_pantry_screen.dart';
import '../preferences/food_preferences_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  final bool homeSelection;
  final RecommendationService? recommendationService;
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  final PantryService? pantryService;
  final PreferencesService? preferencesService;
  const RecommendationsScreen({
    super.key,
    this.homeSelection = false,
    this.recommendationService,
    this.recipeService,
    this.authService,
    this.ingredientService,
    this.pantryService,
    this.preferencesService,
  });
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  late final _service = widget.recommendationService ?? RecommendationService();
  Recommendations? _result;
  bool _loading = true;
  bool _redirecting = false;
  String? _error, _category;
  Set<MealGoal> _goals = {};
  DietaryPreference? _diet;
  int _request = 0;
  final Set<String> _categories = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = widget.homeSelection
          ? (await _service.getHomeRecommendations(
              category: _category,
              goals: Set.of(_goals),
              diet: _diet,
            )).selection
          : await _service.getRecommendations(
              category: _category,
              goals: Set.of(_goals),
              diet: _diet,
            );
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _categories.addAll(
          result.items
              .map((r) => r.recipe.category.trim())
              .where((c) => c.isNotEmpty),
        );
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
      if (e.statusCode == 401) {
        _redirecting = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Could not load recommendations. Please try again.',
        );
      }
    } finally {
      if (mounted && request == _request && !_redirecting) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _navigate(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  void _why(Recommendation recommendation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why ${recommendation.recipe.name}?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Akletna recommendation score: a rule-based match, not a probability.',
                ),
                for (final reason in recommendation.reasons)
                  ListTile(
                    title: Text(reason.message),
                    trailing: Text(
                      '${reason.points > 0 ? '+' : ''}${reason.points.toStringAsFixed(2)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Recommendations'),
      actions: [
        IconButton(
          tooltip: 'My Pantry',
          icon: const Icon(Icons.kitchen),
          onPressed: () => _navigate(
            MyPantryScreen(
              pantryService: widget.pantryService,
              ingredientService: widget.ingredientService,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Food Preferences',
          icon: const Icon(Icons.tune),
          onPressed: () => _navigate(
            FoodPreferencesScreen(
              preferencesService: widget.preferencesService,
              ingredientService: widget.ingredientService,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh recommendations',
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
    ),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All categories'),
                selected: _category == null,
                onSelected: (_) {
                  setState(() => _category = null);
                  _load();
                },
              ),
              for (final category in (_categories.toList()..sort()))
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (selected) {
                    setState(() => _category = selected ? category : null);
                    _load();
                  },
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            spacing: 8,
            children: [
              for (final goal in MealGoal.values)
                FilterChip(
                  label: Text(goal.label),
                  selected: _goals.contains(goal),
                  onSelected: (selected) {
                    setState(() {
                      selected ? _goals.add(goal) : _goals.remove(goal);
                    });
                    _load();
                  },
                ),
              for (final diet in DietaryPreference.values)
                FilterChip(
                  label: Text(diet.label),
                  selected: _diet == diet,
                  onSelected: (selected) {
                    setState(() => _diet = selected ? diet : null);
                    _load();
                  },
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = null;
                    _diet = null;
                    _goals = {};
                  });
                  _load();
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const HearthPageIntro(
                        title: 'Ideas for your table',
                        subtitle: 'Suggestions based on your saved food preferences and pantry.',
                        icon: Icons.soup_kitchen_outlined,
                      ),
                      if (_result!.pantryEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Add pantry ingredients to see which meals you can make at home.',
                          ),
                        ),
                      if (_result!.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No recipes match yet. Try clearing filters or adding recipes to your library.',
                          ),
                        ),
                      for (final item in _result!.items)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RecipeCard(
                              recipe: item.recipe,
                              showEvaluation: false,
                              onTap: () => _navigate(
                                RecipeDetailScreen(
                                  recipe: item.recipe,
                                  recipeService: widget.recipeService,
                                  authService: widget.authService,
                                  ingredientService: widget.ingredientService,
                                ),
                              ),
                            ),
                            Text(
                              '#${item.rank} · ${quantityLabel(item.score)} Akletna recommendation score',
                            ),
                            if (item.pantryPercentage != null)
                              Text(
                                '${quantityLabel(item.pantryPercentage!)}% pantry match · ${item.pantryStatus!.label}',
                              ),
                            for (final reason in item.reasons.take(2))
                              Text(reason.message),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final goal in MealGoal.values)
                                  if (item.recipe.evaluation!.goals[goal] ==
                                      GoalQualification.qualifies)
                                    Chip(label: Text(goal.label)),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _why(item),
                              child: const Text('Why this recommendation?'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
