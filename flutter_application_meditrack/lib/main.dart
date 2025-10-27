import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_meditrack/core/notifications_service.dart';
import 'package:flutter_application_meditrack/core/token_service.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_application_meditrack/splash_page.dart';
import 'package:flutter_application_meditrack/core/theme_controller.dart';
import 'package:flutter_application_meditrack/core/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationsService.instance.init();

  await TokenService.instance.hydrate();
  // Carrega preferências locais (+ tenta hidratar do servidor)
  await SettingsController.instance.load();

  await ThemeController.instance.load();

  TokenService.instance.tokenNotifier.addListener(() {
    final token = TokenService.instance.tokenNotifier.value;
      if (token == null) {
    // navegar para Login, limpar estados, etc.
      }
  });


  SettingsController.instance.setAutoSync(true);

  // Aplica locale inicial para Intl/DateFormat
  final initialLocale = SettingsController.instance.state.locale;
  Intl.defaultLocale = initialLocale;
  try {
    await initializeDateFormatting(initialLocale);
  } catch (_) {
    // Se a localidade específica não estiver disponível, inicializa genérico.
    await initializeDateFormatting();
  }

  // (Opcional) Trava orientação em portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Locale _toLocale(String code) {
    final parts = code.split('_');
    if (parts.length == 2) return Locale(parts[0], parts[1]);
    return Locale(code);
  }

  // Remove transições se reduceMotion = true

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeController.instance;

    // Reage a mudanças do SettingsController (locale, textScale, acessibilidade)
    return AnimatedBuilder(
      animation: SettingsController.instance,
      builder: (context, _) {
        final s = SettingsController.instance.state;

        // Reage a mudanças do ThemeController (claro/escuro)
        return AnimatedBuilder(
          animation: themeCtrl,
          builder: (context, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,

              // Locale dinâmico
              locale: _toLocale(s.locale),
              supportedLocales: const [
                Locale('pt', 'BR'),
                Locale('en', 'US'),
                Locale('es', 'ES'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              // Tema dinâmico + acessibilidade
              themeMode: themeCtrl.mode,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: Colors.black,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
              
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(s.textScale),
                  ),
                  child: child!,
                );
              },

              home: const SplashPage(),
            );
          },
        );
      },
    );
  }
}

/// Construtor de transições "vazio" (sem animação) para acessibilidade.
// ignore: unused_element
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
