// lib/core/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kPrefKey = 'pref.theme.dark';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Carrega o tema salvo no dispositivo (padrão: claro)
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final dark = sp.getBool(_kPrefKey) ?? false;
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
  }

  /// Define o tema e persiste
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPrefKey, mode == ThemeMode.dark);
  }

  /// Atalho para alternar
  Future<void> toggle() =>
      setMode(isDark ? ThemeMode.light : ThemeMode.dark);
}
