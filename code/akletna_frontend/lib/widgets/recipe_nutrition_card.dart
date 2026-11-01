import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/presentation/quantity_label.dart';
import '../models/recipe_nutrition.dart';
import 'hearth_components.dart';

class RecipeNutritionCard extends StatelessWidget {
  const RecipeNutritionCard({
    super.key,
    required this.nutrition,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.baseServings,
    required this.selectedServings,
    this.ingredientNames = const {},
  });
  final RecipeNutrition? nutrition;
  final bool loading, failed;
  final VoidCallback onRetry;
  final int? baseServings, selectedServings;
  final Map<int, String> ingredientNames;

  // Compact per-serving strip: four tiles split by thin dividers.
  Widget _statRow(NutritionValues values) => Container(
    key: const ValueKey('nutrition-stats'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          _stat(
            'cal',
            Icons.local_fire_department_outlined,
            'CAL',
            '${quantityLabel(values.caloriesKcal)} kcal',
            AppColors.accent,
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          _stat(
            'protein',
            Icons.fitness_center,
            'PROTEIN',
            '${quantityLabel(values.proteinGrams)} g',
            AppColors.primary,
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          _stat(
            'carbs',
            Icons.grain,
            'CARBS',
            '${quantityLabel(values.carbohydratesGrams)} g',
            AppColors.primary,
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          _stat(
            'fat',
            Icons.water_drop_outlined,
            'FAT',
            '${quantityLabel(values.fatGrams)} g',
            AppColors.primary,
          ),
        ],
      ),
    ),
  );

  Widget _stat(
    String id,
    IconData icon,
    String label,
    String value,
    Color color,
  ) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            key: ValueKey('nutrition-$id'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  String _totalsLine(NutritionValues v) =>
      '${quantityLabel(v.caloriesKcal)} kcal · '
      '${quantityLabel(v.proteinGrams)} g protein · '
      '${quantityLabel(v.carbohydratesGrams)} g carbs · '
      '${quantityLabel(v.fatGrams)} g fat';

  @override
  Widget build(BuildContext context) {
    final totals = nutrition?.totalForServings(
      baseServings ?? 0,
      selectedServings ?? 0,
    );
    final serving = nutrition?.perServingFor(
      baseServings ?? 0,
      selectedServings ?? 0,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (loading)
              const Text('Loading nutrition information...')
            else if (failed) ...[
              const Text('Could not load nutrition information.'),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry nutrition'),
              ),
            ] else if (totals != null && serving != null) ...[
              Text(
                'Per serving',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _statRow(serving),
              const SizedBox(height: 12),
              Text(
                'Total for $selectedServings servings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _totalsLine(totals),
                key: const ValueKey('nutrition-totals'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ] else ...[
              HearthBadge(
                nutrition?.status == NutritionStatus.incomplete
                    ? 'INCOMPLETE'
                    : 'UNAVAILABLE',
                spice: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nutrition information is not available for this recipe yet.',
              ),
              for (final issue in nutrition?.issues ?? <NutritionIssue>[])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${issue.recipeIngredientId == null ? 'Recipe' : ingredientNames[issue.recipeIngredientId] ?? 'Ingredient line #${issue.recipeIngredientId}'}: ${issue.message}',
                  ),
                ),
              if (nutrition?.issues.isNotEmpty == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Partial totals are withheld until every requirement can be verified.',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
