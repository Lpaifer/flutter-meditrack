// lib/services/user_profile_service.dart
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/env.dart';

class UserProfileService {
  final Dio _dio = ApiClient.instance.dio;

  UserProfileService() {
    _dio.options
      ..baseUrl = Env.apiBase
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 25);
  }

  // ---------- USERS BASIC ----------
  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Envia endereço em **PT** (loga/num/bairro/cidade/uf/cep/pais)
  Future<Map<String, dynamic>> patchMePT({
    required String name,
    String? email, // se o backend não editar email, passe null
    String? phone,
    DateTime? birthDate,
    required Map<String, String> addressPT,
  }) async {
    final body = {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (birthDate != null) 'birthDate': birthDate.toUtc().toIso8601String(),
      'address': {
        'logradouro': addressPT['logradouro'],
        'numero': addressPT['numero'],
        'bairro': addressPT['bairro'],
        'cidade': addressPT['cidade'],
        'uf': addressPT['uf'],
        'cep': addressPT['cep'],
        'pais': addressPT['pais'],
      },
    };

    final res = await _dio.patch('/users/me', data: _deepPrune(body));
    final data = res.data;
    return (data is Map) ? Map<String, dynamic>.from(data) : {};
  }

  // ---------- HEALTH ----------
  /// Lê campos **PT** e normaliza para o app
  Future<Map<String, dynamic>> getHealthPT() async {
    final res = await _dio.get('/users/me/health');
    final Map<String, dynamic> data =
        (res.data is Map) ? Map<String, dynamic>.from(res.data) : {};

    return {
      // listas
      'alergias': List<String>.from((data['alergias'] ?? const []) as List),
      'condicoesCronicas':
          List<String>.from((data['condicoesCronicas'] ?? const []) as List),
      'intoleranciasMedicamentos':
          List<String>.from((data['intoleranciasMedicamentos'] ?? const []) as List),
      // números/texto
      'alturaCm': (data['alturaCm']),
      'pesoKg': (data['pesoKg']),
      'obs': (data['obs'] ?? '') as String,
      // equipe médica (um único médico opcional)
      'medico': (data['medTeam'] is Map && (data['medTeam'] as Map)['medico'] is Map)
          ? Map<String, dynamic>.from((data['medTeam'] as Map)['medico'])
          : null,
    };
  }

  /// Envia **PT na raiz** e **um único médico** (se existir)
  Future<void> putHealthPT({
    required List<String> alergias,
    required List<String> condicoesCronicas,
    required List<String> intoleranciasMedicamentos,
    double? alturaCm,
    double? pesoKg,
    String? obs,
    Map<String, String>? medico, // {nome, crm, contato}
  }) async {
    final body = {
      'alergias': alergias,
      'condicoesCronicas': condicoesCronicas,
      'intoleranciasMedicamentos': intoleranciasMedicamentos,
      if (alturaCm != null) 'alturaCm': alturaCm,
      if (pesoKg != null) 'pesoKg': pesoKg,
      if (obs != null) 'obs': obs,
      // schema: { medTeam: { medico: { nome, crm, contato } } }
      if (medico != null)
        'medTeam': {
          'medico': {
            'nome': medico['nome'],
            'crm': medico['crm'],
            'contato': medico['contato'],
          }
        },
    };

    await _dio.put('/users/me/health', data: _deepPrune(body));
  }

  // ---------- helpers ----------
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
