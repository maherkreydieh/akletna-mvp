import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/hearth_components.dart';

/// Preserve author-supplied instruction paragraphs; never infer times or tips.
class RecipeStepsView extends StatelessWidget {
  const RecipeStepsView({super.key, required this.instructions});
  final String instructions;
  @override
  Widget build(BuildContext context) {
    final steps = instructions
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HearthSection('Culinary Steps'),
        const SizedBox(height: 8),
        Text(
          '${steps.length} instruction ${steps.length == 1 ? 'section' : 'sections'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        if (steps.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No cooking instructions provided for this recipe.'),
            ),
          ),
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: i == steps.length - 1
                            ? AppColors.accent
                            : AppColors.primaryDark,
                        foregroundColor: i == steps.length - 1
                            ? AppColors.textPrimary
                            : Colors.white,
                        child: Text('${i + 1}'),
                      ),
                      Expanded(
                        child: VerticalDivider(
                          color: AppColors.border,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          steps[i],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Guided cooking is not available. Follow the recipe instructions above.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
