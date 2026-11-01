enum DietaryPreference {
  vegetarian('VEGETARIAN', 'Vegetarian'),
  vegan('VEGAN', 'Vegan');

  final String apiValue, label;
  const DietaryPreference(this.apiValue, this.label);
}

enum FoodAvoidance {
  dairy('DAIRY', 'Dairy'),
  egg('EGG', 'Egg'),
  peanut('PEANUT', 'Peanut'),
  treeNut('TREE_NUT', 'Tree nuts'),
  sesame('SESAME', 'Sesame'),
  soy('SOY', 'Soy'),
  wheat('WHEAT', 'Wheat'),
  gluten('GLUTEN', 'Gluten'),
  fish('FISH', 'Fish'),
  shellfish('SHELLFISH', 'Shellfish');

  final String apiValue, label;
  const FoodAvoidance(this.apiValue, this.label);
}

enum MealGoal {
  budgetFriendly('BUDGET_FRIENDLY', 'Budget Friendly'),
  highProtein('HIGH_PROTEIN', 'High Protein');

  final String apiValue, label;
  const MealGoal(this.apiValue, this.label);
}

class FoodPreferences {
  final Set<DietaryPreference> diets;
  final Set<FoodAvoidance> avoidances;
  final Set<int> dislikedIngredientIds;
  final Set<MealGoal> goals;
  final List<String> legacyAllergies, legacyDiets, legacyDislikes;
  const FoodPreferences({
    this.diets = const {},
    this.avoidances = const {},
    this.dislikedIngredientIds = const {},
    this.goals = const {},
    this.legacyAllergies = const [],
    this.legacyDiets = const [],
    this.legacyDislikes = const [],
  });
  factory FoodPreferences.fromJson(Map<String, dynamic> json) =>
      FoodPreferences(
        diets: (json['dietaryRestrictions'] as List)
            .map(
              (v) =>
                  DietaryPreference.values.firstWhere((d) => d.apiValue == v),
            )
            .toSet(),
        avoidances: (json['allergies'] as List)
            .map((v) => FoodAvoidance.values.firstWhere((d) => d.apiValue == v))
            .toSet(),
        dislikedIngredientIds: (json['dislikedIngredientIds'] as List)
            .cast<int>()
            .toSet(),
        goals: (json['preferredMealGoals'] as List)
            .map((v) => MealGoal.values.firstWhere((g) => g.apiValue == v))
            .toSet(),
        legacyAllergies: (json['legacyAllergies'] as List).cast<String>(),
        legacyDiets: (json['legacyDietaryRestrictions'] as List).cast<String>(),
        legacyDislikes: (json['dislikedIngredients'] as List).cast<String>(),
      );
  Map<String, dynamic> toRequestJson() => {
    'dietaryRestrictions': diets.map((v) => v.apiValue).toList(),
    'allergies': avoidances.map((v) => v.apiValue).toList(),
    'dislikedIngredientIds': dislikedIngredientIds.toList()..sort(),
    'preferredMealGoals': goals.map((v) => v.apiValue).toList(),
  };
}
