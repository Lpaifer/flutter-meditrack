import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/token_service.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  String? _pickToken(dynamic data) {
    if (data is Map) {
      final t1 = data['access_token'];
      if (t1 is String && t1.isNotEmpty) return t1;

      final t2 = data['token'];
      if (t2 is String && t2.isNotEmpty) return t2;

      final nested = data['data'];
      if (nested is Map) return _pickToken(nested);
    }
    return null;
  }

  Future<String> login(String email, String password) async {
    final r = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = _pickToken(r.data);
    if (token == null || token.isEmpty) {
      throw Exception('Token ausente no login');
    }

    await TokenService.instance.setToken(token);
    return token;
  }

  /// Alguns backends já retornam token no register; se vier, salva e retorna.
  /// Se retornar `null`, faça login em seguida (como sua RegisterPage já faz).
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final r = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });

    final token = _pickToken(r.data);
    if (token != null && token.isNotEmpty) {
      await TokenService.instance.setToken(token);
    }
    return token;
  }

  Future<void> logout() async {
    await TokenService.instance.clear();
  }
}
