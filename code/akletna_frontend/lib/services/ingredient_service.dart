import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/ingredient.dart';

class IngredientService {
  final ApiClient _client;
  IngredientService({ApiClient? apiClient})
    : _client = apiClient ?? ApiClient();
  Future<List<Ingredient>> getIngredients() async {
    final response = await _client.get('/api/ingredients');
    try {
      return (response.data as List)
          .map((item) => Ingredient.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException(message: 'Could not read available ingredients.');
    }
  }

  Future<Ingredient> createIngredient(String name, String unit) async {
    final response = await _client.post(
      '/api/ingredients',
      data: {'name': name.trim(), 'unit': unit.trim()},
    );
    try {
      return Ingredient.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read the ingredient response. Refresh before trying again.',
      );
    }
  }
}
