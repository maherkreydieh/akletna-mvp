import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/recommendations.dart';
import '../models/food_preferences.dart';

class RecommendationService {
  final ApiClient _client;
  RecommendationService({ApiClient? apiClient})
    : _client = apiClient ?? ApiClient();
  Map<String, dynamic> _filters(
    String? category,
    Set<MealGoal> goals,
    DietaryPreference? diet,
  ) => {
    if (category != null && category.trim().isNotEmpty)
      'category': category.trim(),
    if (goals.isNotEmpty) 'goal': goals.map((goal) => goal.apiValue).join(','),
    if (diet != null) 'diet': diet.apiValue,
  };

  Future<HomeRecommendations> getHomeRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    final response = await _client.get(
      '/api/recipes/recommendations/home',
      queryParameters: _filters(category, goals, diet),
    );
    try {
      return HomeRecommendations.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (_) {
      throw ApiException(
        message: 'Could not read recommendations. Please refresh.',
      );
    }
  }

  Future<Recommendations> getRecommendations({
    String? category,
    Set<MealGoal> goals = const {},
    DietaryPreference? diet,
  }) async {
    final response = await _client.get(
      '/api/recipes/recommendations',
      queryParameters: _filters(category, goals, diet),
    );
    try {
      return Recommendations.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read recommendations. Please refresh.',
      );
    }
  }
}
