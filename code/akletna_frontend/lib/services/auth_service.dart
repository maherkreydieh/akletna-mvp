import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/auth_request.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  /// POST /api/auth/register
  Future<void> register(RegisterRequest request) async {
    await _apiClient.post('/api/auth/register', data: request.toJson());
  }

  /// POST /api/auth/login
  Future<AuthResponse> login(LoginRequest request) async {
    // An unsuccessful account switch must not leave the previous account active.
    await _tokenStorage.deleteToken();
    final response = await _apiClient.post(
      '/api/auth/login',
      data: request.toJson(),
    );

    final authResponse = AuthResponse.fromJson(
      response.data as Map<String, dynamic>,
    );

    // Securely persist the JWT token for future requests
    if (authResponse.token.trim().isEmpty) {
      throw ApiException(
        message: 'The server did not provide a valid session.',
      );
    }
    await _tokenStorage.saveToken(authResponse.token);

    return authResponse;
  }

  /// GET /api/users/me (protected endpoint, token attached via ApiClient interceptor)
  Future<User> getCurrentUser() async {
    final response = await _apiClient.get('/api/users/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Clear session
  Future<void> logout() async {
    await _tokenStorage.deleteToken();
  }
}
