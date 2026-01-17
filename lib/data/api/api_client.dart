import 'package:dio/dio.dart';

import '../../app/config.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenProvider tokenProvider,
  })  : _tokenProvider = tokenProvider,
        dio = Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenProvider();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenProvider _tokenProvider;
}
