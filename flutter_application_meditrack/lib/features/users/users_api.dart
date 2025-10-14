import '../../core/api_client.dart';

class UsersApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/users/me');
    return Map<String, dynamic>.from(r.data);
  }
}
