import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/food_preferences.dart';
import '../../models/ingredient.dart';
import '../../services/preferences_service.dart';
import '../../services/ingredient_service.dart';

class FoodPreferencesScreen extends StatefulWidget {
  final PreferencesService? preferencesService;
  final IngredientService? ingredientService;
  const FoodPreferencesScreen({
    super.key,
    this.preferencesService,
    this.ingredientService,
  });
  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  late final _service = widget.preferencesService ?? PreferencesService();
  late final _ingredientsService =
      widget.ingredientService ?? IngredientService();
  FoodPreferences _profile = const FoodPreferences();
  Set<DietaryPreference> _diets = {};
  Set<FoodAvoidance> _avoidances = {};
  Set<MealGoal> _goals = {};
  Set<int> _dislikes = {};
  List<Ingredient> _ingredients = [];
  String _query = '';
  bool _loading = true, _saving = false, _redirecting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(FoodPreferences value) {
    _profile = value;
    _diets = Set.of(value.diets);
    _avoidances = Set.of(value.avoidances);
    _goals = Set.of(value.goals);
    _dislikes = Set.of(value.dislikedIngredientIds);
  }

  bool _auth(ApiException error) {
    if (error.statusCode != 401) return false;
    _redirecting = true;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (_) => false,
    );
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.getPreferences(),
        _ingredientsService.getIngredients(),
      ]);
      if (mounted) {
        setState(() {
          _apply(results[0] as FoodPreferences);
          _ingredients = results[1] as List<Ingredient>;
          _ingredients.sort((a, b) {
            final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return name == 0 ? a.id.compareTo(b.id) : name;
          });
        });
      }
    } on ApiException catch (e) {
      if (mounted && !_auth(e)) {
        setState(
          () => _error =
              'Could not load your food preferences. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load your food preferences. Please try again.',
        );
      }
    } finally {
      if (mounted && !_redirecting) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _redirecting) return;
    setState(() => _saving = true);
    try {
      final result = await _service.save(
        FoodPreferences(
          diets: _diets,
          avoidances: _avoidances,
          dislikedIngredientIds: _dislikes,
          goals: _goals,
        ),
      );
      if (!mounted) return;
      setState(() => _apply(result));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Food preferences saved.')));
    } on ApiException catch (e) {
      if (mounted && !_auth(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.statusCode == 400
                  ? e.message
                  : 'Could not save preferences. Please try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save preferences. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted && !_redirecting) setState(() => _saving = false);
    }
  }

  void _selectDislike(Ingredient ingredient) {
    if (_dislikes.length >= 50 && !_dislikes.contains(ingredient.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose up to 50 disliked ingredients.')),
      );
      return;
    }
    setState(() => _dislikes.add(ingredient.id));
  }

  String _name(int id) =>
      _ingredients.where((i) => i.id == id).firstOrNull?.name ??
      'Unavailable ingredient';
  Widget _section(String title, Widget content) => Card(
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          content,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Food Preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const HearthPageIntro(
                  title: 'Your kitchen, your way',
                  subtitle: 'Choose the food preferences that work for you.',
                  icon: Icons.tune,
                ),
                const Text(
                  'All sections are optional. Dietary settings and foods you dislike are separate from meal goals.',
                ),
                const Text(
                  'Check ingredient labels and preparation details; Akletna cannot guarantee allergy safety.',
                ),
                _section(
                  'Dietary preferences',
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final diet in DietaryPreference.values)
                        FilterChip(
                          label: Text(diet.label),
                          selected: _diets.contains(diet),
                          onSelected: _saving
                              ? null
                              : (selected) => setState(() {
                                  selected
                                      ? _diets.add(diet)
                                      : _diets.remove(diet);
                                }),
                        ),
                    ],
                  ),
                ),
                _section(
                  'Ingredients to avoid',
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final item in FoodAvoidance.values)
                        FilterChip(
                          label: Text(item.label),
                          selected: _avoidances.contains(item),
                          onSelected: _saving
                              ? null
                              : (selected) => setState(() {
                                  selected
                                      ? _avoidances.add(item)
                                      : _avoidances.remove(item);
                                }),
                        ),
                    ],
                  ),
                ),
                _section(
                  "Foods I don't like",
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final id in _dislikes)
                            InputChip(
                              label: Text(_name(id)),
                              onDeleted: _saving
                                  ? null
                                  : () => setState(() => _dislikes.remove(id)),
                            ),
                        ],
                      ),
                      TextField(
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Search ingredients you dislike',
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      if (_query.isNotEmpty) ...[
                        for (final ingredient
                            in _ingredients
                                .where(
                                  (i) => i.name.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                                )
                                .take(10))
                          ListTile(
                            title: Text(ingredient.name),
                            trailing: _dislikes.contains(ingredient.id)
                                ? const Icon(Icons.check)
                                : const Icon(Icons.add),
                            onTap: _saving
                                ? null
                                : () => _selectDislike(ingredient),
                          ),
                        if (!_ingredients.any(
                          (i) => i.name.toLowerCase().contains(
                            _query.toLowerCase(),
                          ),
                        ))
                          const Text('No existing ingredients match.'),
                      ],
                    ],
                  ),
                ),
                _section(
                  "What I'm looking for",
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final goal in MealGoal.values)
                        FilterChip(
                          label: Text(goal.label),
                          selected: _goals.contains(goal),
                          onSelected: _saving
                              ? null
                              : (selected) => setState(() {
                                  selected
                                      ? _goals.add(goal)
                                      : _goals.remove(goal);
                                }),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'Preferred goals do not hide other recipes. Budget Friendly is a curated label, not a price estimate.',
                ),
                if (_profile.legacyAllergies.isNotEmpty ||
                    _profile.legacyDiets.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Some older dietary settings are preserved but cannot be evaluated yet. Compatibility may remain unverified.',
                    ),
                  ),
                if (_profile.legacyDislikes.isNotEmpty)
                  Text(
                    'Older disliked foods are preserved: ${_profile.legacyDislikes.join(', ')}. Select their exact ingredients above; names are not matched automatically.',
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Preferences'),
                ),
              ],
            ),
    ),
  );
}
