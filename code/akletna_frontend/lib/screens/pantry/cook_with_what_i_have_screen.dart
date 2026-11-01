import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../widgets/app_state_view.dart';

import '../groceries/recipe_shortage_screen.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/pantry_matches.dart';
import '../../services/pantry_matching_service.dart';
import '../../services/pantry_service.dart';
import '../../services/ingredient_service.dart';
import '../../services/recipe_service.dart';
import '../../services/auth_service.dart';
import '../../services/grocery_list_service.dart';
import '../recipes/recipe_detail_screen.dart';
import 'my_pantry_screen.dart';
import '../../widgets/recipe_compatibility_view.dart';
import '../../models/recipe_evaluation.dart';

class CookWithWhatIHaveScreen extends StatefulWidget {
  final PantryMatchingService? matchingService;
  final PantryService? pantryService;
  final IngredientService? ingredientService;
  final RecipeService? recipeService;
  final AuthService? authService;
  const CookWithWhatIHaveScreen({
    super.key,
    this.matchingService,
    this.pantryService,
    this.ingredientService,
    this.recipeService,
    this.authService,
  });
  @override
  State<CookWithWhatIHaveScreen> createState() =>
      _CookWithWhatIHaveScreenState();
}

class _CookWithWhatIHaveScreenState extends State<CookWithWhatIHaveScreen> {
  late final _service =
      widget.matchingService ?? PantryMatchingService(minimumHalf: true);
  PantryMatches? _result;
  bool _loading = true;
  bool _redirecting = false;
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
      final result = await _service.getMatches();
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _redirecting = true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        setState(
          () => _error = 'Could not load pantry matches. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load pantry matches. Please try again.',
        );
      }
    } finally {
      if (mounted && !_redirecting) setState(() => _loading = false);
    }
  }

  Future<void> _pantry() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyPantryScreen(
          pantryService: widget.pantryService,
          ingredientService: widget.ingredientService,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _details(PantryRecipeMatch match) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantryMatchDetailsScreen(
          match: match,
          matchingService: _service,
          recipeService: widget.recipeService,
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
      title: const Text('Cook With What I Have'),
      actions: [
        IconButton(
          tooltip: 'My Pantry',
          onPressed: _pantry,
          icon: const Icon(Icons.kitchen_outlined),
        ),
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
                const HearthPageIntro(
                  title: 'Cook from your pantry',
                  subtitle: 'Recipe matches based on your actual inventory.',
                  icon: Icons.kitchen_outlined,
                ),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ] else if (_result!.pantryEmpty) ...[
                  AppStateView(
                    icon: Icons.soup_kitchen_outlined,
                    title: 'Add ingredients to your pantry first',
                    message: "Tell Akletna what you have at home and we'll show you what you can cook.",
                    actionLabel: 'Open My Pantry',
                    onAction: _pantry,
                  ),
                ] else if (_result!.matches.isEmpty) ...[
                  Text(
                    _result!.readableRecipeCount == 0
                        ? 'No recipes available yet'
                        : _result!.excludedRecipeCount ==
                              _result!.readableRecipeCount
                        ? 'No recipes with valid ingredient requirements'
                        : 'No recipes reach a 50% pantry match yet',
                  ),
                  const Text(
                    'Add pantry ingredients or check the amounts you have.',
                  ),
                ] else ...[
                  const Text(
                    'Recipes with at least a 50% pantry match. Check uncertain amounts before cooking.',
                  ),
                  const Text(
                    'Pantry match scores treat ingredients equally; they do not measure culinary importance.',
                  ),
                  const SizedBox(height: 12),
                  for (final match in _result!.matches)
                    Card(
                      child: ListTile(
                        title: Text(match.recipe.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RecipeCompatibilityView(
                              evaluation: match.recipe.evaluation,
                              compact: true,
                            ),
                            Text(
                              '${match.recipe.evaluation?.compatibility == DietaryCompatibility.conflict ? 'Pantry: ' : ''}${match.status.label}\n${match.percentage}\n${match.summary}',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _details(match),
                      ),
                    ),
                ],
                if (_error == null &&
                    _result != null &&
                    _result!.excludedRecipeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '${_result!.excludedRecipeCount} recipe(s) could not be compared because their requirements are incomplete.',
                    ),
                  ),
              ],
            ),
          ),
  );
}

class PantryMatchDetailsScreen extends StatefulWidget {
  final PantryRecipeMatch match;
  final RecipeService? recipeService;
  final AuthService? authService;
  final IngredientService? ingredientService;
  final PantryMatchingService? matchingService;
  final GroceryListService? groceryListService;
  const PantryMatchDetailsScreen({
    super.key,
    required this.match,
    this.recipeService,
    this.authService,
    this.ingredientService,
    this.matchingService,
    this.groceryListService,
  });
  @override
  State<PantryMatchDetailsScreen> createState() => _PantryMatchDetailsState();
}

class _PantryMatchDetailsState extends State<PantryMatchDetailsScreen> {
  late PantryRecipeMatch match = widget.match;
  bool _loading = false;
  String? _error;
  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.matchingService ?? PantryMatchingService())
          .getMatches();
      if (!mounted) return;
      final current = result.matches
          .where((m) => m.recipe.id == match.recipe.id)
          .firstOrNull;
      setState(() {
        if (current == null) {
          _error = 'This recipe can no longer be compared with your pantry.';
        } else {
          match = current;
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (_) => false,
        );
      } else {
        setState(
          () => _error = 'Could not refresh pantry matches. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(match.recipe.name)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HearthPageIntro(
                title: 'Pantry comparison',
                subtitle: 'Ingredient availability for the base recipe.',
                icon: Icons.fact_check_outlined,
              ),
              RecipeCompatibilityView(evaluation: match.recipe.evaluation),
              Text(
                match.status.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(match.percentage),
              Text('Base recipe: ${match.recipe.servings} serving(s)'),
              OutlinedButton.icon(
                icon: const Icon(Icons.shopping_basket_outlined),
                label: const Text('Add Missing to Groceries'),
                onPressed: () => _open(
                  RecipeShortageScreen(
                    recipeId: match.recipe.id,
                    recipeName: match.recipe.name,
                    initialServings: match.recipe.servings!,
                    service: widget.groceryListService,
                  ),
                ),
              ),
              if (match.status == PantryMatchStatus.likelyReady)
                const Text(
                  'Every ingredient is present, but some quantities need checking.',
                ),
              const SizedBox(height: 16),
              for (final ingredient in match.ingredients)
                Card(
                  child: ListTile(
                    leading: Icon(switch (ingredient.status) {
                      IngredientMatchStatus.enough =>
                        Icons.check_circle_outline,
                      IngredientMatchStatus.shortage => Icons.warning_amber,
                      IngredientMatchStatus.missing =>
                        Icons.remove_circle_outline,
                      _ => Icons.help_outline,
                    }),
                    title: Text(ingredient.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.status.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: switch (ingredient.status) {
                              IngredientMatchStatus.enough => const Color(
                                0xFF316B50,
                              ),
                              IngredientMatchStatus.shortage => const Color(
                                0xFF956321,
                              ),
                              IngredientMatchStatus.missing => const Color(
                                0xFFAA3D35,
                              ),
                              _ => const Color(0xFF68605B),
                            },
                          ),
                        ),
                        Text(ingredient.explanation),
                      ],
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () => _open(
                  RecipeDetailScreen(
                    recipe: match.recipe,
                    recipeService: widget.recipeService,
                    authService: widget.authService,
                    ingredientService: widget.ingredientService,
                    groceryListService: widget.groceryListService,
                  ),
                ),
                child: const Text('Open Recipe Detail'),
              ),
            ],
          ),
  );
}
