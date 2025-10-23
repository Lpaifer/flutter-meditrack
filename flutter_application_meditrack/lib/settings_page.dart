import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/core/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- Opções fixas ---
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

  // Opção 2: apenas os códigos
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

  // --- Estado persistido ---
  String _timezone = 'America/Sao_Paulo';
  String _locale = 'pt_BR';
  String _timeFormat = '24h'; // '12h' | '24h'
  String _unitSystem = _units.first;

  bool _notifEnabled = true;
  bool _notifDose = true;
  bool _notifTips = false;

  double _textScale = 1.0; // acessibilidade
  bool _highContrast = false;
  bool _reduceMotion = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _timezone     = sp.getString('pref.timezone')     ?? _timezone;
      _locale       = sp.getString('pref.locale')       ?? _locale;
      _timeFormat   = sp.getString('pref.timeFormat')   ?? _timeFormat;
      _unitSystem   = sp.getString('pref.units')        ?? _unitSystem;

      _notifEnabled = sp.getBool('pref.notif.enabled')  ?? _notifEnabled;
      _notifDose    = sp.getBool('pref.notif.doses')    ?? _notifDose;
      _notifTips    = sp.getBool('pref.notif.tips')     ?? _notifTips;

      _textScale    = sp.getDouble('pref.a11y.textScale') ?? _textScale;
      _highContrast = sp.getBool('pref.a11y.highContrast') ?? _highContrast;
      _reduceMotion = sp.getBool('pref.a11y.reduceMotion') ?? _reduceMotion;

      _loading = false;
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('pref.timezone', _timezone);
    await sp.setString('pref.locale', _locale);
    await sp.setString('pref.timeFormat', _timeFormat);
    await sp.setString('pref.units', _unitSystem);

    await sp.setBool('pref.notif.enabled', _notifEnabled);
    await sp.setBool('pref.notif.doses', _notifDose);
    await sp.setBool('pref.notif.tips', _notifTips);

    await sp.setDouble('pref.a11y.textScale', _textScale);
    await sp.setBool('pref.a11y.highContrast', _highContrast);
    await sp.setBool('pref.a11y.reduceMotion', _reduceMotion);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferências salvas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white,
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
            tooltip: 'Salvar',
            onPressed: _savePrefs,
            icon: const Icon(Icons.save_outlined, color: Colors.black87),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ---------------- Geral ----------------
                _SectionCard(
                  title: 'Geral',
                  child: Column(
                    children: [
                      // Timezone
                      DropdownButtonFormField<String>(
                        value: _timezone,
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

                      // Locale (agora com value == código)
                      DropdownButtonFormField<String>(
                        value: _locale,
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

                      // Formato de hora
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
                                onChanged: (v) =>
                                    setState(() => _timeFormat = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('12h'),
                                value: '12h',
                                groupValue: _timeFormat,
                                onChanged: (v) =>
                                    setState(() => _timeFormat = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Unidades
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

                // ---------------- Tema ----------------
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
                    children: [
                      SwitchListTile(
                        value: _notifEnabled,
                        onChanged: (v) => setState(() => _notifEnabled = v),
                        title: const Text('Ativar notificações'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 8),
                      IgnorePointer(
                        ignoring: !_notifEnabled,
                        child: Opacity(
                          opacity: _notifEnabled ? 1 : .5,
                          child: Column(
                            children: [
                              SwitchListTile(
                                value: _notifDose,
                                onChanged: (v) =>
                                    setState(() => _notifDose = v),
                                title: const Text('Lembretes de dose'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _notifTips,
                                onChanged: (v) =>
                                    setState(() => _notifTips = v),
                                title: const Text('Dicas/avisos de farmácia'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tamanho do texto'),
                                Slider(
                                  min: 0.9,
                                  max: 1.5,
                                  divisions: 12,
                                  value: _textScale,
                                  label: '${_textScale.toStringAsFixed(2)}x',
                                  onChanged: (v) =>
                                      setState(() => _textScale = v),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.fieldFill,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Aa',
                              textScaleFactor: _textScale,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                const SizedBox(height: 24),

                // Salvar
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
                    onPressed: _savePrefs,
                    child: Text(
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

/* ---------- UI helper ---------- */

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
