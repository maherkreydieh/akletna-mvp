import 'dart:typed_data';

import 'package:akletna_frontend/core/network/api_client.dart';
import 'package:akletna_frontend/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_service_test.dart' show MemoryTokenStorage;

class FixtureAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) respond;
  FixtureAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status) => ResponseBody.fromString(
  '{}',
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  test('secure storage failure completes with an error without sending a request', () async {
    var sent = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = FixtureAdapter((_) {
      sent = true;
      return jsonResponse(200);
    });
    final client = ApiClient(tokenStorage: FailingTokenStorage(), dio: dio);
    await expectLater(client.get('/api/recipes').timeout(const Duration(seconds: 2)),
        throwsA(isA<ApiException>()));
    expect(sent, isFalse);
    // Public authentication does not depend on reading a broken saved session.
    await client.post('/api/auth/login');
    expect(sent, isTrue);
    dio.close();
  });
  test(
    'auth requests omit the saved session; business requests include it',
    () async {
      final storage = MemoryTokenStorage('test-session');
      final headers = <dynamic>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.httpClientAdapter = FixtureAdapter((options) {
        headers.add(options.headers['Authorization']);
        return jsonResponse(200);
      });
      final client = ApiClient(tokenStorage: storage, dio: dio);
      await client.post('/api/auth/login');
      await client.get('/api/recipes');
      expect(headers, [null, 'Bearer test-session']);
      dio.close();
    },
  );

  test('401 clears the rejected session, while a network/server error preserves it', () async {
    final storage = MemoryTokenStorage('test-session');
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = FixtureAdapter((_) => jsonResponse(500));
    final client = ApiClient(tokenStorage: storage, dio: dio);
    await expectLater(client.get('/api/recipes'), throwsA(isA<ApiException>()));
    expect(storage.token, 'test-session');
    dio.httpClientAdapter = FixtureAdapter((_) => jsonResponse(401));
    await expectLater(client.get('/api/recipes'), throwsA(isA<ApiException>()));
    expect(storage.token, isNull);
    dio.close();
  });

  test('a stale 401 does not erase a newer login session', () async {
    final storage = MemoryTokenStorage('old-session');
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = FixtureAdapter((_) {
      storage.token = 'new-session';
      return jsonResponse(401);
    });
    final client = ApiClient(tokenStorage: storage, dio: dio);
    await expectLater(client.get('/api/recipes'), throwsA(isA<ApiException>()));
    expect(storage.token, 'new-session');
    dio.close();
  });
}

class FailingTokenStorage extends MemoryTokenStorage {
  @override
  Future<String?> getToken() async => throw StateError('Storage unavailable');
}
