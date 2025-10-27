import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/core/notifications_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/core/api_client.dart';
import 'package:flutter_application_meditrack/core/env.dart';

// ================== MODELOS (UI) ==================

class Medicine {
  String medicationId;     // id no backend
  String? scheduleId;      // agenda "vigente" (a mais próxima futura)
  String name;
  int freqHours;           // frequência (intervalo) em horas entre doses
  int dosePills;           // quantidade por dose (exibimos como "doses")
  int pillsInDispenser;    // estoque atual (exibimos como "doses")
  TimeOfDay? startAt;      // hora inicial escolhida no formulário

  Medicine({
    required this.medicationId,
    required this.scheduleId,
    required this.name,
    required this.freqHours,
    required this.dosePills,
    required this.pillsInDispenser,
    this.startAt,
  });

  Medicine copyWith({
    String? medicationId,
    String? scheduleId,
    String? name,
    int? freqHours,
    int? dosePills,
    int? pillsInDispenser,
    TimeOfDay? startAt,
  }) {
    return Medicine(
      medicationId: medicationId ?? this.medicationId,
      scheduleId: scheduleId ?? this.scheduleId,
      name: name ?? this.name,
      freqHours: freqHours ?? this.freqHours,
      dosePills: dosePills ?? this.dosePills,
      pillsInDispenser: pillsInDispenser ?? this.pillsInDispenser,
      startAt: startAt ?? this.startAt,
    );
  }
}

// DTOs simples do backend
class _MedicationDto {
  final String id;
  final String name;
  final int stock;

  _MedicationDto({required this.id, required this.name, required this.stock});

  factory _MedicationDto.fromJson(Map<String, dynamic> j) => _MedicationDto(
        id: (j['_id'] ?? j['id']).toString(),
        name: (j['name'] ?? 'Medicamento').toString(),
        stock: (j['stock'] is int)
            ? j['stock'] as int
            : int.tryParse('${j['stock'] ?? 0}') ?? 0,
      );
}

class _ScheduleDto {
  final String id;
  final String medicationId;
  final num dose;
  final DateTime nextAt;
  final bool enabled;

  _ScheduleDto({
    required this.id,
    required this.medicationId,
    required this.dose,
    required this.nextAt,
    required this.enabled,
  });

  factory _ScheduleDto.fromJson(Map<String, dynamic> j) => _ScheduleDto(
        id: (j['_id'] ?? j['id']).toString(),
        medicationId: (j['medicationId'] ?? '').toString(),
        dose: (j['dose'] ?? 0) as num,
        nextAt: DateTime.parse(j['nextAt'].toString()).toLocal(),
        enabled: (j['enabled'] ?? true) == true,
      );
}

// ================== PÁGINA ==================

class DosesPage extends StatefulWidget {
  const DosesPage({super.key});

  @override
  State<DosesPage> createState() => _DosesPageState();
}

class _DosesPageState extends State<DosesPage> {
  final Dio _dio = ApiClient.instance.dio;

  final List<Medicine> _items = [];
  bool _loading = true;
  String? _loadError;

  // aviso amigável caso não consiga programar notificações (ex.: exatas desabilitadas)
  String? _notifWarning;

  @override
  void initState() {
    super.initState();
    _dio.options.baseUrl = Env.apiBase;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 25);

    NotificationsService.instance.init(); // segurança extra
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _notifWarning = null;
      _items.clear();
    });

    try {
      final medsRes = await _retryOnceIfWakeUp(() => _dio.get('/medications'));
      final schRes  = await _retryOnceIfWakeUp(() => _dio.get('/schedules'));

      // medications pode vir [] OU {"value":[...], "Count": N}
      final dynamic medsData = medsRes.data;
      final List medsRaw = medsData is List
          ? medsData
          : (medsData is Map && medsData['value'] is List ? medsData['value'] as List : const []);

      final meds = medsRaw
          .whereType<Map>()
          .map((e) => _MedicationDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final now = DateTime.now();
      final List schRaw = schRes.data is List ? schRes.data as List : const [];
      final schedules = schRaw
          .whereType<Map>()
          .map((e) => _ScheduleDto.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.enabled && s.nextAt.isAfter(now))
          .toList();

      // agenda futura mais próxima por medicamento
      final Map<String, _ScheduleDto> earliestByMed = {};
      for (final s in schedules) {
        final current = earliestByMed[s.medicationId];
        if (current == null || s.nextAt.isBefore(current.nextAt)) {
          earliestByMed[s.medicationId] = s;
        }
      }

      final newItems = <Medicine>[];
      for (final med in meds) {
        final s = earliestByMed[med.id];
        if (s == null) continue; // sem agenda futura: esconde
        final diff = s.nextAt.difference(now);
        final remainingHours = ((diff.inMinutes + 59) ~/ 60); // arredonda pra cima
        newItems.add(Medicine(
          medicationId: med.id,
          scheduleId: s.id,
          name: med.name,
          freqHours: remainingHours,
          dosePills: s.dose.toInt(),
          pillsInDispenser: med.stock,
        ));
      }

      // Agendar notificações — SEM travar a tela em caso de falha
      try {
        await _scheduleAllNotifications(schedules, meds);
        final exactOk = await NotificationsService.instance.areExactAlarmsAllowed();
        if (!exactOk) {
          _notifWarning = 'Para alertas no horário exato, ative “Alarmes e lembretes” nas permissões do app.';
        }
      } catch (_) {
        _notifWarning = 'Não foi possível programar os lembretes agora.';
      }

      setState(() {
        _items.addAll(newItems);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        _loadError = _errorFromDio(e);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Erro inesperado: $e';
      });
    }
  }

  // ======= Notificações =======

  Future<void> _scheduleAllNotifications(
    List<_ScheduleDto> schedules,
    List<_MedicationDto> meds,
  ) async {
    final nameById = {for (final m in meds) m.id: m.name};

    // Limpa antigos pra não duplicar
    await NotificationsService.instance.clearDoseReminders();

    final now = DateTime.now();
    final upcoming = schedules
        .where((s) => s.enabled && s.nextAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.nextAt.compareTo(b.nextAt));

    for (final s in upcoming.take(50)) {
      final name = nameById[s.medicationId] ?? 'Medicamento';
      await NotificationsService.instance.scheduleDoseReminder(
        scheduleId: s.id,
        when: s.nextAt,       // já está em local time na factory
        medName: name,
        dose: s.dose,
      );
    }
  }

  // ======= Cálculo de nextAt a partir da hora inicial + frequência =======

  DateTime _computeNextFromStart(TimeOfDay? start, int freqHours) {
    final nowLocal = DateTime.now();
    DateTime cursor;

    if (start != null) {
      cursor = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        start.hour,
        start.minute,
      );
    } else {
      cursor = nowLocal; // fallback
    }

    final step = Duration(hours: freqHours);
    while (!cursor.isAfter(nowLocal)) {
      cursor = cursor.add(step);
      if (step.inMinutes <= 0) break;
    }
    return cursor; // local
  }

  // ======= AÇÕES =======

  void _openAddMedicineSheet() async {
    final created = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => const _MedicineFormSheet(title: 'Novo remédio'),
    );

    if (!mounted || created == null) return;

    try {
      // 1) Cria o medicamento  (unit é OBRIGATÓRIO no back)
      final medRes = await _retryOnceIfWakeUp(() => _dio.post('/medications', data: {
            'name': created.name,
            'unit': 'pill', // manter compatível com o back
            'stock': created.pillsInDispenser,
          }));
      final med = medRes.data as Map;
      final medId = (med['_id'] ?? med['id'])?.toString();
      if (medId == null) throw Exception('Criação de medicamento sem ID.');

      // 2) Cria a agenda usando Hora inicial + Frequência
      final nextLocal = _computeNextFromStart(created.startAt, created.freqHours);
      final schedRes = await _dio.post('/schedules', data: {
        'medicationId': medId,
        'dose': created.dosePills,
        'nextAt': nextLocal.toUtc().toIso8601String(), // UTC
      });

      // Agenda notificação local imediatamente após criar (sem travar a UX)
      try {
        final sMap = (schedRes.data is Map) ? (schedRes.data as Map) : <String, dynamic>{};
        final sId  = (sMap['_id'] ?? sMap['id'])?.toString() ??
                     'tmp-$medId-${nextLocal.millisecondsSinceEpoch}';
        final when = (sMap['nextAt'] != null)
            ? DateTime.parse(sMap['nextAt'].toString()).toLocal()
            : nextLocal;
        await NotificationsService.instance.scheduleDoseReminder(
          scheduleId: sId,
          when: when,
          medName: created.name,
          dose: created.dosePills,
        );
      } catch (_) {
        setState(() => _notifWarning = 'Não foi possível programar o lembrete agora.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remédio salvo: ${created.name}')),
      );
      _loadAll();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorFromDio(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  void _openEditMedicineSheet({required int index}) async {
    final initial = _items[index];
    final edited = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => _MedicineFormSheet(
        title: 'Alterar definições',
        initial: initial,
      ),
    );

    if (!mounted || edited == null) return;

    try {
      // 1) Atualiza nome/estoque
      await _retryOnceIfWakeUp(() => _dio.patch('/medications/${initial.medicationId}', data: {
            'name': edited.name,
            'stock': edited.pillsInDispenser,
          }));

      // 2) Cria nova agenda com Hora inicial + Frequência
      final nextLocal = _computeNextFromStart(edited.startAt, edited.freqHours);
      final schedRes = await _dio.post('/schedules', data: {
        'medicationId': initial.medicationId,
        'dose': edited.dosePills,
        'nextAt': nextLocal.toUtc().toIso8601String(),
      });

      // Agenda notificação local da nova programação (sem travar a UX)
      try {
        final sMap = (schedRes.data is Map) ? (schedRes.data as Map) : <String, dynamic>{};
        final sId  = (sMap['_id'] ?? sMap['id'])?.toString() ??
                     'tmp-${initial.medicationId}-${nextLocal.millisecondsSinceEpoch}';
        final when = (sMap['nextAt'] != null)
            ? DateTime.parse(sMap['nextAt'].toString()).toLocal()
            : nextLocal;
        await NotificationsService.instance.scheduleDoseReminder(
          scheduleId: sId,
          when: when,
          medName: edited.name,
          dose: edited.dosePills,
        );
      } catch (_) {
        setState(() => _notifWarning = 'Não foi possível programar o novo lembrete.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atualizado: ${edited.name}')),
      );
      _loadAll();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorFromDio(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e')),
      );
    }
  }

  // ======= HELPERS HTTP =======

  String _errorFromDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Tempo esgotado. Verifique sua conexão.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Falha de conexão. Verifique sua internet.';
    }
    final code = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    if (code >= 500) return 'Servidor indisponível ($code).';
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List && m.isNotEmpty) return m.join('\n');
      return m.toString();
    }
    return 'Não foi possível completar a operação.';
  }

  Future<Response<T>> _retryOnceIfWakeUp<T>(Future<Response<T>> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final shouldRetry =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          code == 502 || code == 503 || code == 504;
      if (shouldRetry) {
        await Future.delayed(const Duration(seconds: 1));
        return await fn();
      }
      rethrow;
    }
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'MEDITRACK',
          style: theme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: .5,
          ),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_notifWarning != null) ...[
              _BannerWarning(
                text: _notifWarning!,
                actionLabel: 'Ativar agora',
                onAction: () async {
                  await NotificationsService.instance.requestExactAlarmsPermission();
                  if (mounted) _loadAll();
                },
              ),
              const SizedBox(height: 12),
            ],

            if (_loadError != null) ...[
              _ErrorCard(message: _loadError!, onRetry: _loadAll),
              const SizedBox(height: 12),
            ],
            if (_items.isEmpty && !_loading) ...[
              _EmptyCard(onAdd: _openAddMedicineSheet),
              const SizedBox(height: 12),
            ],
            for (int i = 0; i < _items.length; i++) ...[
              _MedicineCard(
                medicine: _items[i],
                onChange: () => _openEditMedicineSheet(index: i),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: AppColors.primary,
                ),
                onPressed: _openAddMedicineSheet,
                child: Text(
                  'Adicionar novo remédio',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========= FORM (BOTTOM SHEET) =========

class _MedicineFormSheet extends StatefulWidget {
  final String title;
  final Medicine? initial;
  const _MedicineFormSheet({required this.title, this.initial});

  @override
  State<_MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends State<_MedicineFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _freqCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _pillsCtrl;

  TimeOfDay _startTime = TimeOfDay.now(); // Hora inicial fixa (padrão: agora)

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initial?.name ?? '');
    _freqCtrl  = TextEditingController(
      text: widget.initial != null ? widget.initial!.freqHours.toString() : '',
    );
    _doseCtrl  = TextEditingController(
      text: widget.initial != null ? widget.initial!.dosePills.toString() : '',
    );
    _pillsCtrl = TextEditingController(
      text: widget.initial != null ? widget.initial!.pillsInDispenser.toString() : '',
    );

    if (widget.initial?.startAt != null) {
      _startTime = widget.initial!.startAt!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _freqCtrl.dispose();
    _doseCtrl.dispose();
    _pillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora inicial',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  String _fmtTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final med = Medicine(
      medicationId: widget.initial?.medicationId ?? '',
      scheduleId: widget.initial?.scheduleId,
      name: _nameCtrl.text.trim(),
      freqHours: int.parse(_freqCtrl.text),
      dosePills: int.parse(_doseCtrl.text),
      pillsInDispenser: int.parse(_pillsCtrl.text),
      startAt: _startTime,
    );
    Navigator.of(context).pop<Medicine>(med);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),

            // Nome
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Nome do remédio'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),

            // Hora inicial
            GestureDetector(
              onTap: _pickStartTime,
              child: InputDecorator(
                decoration: inputDecoration('Hora inicial'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmtTime(_startTime),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.access_time, color: Colors.black54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Frequência
            TextFormField(
              controller: _freqCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Frequência (em horas)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Informe um número válido (> 0)';
                if (n > 168) return 'Valor muito alto (máx. 168h)';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Dose (quantidade por tomada)
            TextFormField(
              controller: _doseCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Dose (quantidade por tomada)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Informe um número válido (> 0)';
                if (n > 20) return 'Valor muito alto';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Doses no dispenser (estoque)
            TextFormField(
              controller: _pillsCtrl,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Doses no estoque'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Informe um número válido (>= 0)';
                if (n > 500) return 'Valor muito alto';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  'Salvar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ========= CARDS / PLACEHOLDERS =========

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onChange;

  const _MedicineCard({
    required this.medicine,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // LADO ESQUERDO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine.name,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4A4485),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text('Próxima dose em',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF7E7E8A),
                        fontSize: 13,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${medicine.freqHours} ',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          )),
                      Text('hrs',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // LADO DIREITO
          Expanded(
            child: Container(
              height: 150,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${medicine.pillsInDispenser} doses no dispenser',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6C6B77),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Dose',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      )),
                  Text(
                    '${medicine.dosePills} doses',
                    style: GoogleFonts.poppins(color: const Color(0xFF6C6B77)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2941),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onChange,
                      child: Text(
                        'Alterar definições',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD5D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Não foi possível carregar os dados',
              style: GoogleFonts.poppins(
                color: const Color(0xFFB00020),
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          Text(message, style: GoogleFonts.poppins()),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Tentar novamente',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('Nenhuma dose agendada',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A4485),
              )),
          const SizedBox(height: 6),
          Text('Adicione um remédio para criar sua primeira agenda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: const Color(0xFF6C6B77))),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Adicionar remédio',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------ Banner de aviso (permissão de alarme exato / falha) ----------- */
class _BannerWarning extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _BannerWarning({required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD5D5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notification_important_outlined, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.poppins())),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
    }
}
