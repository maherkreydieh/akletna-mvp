import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/meal_plan.dart';
import '../../widgets/hearth_components.dart';
import '../../widgets/kitchen_thumbnail.dart';

class PlannedMealCard extends StatelessWidget {
  const PlannedMealCard({
    super.key,
    required this.meal,
    required this.busy,
    required this.onServings,
    required this.onReplace,
    required this.onRemove,
  });
  final MealPlan meal;
  final bool busy;
  final VoidCallback onServings, onReplace, onRemove;
  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: meal.mealType == MealType.lunch
            ? AppColors.primary
            : AppColors.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitchenThumbnail(
                url: meal.recipeImageUrl,
                recipeName: meal.recipeName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.mealType.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meal.recipeName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (meal.recipeCategory?.trim().isNotEmpty == true)
                      Text(
                        meal.recipeCategory!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      meal.plannedServings == null
                          ? 'Servings unavailable'
                          : '${meal.plannedServings} ${meal.plannedServings == 1 ? 'serving' : 'servings'}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HearthBadge(
            meal.snapshotState == 'UNRESOLVED'
                ? 'Recipe snapshot unavailable'
                : 'Saved meal snapshot',
            spice: meal.snapshotState == 'UNRESOLVED',
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: ValueKey('replace-${meal.id}'),
                onPressed: busy ? null : onReplace,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Change Recipe'),
              ),
              IconButton(
                key: ValueKey('edit-servings-${meal.id}'),
                tooltip: 'Edit planned servings',
                onPressed: busy || meal.snapshotState == 'UNRESOLVED'
                    ? null
                    : onServings,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('remove-${meal.id}'),
                tooltip: 'Remove ${meal.recipeName}',
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
