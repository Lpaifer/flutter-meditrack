import 'package:dio/dio.dart';
import 'token_service.dart';
import 'env.dart';

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const backend = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://nestjs-meditrack.onrender.com',
  );

  late final Dio dio = _build();

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: backend,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));

    // === 1) MOCK /auth/login (antes dos demais interceptors) ===
    if (Env.useMockAuth) {
      d.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Checa a rota; options.uri.path inclui o baseUrl + path resolvido
          final path = options.uri.path; // ex: /auth/login
          if (path.endsWith('/auth/login')) {
            final data = options.data;
            String email = '';
            String pass  = '';

            if (data is Map) {
              email = '${data['email'] ?? ''}'.trim();
              pass  = '${data['password'] ?? ''}';
            }

            if (email == Env.mockEmail && pass == Env.mockPass) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'access_token': 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
                  },
                ),
              );
            } else {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'message': 'Credenciais inválidas (mock).'},
                ),
              );
            }
          }

          handler.next(options);
        },
      ));
    }

    // === 2) Bearer + limpeza de 401 (se for request real) ===
    d.interceptors.add(InterceptorsWrapper(
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

    return d;
  }
}
