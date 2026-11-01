import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/recipe_shortage.dart';
import '../../services/grocery_list_service.dart';
import '../meal_plans/planned_servings_dialog.dart';
import '../pantry/my_pantry_screen.dart';
import 'grocery_list_screen.dart';

class RecipeShortageScreen extends StatefulWidget {
  final int recipeId;
  final String recipeName;
  final int initialServings;
  final GroceryListService? service;
  const RecipeShortageScreen({
    super.key,
    required this.recipeId,
    required this.recipeName,
    required this.initialServings,
    this.service,
  });
  @override
  State<RecipeShortageScreen> createState() => _RecipeShortageScreenState();
}

class _RecipeShortageScreenState extends State<RecipeShortageScreen> {
  late final GroceryListService _service;
  late int _servings;
  RecipeShortage? _result;
  bool _busy = false;
  bool _redirecting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GroceryListService();
    _servings = widget.initialServings;
    _load();
  }

  Future<void> _load({bool add = false}) async {
    if (_busy || _redirecting) return;
    if (add && (_result == null || _result!.added || _result!.pantryEmpty)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = add
          ? await _service.addShortages(widget.recipeId, _servings)
          : await _service.previewShortages(widget.recipeId, _servings);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        _redirecting = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not load missing ingredients. Please try again.',
        );
      }
    } finally {
      if (mounted && !_redirecting) setState(() => _busy = false);
    }
  }

  Future<void> _servingChoice() async {
    final servings = await showDialog<int>(
      context: context,
      builder: (_) => PlannedServingsDialog(
        title: 'How many servings?',
        description: widget.recipeName,
        initialServings: _servings,
        confirmLabel: 'Check ingredients',
      ),
    );
    if (!mounted || servings == null || servings == _servings) return;
    _servings = servings;
    await _load();
  }

  Future<void> _navigate(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Missing Ingredients'),
      actions: [
        IconButton(
          tooltip: 'Refresh missing ingredients',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                FilledButton(
                  onPressed: () => _load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HearthPageIntro(
                title: 'Complete your ingredients',
                subtitle: 'Check known shortages before adding them to your grocery list.',
                icon: Icons.shopping_basket_outlined,
              ),
              Text(
                _result!.recipeName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                title: Text('$_servings servings'),
                trailing: TextButton(
                  onPressed: _servingChoice,
                  child: const Text('Change servings'),
                ),
              ),
              const Text(
                'This adds missing amounts for this recipe. Weekly meal requirements stay separate; avoid adding the same cooking occasion twice.',
              ),
              if (_result!.added)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Already added for this recipe and serving count. Remove the addition from Groceries before adding it again.',
                  ),
                )
              else if (_result!.pantryEmpty) ...[
                const Text(
                  'Your pantry is empty. Add pantry ingredients before checking what is missing.',
                ),
                TextButton(
                  onPressed: () => _navigate(const MyPantryScreen()),
                  child: const Text('Open My Pantry'),
                ),
              ] else if (!_result!.ingredients.any((e) => e.actionable))
                const Text(
                  'No known missing amounts to add. Check any uncertain quantities below.',
                ),
              for (final ingredient in _result!.ingredients)
                ListTile(
                  title: Text(ingredient.name),
                  subtitle: Text(ingredient.explanation),
                  leading: Icon(
                    ingredient.actionable
                        ? Icons.shopping_basket_outlined
                        : ingredient.status == 'ENOUGH'
                        ? Icons.check_circle_outline
                        : Icons.help_outline,
                  ),
                ),
              if (!_result!.added &&
                  !_result!.pantryEmpty &&
                  _result!.ingredients.any((e) => e.actionable))
                FilledButton(
                  onPressed: () => _load(add: true),
                  child: const Text('Add Missing to Groceries'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    _navigate(GroceryListScreen(groceryListService: _service)),
                child: const Text('Open Grocery List'),
              ),
            ],
          ),
  );
}
