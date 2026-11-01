enum NutritionStatus { complete, incomplete, unavailable }

class NutritionValues {
  bool get isValid => [
    caloriesKcal,
    proteinGrams,
    carbohydratesGrams,
    fatGrams,
  ].every((value) => value.isFinite && value >= 0);
  NutritionValues scaled(double factor) => NutritionValues(
    caloriesKcal: caloriesKcal * factor,
    proteinGrams: proteinGrams * factor,
    carbohydratesGrams: carbohydratesGrams * factor,
    fatGrams: fatGrams * factor,
  );
  final double caloriesKcal;
  final double proteinGrams;
  final double carbohydratesGrams;
  final double fatGrams;
  const NutritionValues({
    required this.caloriesKcal,
    required this.proteinGrams,
    required this.carbohydratesGrams,
    required this.fatGrams,
  });
  factory NutritionValues.fromJson(Map<String, dynamic> json) =>
      NutritionValues(
        caloriesKcal: (json['caloriesKcal'] as num).toDouble(),
        proteinGrams: (json['proteinGrams'] as num).toDouble(),
        carbohydratesGrams: (json['carbohydratesGrams'] as num).toDouble(),
        fatGrams: (json['fatGrams'] as num).toDouble(),
      );
}

class RecipeNutrition {
  final NutritionStatus status;
  final NutritionValues? perServing;
  final NutritionValues? totals;
  final List<NutritionIssue> issues;
  const RecipeNutrition({
    required this.status,
    this.perServing,
    this.totals,
    this.issues = const [],
  });

  NutritionValues? totalForServings(int baseServings, int selectedServings) {
    if (status != NutritionStatus.complete ||
        totals?.isValid != true ||
        perServing?.isValid != true ||
        baseServings <= 0 ||
        selectedServings <= 0) {
      return null;
    }
    final scaled = totals!.scaled(selectedServings / baseServings);
    return scaled.isValid ? scaled : null;
  }

  NutritionValues? perServingFor(int baseServings, int selectedServings) =>
      totalForServings(
        baseServings,
        selectedServings,
      )?.scaled(1 / selectedServings);
  factory RecipeNutrition.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'COMPLETE' => NutritionStatus.complete,
      'INCOMPLETE' => NutritionStatus.incomplete,
      _ => NutritionStatus.unavailable,
    };
    final values = json['perServing'];
    final totals = json['totals'];
    final issues = (json['issues'] as List? ?? [])
        .map((v) => NutritionIssue.fromJson(v as Map<String, dynamic>))
        .toList();
    if (status == NutritionStatus.complete) {
      if (issues.isNotEmpty ||
          values is! Map<String, dynamic> ||
          totals is! Map<String, dynamic> ||
          ![
            'caloriesKcal',
            'proteinGrams',
            'carbohydratesGrams',
            'fatGrams',
          ].every(
            (key) =>
                totals[key] is num &&
                (totals[key] as num).isFinite &&
                (totals[key] as num) >= 0,
          ) ||
          ![
            'caloriesKcal',
            'proteinGrams',
            'carbohydratesGrams',
            'fatGrams',
          ].every(
            (key) =>
                values[key] is num &&
                (values[key] as num).isFinite &&
                (values[key] as num) >= 0,
          )) {
        return const RecipeNutrition(status: NutritionStatus.unavailable);
      }
      return RecipeNutrition(
        status: status,
        perServing: NutritionValues.fromJson(values),
        totals: NutritionValues.fromJson(totals),
      );
    }
    return RecipeNutrition(status: status, issues: issues);
  }
}

class NutritionIssue {
  const NutritionIssue({
    required this.recipeIngredientId,
    required this.reason,
  });
  final int? recipeIngredientId;
  final String reason;
  factory NutritionIssue.fromJson(Map<String, dynamic> json) => NutritionIssue(
    recipeIngredientId: json['recipeIngredientId'] as int?,
    reason: json['reason'] as String,
  );
  String get message => switch (reason) {
    'INVALID_SERVINGS' => 'A valid base serving count is required.',
    'NO_INGREDIENTS' => 'Recipe ingredients are missing.',
    'MISSING_INGREDIENT' => 'An ingredient reference is unavailable.',
    'MISSING_MAPPING' => 'A reviewed food and preparation mapping is needed.',
    'UNSUPPORTED_QUANTITY_OR_UNIT' => 'A positive quantity in g or kg is required; volume and count cannot be converted automatically.',
    'NUTRIENT_DATA_UNAVAILABLE' => 'The mapped food and preparation state have no usable stored nutrient profile.',
    _ => 'Nutrition cannot be verified for this ingredient.',
  };
}
