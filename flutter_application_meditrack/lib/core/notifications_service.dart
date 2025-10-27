import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Fallback para checar/abrir a permissão de alarmes exatos (implementado no MainActivity.kt)
  static const MethodChannel _exactCh = MethodChannel('meditrack/exact_alarms');

  /// Inicializa plugin + timezones + canal Android.
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);

    // Garante que o canal existe (Android 8+)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'doses_channel',
      'Lembretes de doses',
      description: 'Notificações para horários de medicamentos',
      importance: Importance.max,
    ));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Android 13+: POST_NOTIFICATIONS
  Future<void> ensureBasicPermissions() async {
    if (!Platform.isAndroid) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final enabled = await android?.areNotificationsEnabled();
    if (enabled == false) {
      await android?.requestNotificationsPermission();
    }
  }

  /// Checa se podemos agendar EXATO.
  /// 1) Tenta via plugin (se a versão expuser o método)
  /// 2) Fallback via MethodChannel (MainActivity.kt)
  Future<bool> areExactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;

    // 1) tentativa via plugin (chamada dinâmica para não quebrar em versões antigas)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final dyn = android as dynamic;
      final ok = await dyn.areExactAlarmsAllowed();
      if (ok is bool) return ok;
    } catch (_) {
      // ignora e tenta fallback
    }

    // 2) fallback via canal nativo
    try {
      final ok = await _exactCh.invokeMethod<bool>('canScheduleExactAlarms');
      return ok ?? true; // se não souber, não acusa falta à toa
    } catch (_) {
      return true;
    }
  }

  /// Abre a tela do sistema para conceder “Alarmes e lembretes” (API 31+).
  Future<void> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return;

    // 1) tentativa via plugin (dinâmica)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final dyn = android as dynamic;
      await dyn.requestExactAlarmsPermission();
      return;
    } catch (_) {
      // ignora e tenta fallback
    }

    // 2) fallback via canal nativo
    try {
      await _exactCh.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }

  Future<void> clearDoseReminders() async => _plugin.cancelAll();

  /// Agenda o lembrete. Se o sistema não permitir EXATO, cai para INEXATO.
  Future<void> scheduleDoseReminder({
    required String scheduleId,
    required DateTime when, // horário local
    required String medName,
    required num dose,
  }) async {
    await ensureBasicPermissions();

    final id = scheduleId.hashCode & 0x7FFFFFFF;
    final tzWhen = tz.TZDateTime.from(when, tz.local);

    AndroidScheduleMode mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (await areExactAlarmsAllowed()) {
      mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    const androidDetails = AndroidNotificationDetails(
      'doses_channel',
      'Lembretes de doses',
      channelDescription: 'Notificações para horários de medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'Hora do remédio',
        '$medName — tomar ${dose.toString()} dose(s)',
        tzWhen,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: scheduleId,
      );
    } on PlatformException catch (e) {
      // Se ainda assim vier o erro, reagenda como INEXATO.
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id,
          'Hora do remédio',
          '$medName — tomar ${dose.toString()} dose(s)',
          tzWhen,
          const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: scheduleId,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Helper para UI: decide se deve mostrar o banner “Ativar agora”.
  Future<bool> shouldShowExactAlarmBanner() async {
    if (!Platform.isAndroid) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifsEnabled = await android?.areNotificationsEnabled() ?? true;

    if (!notifsEnabled) return true; // peça também a permissão de notificação

    final exactOk = await areExactAlarmsAllowed();
    return !exactOk;
  }
}
