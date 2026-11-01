import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/presentation/quantity_label.dart';
import '../../models/recipe.dart';

class RecipeIngredientsView extends StatelessWidget {
  const RecipeIngredientsView({
    super.key,
    required this.recipe,
    required this.servings,
    required this.checkedIndices,
    required this.onToggle,
  });
  final Recipe recipe;
  final int? servings;
  final Set<int> checkedIndices;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Ingredients', style: Theme.of(context).textTheme.titleLarge),
          if (recipe.ingredients.isNotEmpty)
            Text(
              '${checkedIndices.length}/${recipe.ingredients.length} checked',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (recipe.ingredients.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No ingredients listed for this recipe.'),
          ),
        ),
      for (var index = 0; index < recipe.ingredients.length; index++)
        Card(
          child: CheckboxListTile(
            key: ValueKey('recipe-ingredient-${recipe.ingredients[index].id}'),
            value: checkedIndices.contains(index),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            title: Text(
              _label(recipe.ingredients[index]),
              style: TextStyle(
                decoration: checkedIndices.contains(index)
                    ? TextDecoration.lineThrough
                    : null,
                color: checkedIndices.contains(index)
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: (_) => onToggle(index),
          ),
        ),
    ],
  );

  String _label(RecipeIngredient ingredient) {
    if ((servings ?? 0) <= 0 || (recipe.servings ?? 0) <= 0) {
      return ingredient.displayLine;
    }
    final quantity = quantityLabel(
      ingredient.quantity * servings! / recipe.servings!,
    );
    final unit = ingredient.unit?.trim() ?? '';
    return '$quantity${unit.isEmpty ? '' : ' $unit'} ${ingredient.name}';
  }
}
