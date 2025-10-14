import 'package:dio/dio.dart';
import 'token_service.dart';

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

    // === Interceptor para injetar o Bearer e tratar 401 ===
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
          // token inválido/expirado → limpa e deixa a UI decidir o redirecionamento
          await TokenService.instance.clear();
        }
        handler.next(e);
      },
    ));

    return d;
  }
}
