
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/recipe.dart';
import '../models/recipe_nutrition.dart';
import '../models/food_preferences.dart';

class RecipeService {
  Future<List<Recipe>> getFilteredRecipes({
    bool community = false,
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    final response = await _apiClient.get(
      community ? '/api/recipes/community' : '/api/recipes',
      queryParameters: {
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (goals.isNotEmpty) 'goal': goals.map((g) => g.apiValue).join(','),
        if (diet != null) 'diet': diet.apiValue,
      },
    );
    try {
      return (response.data as List)
          .map((v) => Recipe.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException(message: 'Could not read filtered recipes.');
    }
  }

  final ApiClient _apiClient;

  RecipeService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<Recipe>> getSavedRecipes() =>
      _getCollection('/api/recipes/saved');

  Future<void> saveRecipe(int id) async {
    await _apiClient.put('/api/recipes/$id/save', data: <String, dynamic>{});
  }

  Future<void> unsaveRecipe(int id) async {
    await _apiClient.delete('/api/recipes/$id/save');
  }

  Future<List<Recipe>> getCommunityRecipes() =>
      _getCollection('/api/recipes/community');

  Future<List<Recipe>> getAvailableRecipes() =>
      _getCollection('/api/recipes/available');

  Future<List<Recipe>> _getCollection(String path) async {
    final response = await _apiClient.get(path);
    try {
      return (response.data as List)
          .map((json) => Recipe.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException(message: 'Could not read the recipe response.');
    }
  }

  Future<RecipeNutrition> getNutrition(int id) async {
    final response = await _apiClient.get('/api/recipes/$id/nutrition');
    try {
      return RecipeNutrition.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(message: 'Could not read nutrition information.');
    }
  }

  Future<List<Recipe>> getMyRecipes() async {
    final response = await _apiClient.get('/api/recipes/mine');
    try {
      return (response.data as List)
          .map((json) => Recipe.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException(message: 'Could not read your recipes.');
    }
  }

  Future<Recipe> updateRecipe(int id, Map<String, dynamic> request) async {
    final response = await _apiClient.put('/api/recipes/$id', data: request);
    try {
      return Recipe.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read the saved recipe. Reload before trying again.',
      );
    }
  }

  Future<void> deleteRecipe(int id) async {
    await _apiClient.delete('/api/recipes/$id');
  }

  /// Metadata and ingredient lines are saved atomically by the backend.
  Future<Recipe> createRecipe(Map<String, dynamic> request) async {
    final response = await _apiClient.post('/api/recipes', data: request);
    try {
      return Recipe.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read the saved recipe. Refresh the catalog before trying again.',
      );
    }
  }

  /// Fetches the recipe list from GET /api/recipes
  Future<List<Recipe>> getRecipes() async {
    try {
      final response = await _apiClient.get('/api/recipes');
      final list = response.data as List<dynamic>;
      return list
          .map((json) => Recipe.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read the recipe response.');
    }
  }

  /// Recipe metadata and lines have separate, owner-protected endpoints.
  Future<Recipe> getRecipeById(int id) async {
    try {
      final response = await _apiClient.get('/api/recipes/$id');
      final ingredientsResponse = await _apiClient.get(
        '/api/recipes/$id/ingredients',
      );
      final ingredients = (ingredientsResponse.data as List<dynamic>)
          .map(
            (json) => RecipeIngredient.fromJson(json as Map<String, dynamic>),
          )
          .toList();
      return Recipe.fromJson(
        response.data as Map<String, dynamic>,
        ingredients: ingredients,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Could not read the recipe detail response.');
    }
  }
}
