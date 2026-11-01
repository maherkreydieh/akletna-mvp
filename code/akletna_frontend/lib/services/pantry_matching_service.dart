import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/pantry_matches.dart';

class PantryMatchingService {
  final ApiClient _client;
  final bool minimumHalf;
  PantryMatchingService({ApiClient? apiClient, this.minimumHalf = false})
    : _client = apiClient ?? ApiClient();
  Future<PantryMatches> getMatches() async {
    final response = await _client.get(
      '/api/recipes/pantry-matches',
      queryParameters: minimumHalf ? {'minimumHalf': true} : null,
    );
    try {
      return PantryMatches.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        message: 'Could not read pantry matches. Please try again.',
      );
    }
  }
}
