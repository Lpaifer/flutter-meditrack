import '../core/api_client.dart';

class PasswordResetService {
  final _dio = ApiClient.instance.dio;

  Future<void> sendCode(String email) async {
    await _dio.post('/password-reset/send-code', data: {'email': email});
  }

  Future<void> verifyCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post('/password-reset/verify-code', data: {
      'email': email, 'code': code, 'newPassword': newPassword,
    });
  }
}
