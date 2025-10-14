import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  TokenService._();
  static final instance = TokenService._();

  final _storage = const FlutterSecureStorage();
  String? _cached; // cache em memória pra evitar IO em cada request

  Future<void> setToken(String token) async {
    _cached = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    if (_cached != null) return _cached;
    _cached = await _storage.read(key: 'auth_token');
    return _cached;
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: 'auth_token');
  }

  // útil no Splash para hidratar o cache logo no start
  Future<void> hydrate() async {
    _cached = await _storage.read(key: 'auth_token');
  }

  bool get hasCachedToken => _cached != null && _cached!.isNotEmpty;
}
