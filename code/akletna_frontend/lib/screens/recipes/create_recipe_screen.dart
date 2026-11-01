import 'package:flutter/material.dart';

import '../../widgets/hearth_page_intro.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../services/ingredient_service.dart';
import '../../services/recipe_service.dart';

class CreateRecipeScreen extends StatefulWidget {
  final Recipe? recipe;
  final RecipeService? recipeService;
  final IngredientService? ingredientService;
  const CreateRecipeScreen({
    super.key,
    this.recipeService,
    this.ingredientService,
    this.recipe,
  });
  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _IngredientRow {
  Ingredient? ingredient;
  final quantity = TextEditingController();
  final unit = TextEditingController();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  final _servings = TextEditingController(text: '1');
  final _rows = <_IngredientRow>[_IngredientRow()];
  late final _recipes = widget.recipeService ?? RecipeService();
  late final _ingredients = widget.ingredientService ?? IngredientService();
  List<Ingredient> _available = [];
  RecipeVisibility _visibility = RecipeVisibility.private;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    if (recipe != null) {
      _name.text = recipe.name;
      _description.text = recipe.description;
      _instructions.text = recipe.instructions;
      _servings.text = recipe.servings?.toString() ?? '';
      _visibility = recipe.visibility;
      _rows.clear();
      for (final line in recipe.ingredients) {
        _rows.add(
          _IngredientRow()
            ..ingredient = Ingredient(
              id: line.ingredientId,
              name: line.name,
              unit: line.unit ?? '',
            )
            ..quantity.text = line.quantity.toString()
            ..unit.text = line.unit ?? '',
        );
      }
    }
    _loadIngredients();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _instructions,
      _servings,
      ..._rows.map((row) => row.quantity),
      ..._rows.map((row) => row.unit),
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _failure(ApiException exception) {
    if (!mounted) {
      return;
    }
    if (exception.statusCode == 401) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.loginRoute,
        (_) => false,
      );
    } else {
      setState(() => _error = exception.message);
    }
  }

  Future<void> _loadIngredients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _ingredients.getIngredients();
      if (mounted) {
        setState(() {
          for (final row in _rows) {
            final matches = items.where(
              (item) => item.id == row.ingredient?.id,
            );
            row.ingredient = matches.isEmpty ? null : matches.first;
          }
          _available = items;
        });
      }
    } on ApiException catch (e) {
      _failure(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _newIngredient() async {
    if (_saving || _loading) return;
    final name = TextEditingController();
    final unit = TextEditingController();
    final form = GlobalKey<FormState>();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('New shared ingredient'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reuse an existing ingredient when possible. This unit is a default; each recipe line can use its own unit.',
              ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ingredient name'),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ||
                        value!.trim().length > 100
                    ? 'Enter 2–100 characters.'
                    : null,
              ),
              TextFormField(
                controller: unit,
                decoration: const InputDecoration(
                  labelText: 'Unit (for example g or cup)',
                ),
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        value.trim().length > 30
                    ? 'Enter a unit (up to 30 characters).'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, [name.text, unit.text]);
              }
            },
            child: const Text('Create ingredient'),
          ),
        ],
      ),
    );
    // Dialog controllers are disposed after its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    unit.dispose();
    if (values == null || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ingredient = await _ingredients.createIngredient(
        values[0],
        values[1],
      );
      if (mounted) {
        setState(() {
          _available.add(ingredient);
          final emptyRows = _rows.where((row) => row.ingredient == null);
          if (emptyRows.isNotEmpty) {
            emptyRows.first.ingredient = ingredient;
            emptyRows.first.unit.text = ingredient.unit;
          } else {
            _rows.add(
              _IngredientRow()
                ..ingredient = ingredient
                ..unit.text = ingredient.unit,
            );
          }
        });
      }
    } on ApiException catch (e) {
      _failure(e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (!_form.currentState!.validate()) {
      return;
    }
    final ids = _rows.map((row) => row.ingredient!.id).toSet();
    if (ids.length != _rows.length) {
      setState(() => _error = 'Select each ingredient only once.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final request = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'instructions': _instructions.text.trim(),
        'servings': int.parse(_servings.text.trim()),
        'visibility': _visibility.name.toUpperCase(),
        'ingredients': _rows
            .map(
              (row) => {
                'ingredientId': row.ingredient!.id,
                'quantity': double.parse(row.quantity.text.trim()),
                'unit': row.unit.text.trim(),
              },
            )
            .toList(),
        // These fields are not edited by this form; preserve them on full PUT.
        if (widget.recipe != null) ...{
          'cookingTime': widget.recipe!.cookingTime > 0
              ? widget.recipe!.cookingTime
              : null,
          'category': widget.recipe!.category,
          'imageUrl': widget.recipe!.imageUrl,
        },
      };
      final recipe = widget.recipe == null
          ? await _recipes.createRecipe(request)
          : await _recipes.updateRecipe(widget.recipe!.id, request);
      if (mounted) {
        Navigator.pop(context, recipe);
      }
    } on ApiException catch (e) {
      _failure(e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recipe == null ? 'Create Recipe' : 'Edit Recipe'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: HearthFormSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HearthPageIntro(
                        title: widget.recipe == null
                            ? 'From your kitchen'
                            : 'Refine your recipe',
                        subtitle: 'Keep your family recipes private or share them with the community.',
                        icon: Icons.edit_note,
                      ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _loadIngredients,
                          child: const Text('Reload ingredients'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Recipe name',
                        ),
                        validator: (value) =>
                            (value?.trim().length ?? 0) < 2 ||
                                value!.trim().length > 150
                            ? 'Enter a name with 2–150 characters.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _description,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instructions,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter cooking instructions.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _servings,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Servings',
                        ),
                        validator: (value) {
                          final count = int.tryParse(value?.trim() ?? '');
                          return count == null ||
                                  count <= 0 ||
                                  count > 2147483647
                              ? 'Enter a positive whole number.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RecipeVisibility>(
                        isExpanded: true,
                        initialValue: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: RecipeVisibility.private,
                            child: Text('Private — only you'),
                          ),
                          DropdownMenuItem(
                            value: RecipeVisibility.public,
                            child: Text('Public — shared with others'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _visibility = value!),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Quantities are for the entire recipe. Set the unit used by each line. Nutrition currently supports g and kg only.',
                      ),
                      for (final row in _rows)
                        Card(
                          key: ObjectKey(row),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                DropdownButtonFormField<Ingredient>(
                                  initialValue: row.ingredient,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingredient',
                                  ),
                                  items: _available
                                      .map(
                                        (item) => DropdownMenuItem(
                                          value: item,
                                          child: Text(
                                            '${item.name} (${item.unit})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    row.ingredient = value;
                                    row.unit.text = value?.unit ?? '';
                                  }),
                                  validator: (value) => value == null
                                      ? 'Select an ingredient.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: row.unit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit (g, kg, mL, cup…)',
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) > 30
                                      ? 'Use at most 30 characters.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: row.quantity,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    suffixText: row.unit.text,
                                  ),
                                  validator: (value) {
                                    final quantity = double.tryParse(
                                      value?.trim() ?? '',
                                    );
                                    return quantity == null ||
                                            !quantity.isFinite ||
                                            quantity <= 0
                                        ? 'Enter a positive quantity.'
                                        : null;
                                  },
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _rows.length == 1 && widget.recipe == null
                                      ? null
                                      : () => setState(() {
                                          _rows.remove(row);
                                          row.quantity.dispose();
                                          row.unit.dispose();
                                        }),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  label: const Text('Remove ingredient'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _rows.add(_IngredientRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add ingredient row'),
                      ),
                      TextButton(
                        onPressed: _newIngredient,
                        child: const Text('Create missing ingredient'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.recipe == null
                                    ? 'Create recipe'
                                    : 'Save changes',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
