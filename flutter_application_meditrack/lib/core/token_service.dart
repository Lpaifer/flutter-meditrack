import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  TokenService._();
  static final instance = TokenService._();

  static const _key = 'auth_token';

  /// Observável para UI/serviços poderem reagir (ex.: redirecionar ao expirar).
  /// Ex.: TokenService.instance.tokenNotifier.addListener(() { ... })
  final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);

  // Opções seguras por plataforma (ajuste se necessário)
  static const _android = AndroidOptions(encryptedSharedPreferences: true);
  static const _ios     = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  // Se for usar Web/Linux/Mac/Windows, pode habilitar:
  // static const _web    = WebOptions(dbName: 'meditrack_secure');
  // static const _linux  = LinuxOptions(collectionName: 'meditrack');
  // static const _mac    = MacOsOptions(accessibility: KeychainAccessibility.first_unlock);
  // static const _win    = WindowsOptions(); // (usa DPAPI)

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _android,
    iOptions: _ios,
    // webOptions: _web,
    // linuxOptions: _linux,
    // mOptions: _mac,
    // windowsOptions: _win,
  );

  String? _cached; // cache em memória para evitar IO em cada request

  Future<void> setToken(String token) async {
    _cached = token;
    tokenNotifier.value = token;
    await _storage.write(key: _key, value: token);
  }

  Future<String?> getToken() async {
    if (_cached != null) return _cached;
    final v = await _storage.read(key: _key);
    _cached = v;
    tokenNotifier.value = v;
    return v;
  }

  Future<bool> hasToken() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    _cached = null;
    tokenNotifier.value = null;
    await _storage.delete(key: _key);
  }

  Future<void> hydrate() async {
    _cached = await _storage.read(key: _key);
    tokenNotifier.value = _cached;
  }

  bool get hasCachedToken => _cached != null && _cached!.isNotEmpty;
}
