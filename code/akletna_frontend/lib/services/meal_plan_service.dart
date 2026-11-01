import 'meal_plan_changes.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/meal_plan.dart';

class MealPlanService {
  final ApiClient _apiClient;

  MealPlanService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<MealPlan>> getWeek(DateTime date) async {
    final monday = mealPlanWeekStart(date);
    try {
      final response = await _apiClient.get(
        '/api/meal-plans',
        queryParameters: {
          'startDate': mealPlanDate(monday),
          'endDate': mealPlanDate(mealPlanDay(monday, 6)),
        },
      );
      return (response.data as List<dynamic>)
          .map((json) => MealPlan.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read your meal plan.');
    }
  }

  Future<MealPlan> addMeal({
    required int plannedServings,
    required int recipeId,
    required DateTime date,
    required MealType mealType,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/meal-plans',
        data: {
          'plannedServings': plannedServings,
          'recipeId': recipeId,
          'date': mealPlanDate(date),
          'mealType': mealType.apiValue,
        },
      );
      MealPlanChanges.notify();
      return MealPlan.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read the planned meal response.');
    }
  }

  Future<void> removeMeal(int id) async {
    await _apiClient.delete('/api/meal-plans/$id');
    MealPlanChanges.notify();
  }

  /// The existing PUT captures a new snapshot only when the recipe ID changes.
  Future<MealPlan> replaceRecipe(
    MealPlan meal,
    int recipeId,
    int plannedServings,
  ) async {
    final response = await _apiClient.put(
      '/api/meal-plans/${meal.id}',
      data: {
        'recipeId': recipeId,
        'date': mealPlanDate(meal.date),
        'mealType': meal.mealType.apiValue,
        'plannedServings': plannedServings,
      },
    );
    MealPlanChanges.notify();
    try {
      return MealPlan.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message:
            'Could not read the changed meal. Refresh before trying again.',
      );
    }
  }

  Future<MealPlan> updateServings(MealPlan meal, int plannedServings) async {
    final response = await _apiClient.put(
      '/api/meal-plans/${meal.id}',
      data: {
        'recipeId': meal.recipeId,
        'date': mealPlanDate(meal.date),
        'mealType': meal.mealType.apiValue,
        'plannedServings': plannedServings,
      },
    );
    MealPlanChanges.notify();
    try {
      return MealPlan.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read the updated planned meal. Refresh before trying again.',
      );
    }
  }
}
