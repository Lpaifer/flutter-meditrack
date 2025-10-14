import 'package:flutter/material.dart';
import 'core/token_service.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'features/users/users_api.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await TokenService.instance.hydrate();

    // Se tem token, opcionalmente valida no /users/me
    if (TokenService.instance.hasCachedToken) {
      try {
        await UsersApi().me();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        return;
      } catch (_) {
        await TokenService.instance.clear();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
