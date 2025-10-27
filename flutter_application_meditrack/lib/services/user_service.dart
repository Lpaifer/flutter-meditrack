import '../core/api_client.dart';

class UserService {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/users/me');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> updateMe({String? name}) async {
    final r = await _dio.patch('/users/me', data: {'name': name});
    return Map<String, dynamic>.from(r.data);
  }
}
