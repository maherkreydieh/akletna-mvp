import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;

  ApiClient({TokenStorage? tokenStorage, Dio? dio})
    : _tokenStorage = tokenStorage ?? TokenStorage() {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    // Inject a stored token only for protected business requests.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (!options.path.startsWith('/api/auth/')) {
              final token = await _tokenStorage.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
          } catch (_) {
            handler.reject(DioException(
              requestOptions: options,
              message: 'Unable to read the saved session. Please try again.',
            ));
            return;
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          try {
            if (e.response?.statusCode == 401) {
              final token = await _tokenStorage.getToken();
              // Avoid deleting a newer login's token after an older request fails.
              if (token != null &&
                  e.requestOptions.headers['Authorization'] ==
                      'Bearer $token') {
                await _tokenStorage.deleteToken();
              }
            }
          } catch (_) {
            // Preserve the original network failure if secure storage fails.
          }
          return handler.next(e);
        },
      ),
    );
  }

  // GET request wrapper
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // POST request wrapper
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // PUT request wrapper
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // PATCH request wrapper
  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // DELETE request wrapper
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
