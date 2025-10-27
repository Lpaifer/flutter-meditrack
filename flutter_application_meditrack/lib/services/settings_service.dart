import 'package:dio/dio.dart';
import 'package:flutter_application_meditrack/core/api_client.dart';

class SettingsService {
  final Dio _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me/preferences');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return {}; // se o back devolver null/empty
  }

  Future<void> save(Map<String, dynamic> body) async {
    await _dio.put(
      '/users/me/preferences',
      data: _deepPrune(body),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  dynamic _deepPrune(dynamic v) {
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, val) {
        final p = _deepPrune(val);
        final emptyStr = p is String && p.trim().isEmpty;
        final emptyList = p is List && p.isEmpty;
        final emptyMap = p is Map && p.isEmpty;
        if (p == null || emptyStr || emptyList || emptyMap) return;
        out[k] = p;
      });
      return out;
    }
    if (v is List) {
      return v.map(_deepPrune).where((e) {
        if (e == null) return false;
        if (e is String && e.trim().isEmpty) return false;
        if (e is List && e.isEmpty) return false;
        if (e is Map && e.isEmpty) return false;
        return true;
      }).toList();
    }
    return v;
  }
}
