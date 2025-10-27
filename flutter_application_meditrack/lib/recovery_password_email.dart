import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/forget_password_page.dart'; // ForgotPasswordPage
import 'package:flutter_application_meditrack/core/api_client.dart';
import 'package:flutter_application_meditrack/core/env.dart';

class RecoveryPasswordEmailPage extends StatefulWidget {
  const RecoveryPasswordEmailPage({super.key});

  @override
  State<RecoveryPasswordEmailPage> createState() => _RecoveryPasswordEmailPageState();
}

class _RecoveryPasswordEmailPageState extends State<RecoveryPasswordEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;

  final Dio _dio = ApiClient.instance.dio;

  @override
  void initState() {
    super.initState();
    _dio.options.baseUrl = Env.apiBase;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 25);
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v.trim());
    if (!ok) return 'E-mail inválido';
    return null;
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final email = _emailCtrl.text.trim().toLowerCase();

    try {
      // Chama o endpoint de envio de código
      await _retryOnceIfWakeUp(() {
        return _dio.post('/auth/request-reset', data: {'email': email});
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviamos um código para $email.')),
      );

      // Abre a tela de confirmação do código + nova senha
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ForgotPasswordPage(email: email)),
      );
    } on DioException catch (e) {
      final msg = _errorFromDio(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Melhora mensagens do Nest/Dio
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
    return 'Não foi possível enviar o código. Tente novamente.';
  }

  // Retry 1x em casos típicos do Render “acordando”
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),
                Text(
                  'MEDITRACK',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    letterSpacing: 2,
                    color: const Color(0xFF9DA0A8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Esqueci minha senha',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 80),

                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: inputDecoration('Digite seu e-mail'),
                ),

                const SizedBox(height: 48),

                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isSubmitting ? null : _sendCode,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                          )
                        : Text(
                            'Enviar código',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dica opcional
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Você receberá um código por e-mail para redefinir sua senha.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF8B8B97),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
