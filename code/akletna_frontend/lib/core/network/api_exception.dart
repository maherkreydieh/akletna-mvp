import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;

  /// Factory method to translate low-level DioException into user-friendly ApiException
  factory ApiException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Connection timed out. Please check your internet connection.',
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Could not connect. Check your connection and try again.',
        );

      case DioExceptionType.badResponse:
        final response = dioException.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        // Try extracting error message sent from Spring Boot if available
        String errorMessage = 'Something went wrong. Please try again.';

        if (data is Map<String, dynamic>) {
          if (data.containsKey('message') && data['message'] != null) {
            errorMessage = data['message'].toString();
          } else if (data.containsKey('error') && data['error'] != null) {
            errorMessage = data['error'].toString();
          }
        }
        // Keep helpful validation text, never display proxy pages or technical diagnostics.
        if (errorMessage.length > 250 ||
            RegExp(
              r'https?://|<[^>]+>|[{}]|Exception|StackTrace|SQL|DioError|java\.|org\.',
              caseSensitive: false,
            ).hasMatch(errorMessage)) {
          errorMessage = 'Please check your details and try again.';
        }

        switch (statusCode) {
          case 400:
            return ApiException(
              message: errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Invalid request.',
              statusCode: 400,
            );
          case 401:
            return ApiException(
              message: 'Invalid credentials or session expired. Please log in again.',
              statusCode: 401,
            );
          case 403:
            return ApiException(message: 'Access denied.', statusCode: 403);
          case 404:
            return ApiException(
              message: 'The requested resource was not found.',
              statusCode: 404,
            );
          case 409:
            return ApiException(
              message: errorMessage.isNotEmpty
                  ? errorMessage
                  : 'A conflict occurred. This email may already be in use.',
              statusCode: 409,
            );
          case 500:
          default:
            return ApiException(
              message: 'Server error occurred. Please try again later.',
              statusCode: statusCode,
            );
        }

      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');

      case DioExceptionType.unknown:
      default:
        return ApiException(message: 'An unexpected network error occurred.');
    }
  }
}
