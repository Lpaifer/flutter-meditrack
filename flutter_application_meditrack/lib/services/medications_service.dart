import 'package:dio/dio.dart';
import '../core/api_client.dart';

class Medication {
  final String id;
  final String name;
  final String unit; // <- existe no back
  final int stock;

  Medication({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
  });

  factory Medication.fromJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id'] ?? '').toString();
    final name = (j['name'] ?? j['nome'] ?? '').toString();
    final unit = (j['unit'] ?? j['unidade'] ?? 'pill').toString();
    final raw = j['stock'] ?? j['estoque'] ?? 0;
    final stock = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    return Medication(id: id, name: name, unit: unit, stock: stock);
  }
}

class MedicationsService {
  final Dio _dio = ApiClient.instance.dio;

  /// Lê a lista do back. Ele pode vir como {"value":[...], "Count":N} ou [] puro.
  Future<List<Medication>> list() async {
    final r = await _dio.get('/medications');
    final data = r.data;

    final List items;
    if (data is List) {
      items = data;
    } else if (data is Map && data['value'] is List) {
      items = data['value'] as List;
    } else {
      items = const [];
    }

    return items
        .whereType<Map>()
        .map((e) => Medication.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Cria um medicamento. No back, 'unit' é importante – mande um default.
  Future<Medication> create({
    required String name,
    required int stock,
    String unit = 'pill', // ou 'tablet', conforme seu domínio
  }) async {
    final r = await _dio.post('/medications', data: {
      'name': name,
      'unit': unit,
      'stock': stock,
    });
    return Medication.fromJson(Map<String, dynamic>.from(r.data));
  }

  /// Atualiza campos suportados pelo back (name, unit, stock).
  Future<Medication> update(String id, {String? name, String? unit, int? stock}) async {
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (unit != null) patch['unit'] = unit;
    if (stock != null) patch['stock'] = stock;

    final r = await _dio.patch('/medications/$id', data: patch);
    return Medication.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> remove(String id) async {
    await _dio.delete('/medications/$id');
  }

  /// (Opcional) se você quiser usar o endpoint de reabastecer que o back mapeia:
  /// POST /medications/:id/refill  { amount: number }
  Future<Medication> refill(String id, int amount) async {
    final r = await _dio.post('/medications/$id/refill', data: {'amount': amount});
    return Medication.fromJson(Map<String, dynamic>.from(r.data));
  }
}
