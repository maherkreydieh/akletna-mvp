import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/pantry_item.dart';

class PantryService {
  final ApiClient _client;
  PantryService({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();
  PantryItem _read(dynamic data) {
    try {
      return PantryItem.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read your pantry. Refresh before trying again.',
      );
    }
  }

  Future<List<PantryItem>> getPantry() async {
    final response = await _client.get('/api/pantry');
    try {
      return (response.data as List).map(_read).toList();
    } catch (_) {
      throw ApiException(message: 'Could not read your pantry.');
    }
  }

  Future<PantryItem> add(
    int ingredientId, {
    String? quantity,
    String? unit,
  }) async {
    final response = await _client.post(
      '/api/pantry',
      data: {'ingredientId': ingredientId, 'quantity': quantity, 'unit': unit},
    );
    return _read(response.data);
  }

  Future<PantryItem> update(int id, {String? quantity, String? unit}) async {
    final response = await _client.put(
      '/api/pantry/$id',
      data: {'quantity': quantity, 'unit': unit},
    );
    return _read(response.data);
  }

  Future<void> remove(int id) async {
    await _client.delete('/api/pantry/$id');
  }
}
