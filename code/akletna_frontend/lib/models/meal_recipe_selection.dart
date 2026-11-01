import 'meal_plan.dart';

/// Navigation context only; the planner remains responsible for confirmation/save.
class MealRecipeSelection {
  const MealRecipeSelection({
    required this.date,
    required this.mealType,
    this.replacing,
  });
  final DateTime date;
  final MealType mealType;
  final String? replacing;
  String get label => '${mealType.label} · ${mealPlanDate(date)}';
}
