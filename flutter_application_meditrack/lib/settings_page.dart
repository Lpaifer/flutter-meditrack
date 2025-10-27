import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/login_page.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/core/theme_controller.dart';
import 'package:flutter_application_meditrack/services/settings_service.dart';

// NEW: (ajuste os imports de acordo com o seu projeto)
import 'package:flutter_application_meditrack/core/token_service.dart';
import 'package:flutter_application_meditrack/core/notifications_service.dart';
// se você usa rotas nomeadas, garanta que '/login' existe no MaterialApp
// import 'package:flutter_application_meditrack/login_page.dart'; // caso navegue por widget

/* =========================================
 * SettingsPage (layout do 1º, lógica/recursos do 2º)
 * ========================================= */

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- Catálogos (mantendo formato do 1º) ---
  static const _timezones = <String>[
    'America/Sao_Paulo',
    'America/Manaus',
    'America/Fortaleza',
    'America/Recife',
    'America/Bogota',
    'America/New_York',
    'Europe/London',
    'Europe/Berlin',
    'UTC',
  ];

  static const _locales = <String>['pt_BR', 'en_US', 'es_ES'];

  static String labelForLocale(String code) {
    switch (code) {
      case 'pt_BR':
        return 'Português (Brasil)';
      case 'en_US':
        return 'English (US)';
      case 'es_ES':
        return 'Español (ES)';
      default:
        return code;
    }
  }

  static const _units = <String>['metric (°C, kg)', 'imperial (°F, lb)'];

  // --- Serviço remoto (do 2º) ---
  final _svc = SettingsService();

  // --- Estado de ciclo de vida (do 2º) ---
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // --- Campos persistidos (unificando) ---
  String _timezone = 'America/Sao_Paulo';
  String _locale = 'pt_BR';
  String _timeFormat = '24h'; // 12h | 24h
  String _unitSystem = _units.first; // exibe "metric (°C, kg)" mas salva "metric/imperial"

  // Acessibilidade (mantém UI do 1º + chips do 2º)
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  final List<String> _accessibilityChips = [];
  final _accInput = TextEditingController();

  // Notificações (mantém seção do 1º + chips do 2º)
  bool _notifEnabled = true; // opcionalmente espelha chips "enabled:on|off"
  final List<String> _notifSettings = [];
  final _notifInput = TextEditingController();

  // NEW: flag para mostrar progresso do logout
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _accInput.dispose();
    _notifInput.dispose();
    super.dispose();
  }

  // ---------- Carregar do backend (do 2º) ----------
  Future<void> _loadPrefs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.fetch();

      // Leitura com defaults seguros
      _timezone = (data['timezone'] as String?) ?? _timezone;
      _locale = (data['locale'] as String?) ?? _locale;
      _timeFormat = (data['timeFormat'] as String?) ?? _timeFormat;

      final unitsRaw = (data['units'] as String?) ?? 'metric';
      _unitSystem = unitsRaw == 'imperial' ? _units.last : _units.first;

      // Acessibilidade: aceita tanto lista de flags quanto valores
      final accList = List<String>.from(
        (data['accessibility'] ?? const <String>[]) as List,
      );
      _accessibilityChips
        ..clear()
        ..addAll(accList);

      // Se vierem valores específicos, tentamos refletir
      _highContrast = accList.contains('highContrast') ||
          (data['highContrast'] as bool?) == true;
      _reduceMotion = accList.contains('reduceMotion') ||
          (data['reduceMotion'] as bool?) == true;
      final ts = (data['textScale'] as num?)?.toDouble();
      if (ts != null && ts >= 0.9 && ts <= 1.5) _textScale = ts;

      // Notificações (chips livres)
      _notifSettings
        ..clear()
        ..addAll(List<String>.from(
            (data['notificationSettings'] ?? const <String>[]) as List));

      // Habilitado (se houver chave)
      final enabledKey =
          _notifSettings.firstWhere((e) => e.startsWith('enabled:'), orElse: () => '');
      if (enabledKey.isNotEmpty) {
        _notifEnabled = enabledKey.split(':').last.toLowerCase() == 'on';
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Falha ao carregar preferências: $e';
      });
    }
  }

  // ---------- Salvar no backend (do 2º) ----------
  Future<void> _savePrefs() async {
    setState(() => _saving = true);
    try {
      // Converte label amigável para valor cru
      final unitsRaw = _unitSystem.startsWith('imperial') ? 'imperial' : 'metric';

      // Garante que os chips de acessibilidade reflitam os toggles/slider
      final acc = {..._accessibilityChips};
      _highContrast ? acc.add('highContrast') : acc.remove('highContrast');
      _reduceMotion ? acc.add('reduceMotion') : acc.remove('reduceMotion');
      // inclui textScale como key-value
      acc.removeWhere((e) => e.startsWith('textScale:'));
      acc.add('textScale:${_textScale.toStringAsFixed(2)}');

      // Mantém um chip de enabled:on|off para notificações
      final notif = {..._notifSettings};
      notif.removeWhere((e) => e.startsWith('enabled:'));
      notif.add('enabled:${_notifEnabled ? 'on' : 'off'}');

      final body = {
        'timezone': _timezone,
        'locale': _locale,
        'timeFormat': _timeFormat,
        'units': unitsRaw,
        'accessibility': acc.toList(),
        'notificationSettings': notif.toList(),
        // também envia campos diretos úteis (idempotente)
        'highContrast': _highContrast,
        'reduceMotion': _reduceMotion,
        'textScale': _textScale,
      };

      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(body));

      await _svc.save(body);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências salvas!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // NEW: fluxo de logout local (enquanto o endpoint não existe)
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você será desconectado deste dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loggingOut = true);
    try {
      // 1) Cancela notificações locais (se usar)
      try {
        await NotificationsService.instance.cancelAll();
      } catch (_) {}

      // 2) Limpa token/estado de sessão
      try {
        await TokenService.instance.clear(); // implemente clear() ou hydrate(null)
      } catch (_) {}

      // 3) Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você saiu da conta.')),
        );
      }

      // 4) Redireciona para Login limpando a pilha
      if (!mounted) return;
       Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
      );
      
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white, // mantém estilo do 1º
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Configurações',
          style: t.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _loadPrefs,
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_error != null) ...[
                  _BannerError(text: _error!, onRetry: _loadPrefs),
                  const SizedBox(height: 16),
                ],

                // ---------------- Geral ----------------
                _SectionCard(
                  title: 'Geral',
                  child: Column(
                    children: [
                      // Timezone (dropdown como no 1º)
                      DropdownButtonFormField<String>(
                        value: _timezones.contains(_timezone) ? _timezone : _timezones.first,
                        items: _timezones
                            .map((z) => DropdownMenuItem(
                                  value: z,
                                  child: Text(z),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _timezone = v!),
                        decoration: inputDecoration('Timezone'),
                      ),
                      const SizedBox(height: 12),

                      // Locale (dropdown com rótulos)
                      DropdownButtonFormField<String>(
                        value: _locales.contains(_locale) ? _locale : 'pt_BR',
                        items: _locales
                            .map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(labelForLocale(code)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _locale = v!),
                        decoration: inputDecoration('Idioma (locale)'),
                      ),
                      const SizedBox(height: 12),

                      // Formato de hora (radio como no 1º)
                      InputDecorator(
                        decoration: inputDecoration('Formato de hora'),
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('24h'),
                                value: '24h',
                                groupValue: _timeFormat,
                                onChanged: (v) => setState(() => _timeFormat = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('12h'),
                                value: '12h',
                                groupValue: _timeFormat,
                                onChanged: (v) => setState(() => _timeFormat = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Unidades (dropdown como no 1º)
                      DropdownButtonFormField<String>(
                        value: _unitSystem,
                        items: _units
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _unitSystem = v!),
                        decoration: inputDecoration('Unidades'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- Tema (mantém do 1º) ----------------
                _SectionCard(
                  title: 'Tema',
                  child: SwitchListTile(
                    value: ThemeController.instance.mode == ThemeMode.dark,
                    onChanged: (v) => ThemeController.instance
                        .setMode(v ? ThemeMode.dark : ThemeMode.light),
                    title: const Text('Modo escuro'),
                    subtitle: const Text('Alterne entre claro e escuro'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- Notificações ----------------
                _SectionCard(
                  title: 'Notificações',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _notifEnabled,
                        onChanged: (v) => setState(() => _notifEnabled = v),
                        title: const Text('Ativar notificações'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- Acessibilidade ----------------
                _SectionCard(
                  title: 'Acessibilidade',
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _highContrast,
                        onChanged: (v) => setState(() => _highContrast = v),
                        title: const Text('Alto contraste'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _reduceMotion,
                        onChanged: (v) => setState(() => _reduceMotion = v),
                        title: const Text('Reduzir animações'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // NEW: Conta (logout)
                _SectionCard(
                  title: 'Conta',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Sair da conta'),
                        subtitle: const Text('Desconectar deste dispositivo'),
                        trailing: _loggingOut
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : null,
                        onTap: _loggingOut ? null : _logout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- Botão Salvar (mantém do 1º) ----------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saving ? null : _savePrefs,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.6, color: Colors.white),
                          )
                        : Text(
                            'Salvar alterações',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

/* ---------- UI helpers (mantidos/adaptados) ---------- */

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BannerError extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _BannerError({required this.text, required this.onRetry});

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
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.poppins())),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
