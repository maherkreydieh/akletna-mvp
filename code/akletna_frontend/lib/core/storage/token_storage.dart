import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // Use encrypted shared preferences on Android (hardware-backed Keystore)

  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(),
  );

  static const String _keyJwtToken = 'jwt_token';

  /// Saves the JWT token securely
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyJwtToken, value: token);
  }

  /// Retrieves the JWT token, or returns null if not stored
  Future<String?> getToken() async {
    return await _storage.read(key: _keyJwtToken);
  }

  /// Checks if a token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Deletes the JWT token on logout
  Future<void> deleteToken() async {
    await _storage.delete(key: _keyJwtToken);
  }

  /// Clears all keys in secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
