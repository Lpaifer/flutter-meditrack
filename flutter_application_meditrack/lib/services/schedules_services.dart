import '../core/api_client.dart';

class Schedule {
  final String id;
  final String medicationId;
  final int dose;
  final DateTime? nextAt;
  final bool enabled;

  Schedule({
    required this.id,
    required this.medicationId,
    required this.dose,
    required this.nextAt,
    required this.enabled,
  });

  factory Schedule.fromJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id'] ?? '').toString();
    final medId = (j['medicationId'] ?? j['medication'] ?? '').toString();
    final rawDose = j['dose'] ?? 0;
    final dose = rawDose is int ? rawDose : int.tryParse(rawDose.toString()) ?? 0;
    final enabled = (j['enabled'] ?? true) == true;
    final next = j['nextAt']?.toString();
    return Schedule(
      id: id,
      medicationId: medId,
      dose: dose,
      nextAt: next != null ? DateTime.tryParse(next) : null,
      enabled: enabled,
    );
  }
}

class SchedulesService {
  final _dio = ApiClient.instance.dio;

  Future<List<Schedule>> list() async {
    final r = await _dio.get('/schedules'); // seu back já retorna [] puro
    final data = r.data;
    final List items = data is List ? data : (data is Map && data['value'] is List ? data['value'] : const []);
    return items
        .whereType<Map>()
        .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Schedule> create({
    required String medicationId,
    required int dose,
    required DateTime nextAt,
  }) async {
    final r = await _dio.post('/schedules', data: {
      'medicationId': medicationId, // exatamente como o back espera
      'dose': dose,
      'nextAt': nextAt.toIso8601String(),
      // enabled fica true por padrão no back
    });
    return Schedule.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<Schedule> update(String id, {int? dose, DateTime? nextAt, bool? enabled}) async {
    final patch = <String, dynamic>{};
    if (dose != null) patch['dose'] = dose;
    if (nextAt != null) patch['nextAt'] = nextAt.toIso8601String();
    if (enabled != null) patch['enabled'] = enabled;

    final r = await _dio.patch('/schedules/$id', data: patch);
    return Schedule.fromJson(Map<String, dynamic>.from(r.data));
  }
}
