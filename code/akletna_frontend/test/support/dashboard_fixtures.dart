import 'package:akletna_frontend/models/grocery_list.dart';
import 'package:akletna_frontend/models/meal_plan.dart';
import 'package:akletna_frontend/models/pantry_matches.dart';
import 'package:akletna_frontend/models/recipe.dart';
import 'package:akletna_frontend/models/recommendations.dart';
import 'package:akletna_frontend/models/food_preferences.dart';
import 'package:akletna_frontend/services/recommendation_service.dart';
import 'package:akletna_frontend/services/grocery_list_service.dart';
import 'package:akletna_frontend/services/meal_plan_service.dart';
import 'package:akletna_frontend/services/pantry_matching_service.dart';
import 'package:akletna_frontend/services/recipe_service.dart';

class DashboardRecipes extends RecipeService {
  @override
  Future<List<Recipe>> getRecipes() async => [];
  @override
  Future<List<Recipe>> getSavedRecipes() async => [];
}

class DashboardRecommendations extends RecommendationService {
  @override
  Future<HomeRecommendations> getHomeRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async => HomeRecommendations.fromJson({
    'preferencesConfigured': false,
    'limitations': <String>[],
    'selection': {
      'pantryEmpty': true,
      'readableRecipeCount': 0,
      'excludedRecipeCount': 0,
      'recommendations': <dynamic>[],
    },
  });
}

class DashboardPlans extends MealPlanService {
  @override
  Future<List<MealPlan>> getWeek(DateTime date) async => [];
}

class DashboardGroceries extends GroceryListService {
  @override
  Future<GroceryList> getList() async =>
      const GroceryList(id: null, updatedAt: null, items: []);
}

class DashboardMatches extends PantryMatchingService {
  @override
  Future<PantryMatches> getMatches() async => PantryMatches.fromJson({
    'pantryEmpty': true,
    'readableRecipeCount': 0,
    'excludedRecipeCount': 0,
    'matches': [],
  });
}
