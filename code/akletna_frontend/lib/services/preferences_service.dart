import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/food_preferences.dart';

class PreferencesService {
  final ApiClient _client;
  PreferencesService({ApiClient? apiClient})
    : _client = apiClient ?? ApiClient();
  Future<FoodPreferences> getPreferences() async =>
      _parse((await _client.get('/api/preferences')).data);
  Future<FoodPreferences> save(FoodPreferences preferences) async => _parse(
    (await _client.put(
      '/api/preferences',
      data: preferences.toRequestJson(),
    )).data,
  );
  FoodPreferences _parse(dynamic json) {
    try {
      return FoodPreferences.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read your dietary settings. Please reload.',
      );
    }
  }
}
