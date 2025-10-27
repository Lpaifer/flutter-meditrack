import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_service.dart';
import 'env.dart';

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  // Preferimos API_BASE_URL; se faltar, tenta BACKEND_URL; senão cai no Env.apiBase
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: Env.apiBase, // <- seu fallback do env.dart
    ),
  );

  late final Dio dio = _build();

  Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl, // sem barra no final!
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    // 1) MOCK /auth/login (antes de qualquer outra coisa)
    if (Env.useMockAuth) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path; // ex: /auth/login
          if (path.endsWith('/auth/login')) {
            final data = options.data;
            final email = (data is Map) ? '${data['email'] ?? ''}'.trim() : '';
            final pass  = (data is Map) ? '${data['password'] ?? ''}' : '';

            if (email == Env.mockEmail && pass == Env.mockPass) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'access_token': 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
                },
              ));
            } else {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 401,
                data: {'message': 'Credenciais inválidas (mock).'},
              ));
            }
          }
          handler.next(options);
        },
      ));
    }

    // 2) Bearer + limpeza de 401
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenService.instance.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          await TokenService.instance.clear();
        }
        handler.next(e);
      },
    ));

    // 3) Log somente em debug
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ));
    }

    return dio;
  }
}
