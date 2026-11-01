import 'package:flutter/material.dart';

import '../models/recipe_evaluation.dart';
import '../models/food_preferences.dart';

class RecipeCompatibilityView extends StatelessWidget {
  final RecipeEvaluation? evaluation;
  final bool compact;
  const RecipeCompatibilityView({
    super.key,
    required this.evaluation,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final value = evaluation;
    if (value == null) return const SizedBox.shrink();
    final conflict = value.compatibility == DietaryCompatibility.conflict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          value.label,
          style: TextStyle(
            color: conflict ? Theme.of(context).colorScheme.error : null,
            fontWeight: conflict ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        for (final reason in value.reasons.where(
          (r) => !compact || r.severity != CompatibilitySeverity.uncertain,
        ))
          Text(
            reason.message,
            style: TextStyle(
              color: reason.severity == CompatibilitySeverity.avoid
                  ? Theme.of(context).colorScheme.error
                  : null,
              fontSize: compact ? 12 : 14,
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final goal in MealGoal.values)
              if (value.goals[goal] == GoalQualification.qualifies)
                Chip(label: Text(goal.label)),
          ],
        ),
        if (!compact) ...[
          const Text(
            'Check ingredient labels and preparation details. This is filtering assistance, not an allergy-safety guarantee.',
          ),
          if (value.goals[MealGoal.budgetFriendly] ==
              GoalQualification.qualifies)
            const Text(
              'Budget Friendly is a curated classification, not a live price calculation.',
            ),
          if (value.proteinPerServing != null)
            Text(
              'Protein per serving: ${value.proteinPerServing!.toStringAsFixed(2)} g. High Protein threshold: ${value.proteinThreshold.toStringAsFixed(0)} g.',
            ),
          if (value.goals[MealGoal.highProtein] == GoalQualification.unknown)
            const Text(
              'High Protein cannot be verified because trusted nutrition is incomplete or unavailable.',
            ),
        ],
      ],
    );
  }
}
