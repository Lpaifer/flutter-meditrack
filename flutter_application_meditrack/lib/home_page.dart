import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/core/notifications_service.dart';
import 'package:flutter_application_meditrack/pharmacy_near_you.dart';
import 'package:flutter_application_meditrack/doses_page.dart';
import 'package:flutter_application_meditrack/profile_page.dart';
import 'package:flutter_application_meditrack/settings_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/core/api_client.dart';
import 'package:flutter_application_meditrack/core/env.dart';

/* =========================
 * MODELO DE EVENTO (UI)
 * =======================*/
class Dose {
  final String medId;       // medicationId
  final String medName;     // nome do remédio
  final int doseQty;        // quantidade por dose
  final DateTime dateTime;  // horário da dose

  const Dose({
    required this.medId,
    required this.medName,
    required this.doseQty,
    required this.dateTime,
  });
}

/* =========================
 * DTOs (resilientes ao back)
 * =======================*/
class _MedicationDto {
  final String id;
  final String name;

  _MedicationDto({required this.id, required this.name});

  factory _MedicationDto.fromJson(Map<String, dynamic> j) => _MedicationDto(
        id: (j['_id'] ?? j['id']).toString(),
        name: (j['name'] ?? 'Medicamento').toString(),
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

/* ==============
 *     PAGE
 * ============*/
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // backend
  final Dio _dio = ApiClient.instance.dio;

  // dados
  late Map<DateTime, List<Dose>> _dosesByDay; // eventos por dia
  List<_ScheduleDto> _schedules = [];
  Map<String, String> _medNameById = {}; // medicationId -> name

  // estados de UI
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;
  String? _loadError;

  // próxima dose / contador
  Timer? _ticker;
  Duration? _nextIn;
  Duration? _prevNextIn;
  Dose? _nextDose;
  String? _lastBannerKey;

  // aviso de permissão/queda de exato
  String? _notifWarning;

  // bottom nav
  int _navIndex = 1; // 0=DOSES, 1=HOME, 2=PERFIL

  @override
  void initState() {
    super.initState();
    _dio.options.baseUrl = Env.apiBase;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 25);

    _dosesByDay = {};
    _loadAll();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /* --------------------------
   * Banner de permissão
   * ------------------------*/
  Future<void> _refreshNotifBanner() async {
    try {
      final show = await NotificationsService.instance.shouldShowExactAlarmBanner();
      if (!mounted) return;
      setState(() {
        _notifWarning = show
            ? 'Para alertas no horário exato, ative “Alarmes e lembretes” nas permissões do app.'
            : null;
      });
    } catch (_) {
      // Se der erro na checagem, não travar a UI
    }
  }

  /* --------------------------
   * Carregamento do backend
   * ------------------------*/
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _notifWarning = null;
    });

    try {
      final medsRes = await _retryOnceIfWakeUp(() => _dio.get('/medications'));
      final schRes  = await _retryOnceIfWakeUp(() => _dio.get('/schedules'));

      // medications pode vir como [] OU {"value":[...], "Count": N}
      final dynamic medsData = medsRes.data;
      final List medsRaw = medsData is List
          ? medsData
          : (medsData is Map && medsData['value'] is List ? medsData['value'] as List : const []);

      final meds = medsRaw
          .whereType<Map>()
          .map((e) => _MedicationDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // schedules: lista simples
      final List schRaw = schRes.data is List ? schRes.data as List : const [];
      final schs = schRaw
          .whereType<Map>()
          .map((e) => _ScheduleDto.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.enabled)
          .toList();

      _medNameById = {for (final m in meds) m.id: m.name};
      _schedules = schs;

      _buildEventsMapFromSchedules();
      _computeNextDose(); // 1ª computação

      // (Re)agenda notificações futuras
      try {
        await NotificationsService.instance.clearDoseReminders();
        final now = DateTime.now();
        for (final s in _schedules.where((x) => x.enabled && x.nextAt.isAfter(now)).take(20)) {
          final name = _medNameById[s.medicationId] ?? 'Medicamento';
          await NotificationsService.instance.scheduleDoseReminder(
            scheduleId: s.id,
            when: s.nextAt,
            medName: name,
            dose: s.dose.toInt(),
          );
        }
      } catch (_) {
        _notifWarning = 'Não foi possível programar os lembretes agora.';
      }

      // ticker para countdown + gatilho do banner
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _computeNextDose());

      // Atualiza o banner de permissão
      await _refreshNotifBanner();

      setState(() {
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

  // Cria o mapa de eventos do calendário a partir de _schedules
  void _buildEventsMapFromSchedules() {
    final map = <DateTime, List<Dose>>{};
    for (final s in _schedules) {
      final dayKey = _keyOf(s.nextAt);
      final medName = _medNameById[s.medicationId] ?? 'Medicamento';
      final qty = s.dose.toInt();
      (map[dayKey] ??= []).add(Dose(
        medId: s.medicationId,
        medName: medName,
        doseQty: qty,
        dateTime: s.nextAt,
      ));
    }
    // ordena por horário dentro do dia
    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    _dosesByDay = map;
  }

  /* --------------------------
   * Helpers de data / eventos
   * ------------------------*/
  DateTime _keyOf(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Dose> _eventsLoader(DateTime day) => _dosesByDay[_keyOf(day)] ?? const [];

  /* --------------------------
   * Próxima dose / contador + banner
   * ------------------------*/
  void _computeNextDose() {
    final now = DateTime.now();

    final upcoming = _dosesByDay.values
        .expand((e) => e)
        .where((d) => d.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (upcoming.isEmpty) {
      setState(() {
        _nextIn = null;
        _nextDose = null;
      });
      return;
    }

    final first = upcoming.first;
    final newNext = first.dateTime.difference(now);

    // detectar cruzamento do contador para <= 0 (mudança de tick)
    final crossedToZero = _prevNextIn != null &&
        _prevNextIn!.inSeconds > 0 &&
        newNext.inSeconds <= 0;

    setState(() {
      _nextIn = newNext;
      _nextDose = first;
      _prevNextIn = newNext;
    });

    // Banner "está na hora!" (anti-duplicação)
    if (crossedToZero) {
      final key = '${first.medId}-${first.dateTime.toIso8601String()}';
      if (_lastBannerKey == key) return;
      _lastBannerKey = key;

      showDoseBanner(
        context,
        medName: first.medName,
        dose: first.doseQty,
        onTake: () {
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OK! ${first.doseQty} dose${first.doseQty == 1 ? '' : 's'} de ${first.medName}')),
          );
          // opcional: _loadAll();
        },
        onSnooze10: () async {
          await NotificationsService.instance.scheduleDoseReminder(
            scheduleId: 'snooze-$key',
            when: DateTime.now().add(const Duration(minutes: 10)),
            medName: first.medName,
            dose: first.doseQty,
          );
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lembrarei em 10 minutos')),
          );
        },
      );
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')} hrs '
           '${m.toString().padLeft(2, '0')} min '
           '${s.toString().padLeft(2, '0')} seg';
  }

  /* --------------------------
   * UI auxiliares
   * ------------------------*/
  void _openDosesForDay(DateTime day) {
    final doses = _eventsLoader(day);
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          children: [
            // Data grande à esquerda
            Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${day.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(
                    DateFormat.MMMM('pt_BR').format(day).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6B75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Lista de doses
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(238, 221, 214, 253),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doses por vir',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 12),
                    if (doses.isEmpty)
                      Text('Sem doses para este dia.',
                          style: GoogleFonts.poppins(color: Colors.black87))
                    else
                      ...doses.map((d) {
                        final h = DateFormat.Hm('pt_BR').format(d.dateTime);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  h,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                      fontSize: 15,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: d.medName,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const TextSpan(text: '\n'),
                                      TextSpan(
                                        text: '${d.doseQty} dose${d.doseQty == 1 ? '' : 's'}',
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    return 'Não foi possível carregar as doses.';
  }

  // Retry 1x nos casos típicos do Render “acordando”
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

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat.yMMMM('pt_BR').format(_focusedDay);
    final nextLabel = (_nextDose == null)
        ? '—'
        : '${_nextDose!.medName} • ${_nextDose!.doseQty} dose${_nextDose!.doseQty == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'MEDITRACK',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 32,
            letterSpacing: 0,
            color: Colors.black,
            fontWeight: FontWeight.w600,
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
              iconSize: 28,
              tooltip: 'Recarregar',
              icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
              onPressed: _loadAll,
            ),
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          )
        ],
      ),

      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.deepPurple.shade100,
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          if (i == 0) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DosesPage()));
            return;
          }
          if (i == 1) setState(() => _navIndex = 1); // HOME
          if (i == 2) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.science_outlined), label: 'DOSES'),
          NavigationDestination(icon: Icon(Icons.home_outlined),   label: 'HOME'),
          NavigationDestination(icon: Icon(Icons.person_2_outlined), label: 'PERFIL'),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              // Banner de aviso de notificação (não-bloqueante)
              if (_notifWarning != null) ...[
                _BannerWarning(
                  text: _notifWarning!,
                  actionLabel: 'Ativar agora',
                  onAction: () async {
                    await NotificationsService.instance.requestExactAlarmsPermission();
                    await Future.delayed(const Duration(seconds: 1));
                    await _refreshNotifBanner(); // ✅ atualiza corretamente
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Erro de carregamento (somente erros de rede/back)
              if (_loadError != null) ...[
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Não foi possível carregar as doses',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          )),
                      const SizedBox(height: 8),
                      Text(_loadError!, style: GoogleFonts.poppins()),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: _loadAll,
                          child: Text('Tentar novamente',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ---- Card Próxima dose ----
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Text('Próxima dose em:',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      _nextIn == null ? '—' : _fmtDuration(_nextIn!),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${DateFormat.EEEE('pt_BR').format(DateTime.now())}, ${DateFormat.d().format(DateTime.now())} de ${DateFormat.MMMM('pt_BR').format(DateTime.now())}',
                      style: GoogleFonts.poppins(
                        color: Colors.deepPurple,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- Card Farmácias ----
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text('FARMÁCIAS PERTO DE VOCÊ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.black87,
                        )),
                    const SizedBox(height: 4),
                    Text('Veja as farmácias próximas a sua localização',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(255, 21, 25, 33),
                        )),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NearbyPharmaciesPage()),
                          );
                        },
                        child: Text('VEJA AQUI',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---- Card Calendário ----
              _Card(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      monthTitle.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TableCalendar<Dose>(
                      locale: 'pt_BR',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Color.fromARGB(255, 169, 138, 255),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerVisible: false,
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        weekendStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      eventLoader: _eventsLoader,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                        _openDosesForDay(selected);
                      },
                      onPageChanged: (focused) {
                        setState(() => _focusedDay = focused);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------------
 * Card base com visual lilás
 * ------------------------*/
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color.fromARGB(238, 221, 214, 253),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/* --------------------------
 * Banner de aviso (permissão / fallback)
 * ------------------------*/
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

/* --------------------------
 * Banner “está na hora!”
 * ------------------------*/
void showDoseBanner(
  BuildContext context, {
  required String medName,
  required int dose,
  required VoidCallback onTake,
  required Future<void> Function() onSnooze10,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();

  final banner = MaterialBanner(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    leading: const Icon(Icons.notifications_active_outlined, color: Colors.green),
    content: Text(
      'Está na hora: $medName — $dose dose${dose == 1 ? '' : 's'}',
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    ),
    actions: [
      TextButton(
        onPressed: () {
          onTake();
        },
        child: const Text('Tomar agora'),
      ),
      TextButton(
        onPressed: () async {
          await onSnooze10();
        },
        child: const Text('Lembrar em 10 min'),
      ),
      IconButton(
        tooltip: 'Fechar',
        onPressed: () => messenger.hideCurrentMaterialBanner(),
        icon: const Icon(Icons.close),
      ),
    ],
  );

  messenger.showMaterialBanner(banner);
}
