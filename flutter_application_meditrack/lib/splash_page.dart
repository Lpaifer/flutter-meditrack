import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_meditrack/core/token_service.dart';
import 'package:flutter_application_meditrack/services/user_service.dart';
import 'package:flutter_application_meditrack/home_page.dart';
import 'package:flutter_application_meditrack/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _user = UserService();

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final token = await TokenService.instance.getToken();
      if (token == null || token.isEmpty) {
        _go(const LoginPage());
        return;
      }

      // valida o token no backend
      await _user.me();
      _go(const HomePage());
    } catch (_) {
      await TokenService.instance.clear();
      _go(const LoginPage());
    }
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'MEDITRACK',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }
}
