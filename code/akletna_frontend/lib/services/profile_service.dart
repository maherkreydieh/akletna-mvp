import '../core/network/api_client.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<UserProfile> get() async => UserProfile.fromJson(
    (await _api.get('/api/users/me/profile')).data as Map<String, dynamic>,
  );
  Future<UserProfile> update(String name) async => UserProfile.fromJson(
    (await _api.put('/api/users/me/profile', data: {'name': name.trim()})).data
        as Map<String, dynamic>,
  );
}
