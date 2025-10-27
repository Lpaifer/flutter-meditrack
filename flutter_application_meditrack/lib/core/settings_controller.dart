import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

class SettingsState {
  final String timezone;
  final String locale;        // ex: pt_BR
  final String timeFormat;    // '12h' | '24h'
  final String unitSystem;    // 'metric' | 'imperial'
  final bool notifEnabled;
  final bool notifDose;
  final bool notifTips;
  final double textScale;     // 0.9 ~ 1.5
  final bool highContrast;
  final bool reduceMotion;

  const SettingsState({
    required this.timezone,
    required this.locale,
    required this.timeFormat,
    required this.unitSystem,
    required this.notifEnabled,
    required this.notifDose,
    required this.notifTips,
    required this.textScale,
    required this.highContrast,
    required this.reduceMotion,
  });

  SettingsState copyWith({
    String? timezone,
    String? locale,
    String? timeFormat,
    String? unitSystem,
    bool? notifEnabled,
    bool? notifDose,
    bool? notifTips,
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
  }) {
    return SettingsState(
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      timeFormat: timeFormat ?? this.timeFormat,
      unitSystem: unitSystem ?? this.unitSystem,
      notifEnabled: notifEnabled ?? this.notifEnabled,
      notifDose: notifDose ?? this.notifDose,
      notifTips: notifTips ?? this.notifTips,
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  Map<String, dynamic> toServerJson() => {
        'timezone': timezone,
        'locale': locale,
        'timeFormat': timeFormat,
        'units': unitSystem, // 'metric' | 'imperial'
        'notifications': {
          'enabled': notifEnabled,
          'doses': notifDose,
          'tips': notifTips,
        },
        'a11y': {
          'textScale': textScale,
          'highContrast': highContrast,
          'reduceMotion': reduceMotion,
        },
      };

  static Future<SettingsState> fromLocal(SharedPreferences sp) async {
    return SettingsState(
      timezone:      sp.getString('pref.timezone')         ?? 'America/Sao_Paulo',
      locale:        sp.getString('pref.locale')           ?? 'pt_BR',
      timeFormat:    sp.getString('pref.timeFormat')       ?? '24h',
      unitSystem:    (sp.getString('pref.units') ?? 'metric').toLowerCase().startsWith('imperial') ? 'imperial' : 'metric',
      notifEnabled:  sp.getBool('pref.notif.enabled')      ?? true,
      notifDose:     sp.getBool('pref.notif.doses')        ?? true,
      notifTips:     sp.getBool('pref.notif.tips')         ?? false,
      textScale:     sp.getDouble('pref.a11y.textScale')   ?? 1.0,
      highContrast:  sp.getBool('pref.a11y.highContrast')  ?? false,
      reduceMotion:  sp.getBool('pref.a11y.reduceMotion')  ?? false,
    );
  }

  Future<void> saveToLocal(SharedPreferences sp) async {
    await sp.setString('pref.timezone', timezone);
    await sp.setString('pref.locale', locale);
    await sp.setString('pref.timeFormat', timeFormat);
    // se vier rótulo completo, normaliza; caso contrário, assume já normalizado
    final normalizedUnits = (unitSystem.toLowerCase().startsWith('imperial')) ? 'imperial'
                         : (unitSystem.toLowerCase().startsWith('metric'))   ? 'metric'
                         : unitSystem;
    await sp.setString('pref.units', normalizedUnits);

    await sp.setBool('pref.notif.enabled', notifEnabled);
    await sp.setBool('pref.notif.doses', notifDose);
    await sp.setBool('pref.notif.tips', notifTips);

    await sp.setDouble('pref.a11y.textScale', textScale);
    await sp.setBool('pref.a11y.highContrast', highContrast);
    await sp.setBool('pref.a11y.reduceMotion', reduceMotion);
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  final _svc = SettingsService();
  SettingsState _state = const SettingsState(
    timezone: 'America/Sao_Paulo',
    locale: 'pt_BR',
    timeFormat: '24h',
    unitSystem: 'metric',
    notifEnabled: true,
    notifDose: true,
    notifTips: false,
    textScale: 1.0,
    highContrast: false,
    reduceMotion: false,
  );

  SettingsState get state => _state;

  bool _autoSync = false;
  Timer? _debounce;

  void setAutoSync(bool v) => _autoSync = v;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _state = await SettingsState.fromLocal(sp);
    notifyListeners();

    // hidrata do servidor (se existir)
    try {
      final m = await _svc.fetch();
      String units = (m['units'] ?? m['unidades'] ?? 'metric').toString();
      units = units.toLowerCase().startsWith('imperial') ? 'imperial' : 'metric';

      _state = _state.copyWith(
        timezone:     (m['timezone'] ?? m['fuso'] ?? _state.timezone).toString(),
        locale:       (m['locale'] ?? m['idioma'] ?? _state.locale).toString(),
        timeFormat:   (m['timeFormat'] ?? m['formatoHora'] ?? _state.timeFormat).toString(),
        unitSystem:   units,
        notifEnabled: ((m['notifications'] ?? m['notificacoes'])?['enabled'] ?? _state.notifEnabled) as bool,
        notifDose:    ((m['notifications'] ?? m['notificacoes'])?['doses']   ?? _state.notifDose) as bool,
        notifTips:    ((m['notifications'] ?? m['notificacoes'])?['tips']    ?? _state.notifTips) as bool,
        textScale:    (((m['a11y'] ?? m['accessibility'])?['textScale']) ?? _state.textScale).toDouble(),
        highContrast: ((m['a11y'] ?? m['accessibility'])?['highContrast'] ?? _state.highContrast) as bool,
        reduceMotion: ((m['a11y'] ?? m['accessibility'])?['reduceMotion'] ?? _state.reduceMotion) as bool,
      );
      await _persistLocal();
      notifyListeners();
    } catch (_) {
      // sem problema: segue com valores locais
    }
  }

  Future<void> saveToServer() async => _svc.save(_state.toServerJson());

  // ---------- setters (notificam + persistem local; opcional: debounce server) ----------
  void setTimezone(String v) => _update(_state.copyWith(timezone: v));
  void setLocale(String v)   => _update(_state.copyWith(locale: v));
  void setTimeFormat(String v) => _update(_state.copyWith(timeFormat: v));
  void setUnits(String v) {
    final normalized = v.toLowerCase().startsWith('imperial') ? 'imperial' : 'metric';
    _update(_state.copyWith(unitSystem: normalized));
  }
  void setNotifEnabled(bool v) => _update(_state.copyWith(notifEnabled: v));
  void setNotifDose(bool v)    => _update(_state.copyWith(notifDose: v));
  void setNotifTips(bool v)    => _update(_state.copyWith(notifTips: v));
  void setTextScale(double v)  => _update(_state.copyWith(textScale: v));
  void setHighContrast(bool v) => _update(_state.copyWith(highContrast: v));
  void setReduceMotion(bool v) => _update(_state.copyWith(reduceMotion: v));

  // aplica de uma vez (útil ao abrir a SettingsPage com valores carregados)
  void replace(SettingsState next) => _update(next, debounce: false);

  Future<void> _persistLocal() async {
    final sp = await SharedPreferences.getInstance();
    await _state.saveToLocal(sp);
  }

  void _update(SettingsState next, {bool debounce = true}) {
    _state = next;
    _persistLocal(); // fire and forget
    notifyListeners();

    if (_autoSync) {
      _debounce?.cancel();
      if (debounce) {
        _debounce = Timer(const Duration(milliseconds: 800), () {
          saveToServer().catchError((_) {});
        });
      } else {
        saveToServer().catchError((_) {});
      }
    }
  }
}
