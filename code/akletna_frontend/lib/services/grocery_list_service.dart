import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/grocery_list.dart';
import '../models/meal_plan.dart';
import '../models/recipe_shortage.dart';

class GroceryListService {
  Future<RecipeShortage> previewShortages(int recipeId, int servings) async {
    try {
      final response = await _apiClient.get(
        '/api/grocery-list/from-recipe/$recipeId',
        queryParameters: {'servings': servings},
      );
      return RecipeShortage.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read missing ingredients.');
    }
  }

  Future<RecipeShortage> addShortages(int recipeId, int servings) async {
    try {
      final response = await _apiClient.post(
        '/api/grocery-list/from-recipe/$recipeId',
        data: {'servings': servings},
      );
      return RecipeShortage.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message: 'Could not confirm the grocery addition. Retry safely.',
      );
    }
  }

  Future<GroceryList> removeContribution(int id) async {
    try {
      final response = await _apiClient.delete(
        '/api/grocery-list/contributions/$id',
      );
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message: 'Could not confirm removal. Refresh your groceries.',
      );
    }
  }

  final ApiClient _apiClient;

  GroceryListService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Regenerates the user's stored list from the selected Monday–Sunday week.
  /// The backend replaces items and resets purchased checks on generation.
  Future<GroceryList> generateWeek(DateTime date) async {
    final monday = mealPlanWeekStart(date);
    try {
      final response = await _apiClient.post(
        '/api/grocery-list/generate',
        data: {
          'startDate': mealPlanDate(monday),
          'endDate': mealPlanDate(mealPlanDay(monday, 6)),
        },
      );
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read your grocery list.');
    }
  }

  /// Reads stored state without regenerating or resetting purchased checks.
  Future<GroceryList> getList() async {
    try {
      final response = await _apiClient.get('/api/grocery-list');
      return GroceryList.fromJson(response.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read your grocery list.');
    }
  }

  Future<GroceryItem> toggleItem(int id) async {
    try {
      final response = await _apiClient.patch(
        '/api/grocery-list/items/$id/toggle',
      );
      final item = GroceryItem.fromJson(response.data as Map<String, dynamic>);
      if (item.id != id) {
        throw const FormatException('Unexpected grocery item.');
      }
      return item;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read the updated grocery item.');
    }
  }
}
