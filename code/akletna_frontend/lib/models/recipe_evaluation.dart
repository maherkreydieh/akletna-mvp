import 'food_preferences.dart';

enum DietaryCompatibility { compatible, conflict, unknown }

enum GoalQualification { qualifies, doesNotQualify, unknown }

enum CompatibilitySeverity { avoid, uncertain, dislike }

class CompatibilityReason {
  final String code, message;
  final CompatibilitySeverity severity;
  final int? ingredientId;
  CompatibilityReason.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      message = json['message'] as String,
      severity = switch (json['severity']) {
        'AVOID' => CompatibilitySeverity.avoid,
        'UNCERTAIN' => CompatibilitySeverity.uncertain,
        'DISLIKE' => CompatibilitySeverity.dislike,
        _ => throw const FormatException('Invalid severity'),
      },
      ingredientId = json['ingredientId'] as int?;
}

class RecipeEvaluation {
  final DietaryCompatibility compatibility;
  final List<CompatibilityReason> reasons;
  final Map<DietaryPreference, DietaryCompatibility> diets;
  final Map<MealGoal, GoalQualification> goals;
  final double? proteinPerServing;
  final double proteinThreshold;
  RecipeEvaluation.fromJson(Map<String, dynamic> json)
    : compatibility = parseCompatibility(json['compatibility']),
      reasons = (json['reasons'] as List)
          .map((v) => CompatibilityReason.fromJson(v as Map<String, dynamic>))
          .toList(),
      diets = {
        for (final diet in DietaryPreference.values)
          diet: parseCompatibility((json['diets'] as Map)[diet.apiValue]),
      },
      goals = {
        for (final goal in MealGoal.values)
          goal: parseGoal((json['mealGoals'] as Map)[goal.apiValue]),
      },
      proteinPerServing = (json['proteinGramsPerServing'] as num?)?.toDouble(),
      proteinThreshold = (json['highProteinThresholdGrams'] as num).toDouble() {
    if (!proteinThreshold.isFinite ||
        proteinThreshold <= 0 ||
        (proteinPerServing != null &&
            (!proteinPerServing!.isFinite || proteinPerServing! < 0))) {
      throw const FormatException('Invalid nutrition classification');
    }
  }
  static DietaryCompatibility parseCompatibility(dynamic value) =>
      switch (value) {
        'COMPATIBLE' => DietaryCompatibility.compatible,
        'CONFLICT' => DietaryCompatibility.conflict,
        'UNKNOWN' => DietaryCompatibility.unknown,
        _ => throw const FormatException('Invalid compatibility'),
      };
  static GoalQualification parseGoal(dynamic value) => switch (value) {
    'QUALIFIES' => GoalQualification.qualifies,
    'DOES_NOT_QUALIFY' => GoalQualification.doesNotQualify,
    'UNKNOWN' => GoalQualification.unknown,
    _ => throw const FormatException('Invalid goal'),
  };
  String get label => switch (compatibility) {
    DietaryCompatibility.compatible => 'Matches configured dietary settings',
    DietaryCompatibility.conflict =>
      'Avoid — conflicts with your dietary settings',
    DietaryCompatibility.unknown => 'Dietary compatibility unverified',
  };
}
