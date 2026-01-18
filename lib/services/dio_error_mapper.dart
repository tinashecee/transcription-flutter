import 'package:dio/dio.dart';

String mapDioError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check the API server.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending data.';
      case DioExceptionType.receiveTimeout:
        return 'Request timed out while waiting for data.';
      case DioExceptionType.connectionError:
        return 'Network error. Please check your connection.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return 'Unauthorized. Please log in again.';
        if (status == 403) return 'Access denied.';
        if (status == 404) return 'Resource not found.';
        if (status != null && status >= 500) {
          return 'Server error. Please try again later.';
        }
        return 'Request failed (HTTP $status).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'Certificate error. Please check the server certificate.';
      case DioExceptionType.unknown:
        return 'Unexpected network error.';
    }
  }
  return 'Unexpected error.';
}
