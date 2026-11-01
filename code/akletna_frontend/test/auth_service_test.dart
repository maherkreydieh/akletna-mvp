import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:akletna_frontend/core/storage/token_storage.dart';
import 'package:akletna_frontend/models/auth_request.dart';
import 'package:akletna_frontend/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStorage extends TokenStorage {
  String? token;
  MemoryTokenStorage([this.token]);
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

class LoginApiClient extends ApiClient {
  final String responseToken;
  LoginApiClient(this.responseToken);
  @override
  Future<Response<dynamic>> post(String path, {dynamic data}) async => Response(
    data: {
      'token': responseToken,
      'email': 'owner@example.test',
      'name': 'Test User',
    },
    requestOptions: RequestOptions(path: path),
  );
}

void main() {
  final request = LoginRequest(
    email: 'owner@example.test',
    password: 'test-password',
  );
  test('successful login persists a session and logout clears it', () async {
    final storage = MemoryTokenStorage('previous-session');
    final auth = AuthService(
      apiClient: LoginApiClient('test-session'),
      tokenStorage: storage,
    );
    await auth.login(request);
    expect(storage.token, 'test-session');
    await auth.logout();
    expect(storage.token, isNull);
  });

  test('empty session response is rejected and never persisted', () async {
    final storage = MemoryTokenStorage('previous-session');
    final auth = AuthService(
      apiClient: LoginApiClient('  '),
      tokenStorage: storage,
    );
    await expectLater(auth.login(request), throwsA(isA<ApiException>()));
    expect(storage.token, isNull);
  });
}
