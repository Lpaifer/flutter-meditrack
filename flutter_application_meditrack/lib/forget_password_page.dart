// lib/forget_password_page.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/home_page.dart';
import 'package:flutter_application_meditrack/login_page.dart';
import 'package:flutter_application_meditrack/core/api_client.dart';
import 'package:flutter_application_meditrack/core/env.dart';
import 'package:flutter_application_meditrack/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.email});
  final String? email;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSubmitting = false;

  // cooldown para reenviar código
  int _resendCooldown = 0;
  Timer? _timer;

  // HTTP
  final Dio _dio = ApiClient.instance.dio;

  @override
  void initState() {
    super.initState();
    // Configura Dio/baseURL
    _dio.options.baseUrl = Env.apiBase;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 25);
    _dio.options.headers['Content-Type'] = 'application/json';

    // Mostra alerta de "código enviado" quando abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCodeSentAlert();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  // ---------- Validações ----------
  String? _validateCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o código';
    if (v.trim().length < 6) return 'Código inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Informe a nova senha';
    if (v.length < 8) return 'Mínimo de 8 caracteres';
    return null;
  }

  // ---------- Ações ----------
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final code = _codeCtrl.text.trim();
    final newPass = _passCtrl.text;

    try {
      // 1) Redefinir senha
      await _retryOnceIfWakeUp(() {
        return _dio.post('/auth/reset-with-code', data: {
          'token': code,
          'newPassword': newPass,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada com sucesso!')),
      );

      // 2) (Opcional) login automático se soubermos o e-mail
      if (widget.email != null && widget.email!.trim().isNotEmpty) {
        try {
          await AuthService().login(widget.email!.trim().toLowerCase(), newPass);
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (_) => false,
          );
          return;
        } on DioException {
          // se o login automático falhar, cai pro fluxo de ir ao Login
        } catch (_) {/* ignore */}
      }

      // 3) Sem e-mail ou falhou auto-login: levar para Login
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
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

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;

    if (widget.email == null || widget.email!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o e-mail na etapa anterior para reenviar o código.')),
      );
      return;
    }

    try {
      await _retryOnceIfWakeUp(() {
        return _dio.post('/auth/request-reset', data: {
          'email': widget.email!.trim().toLowerCase(),
        });
      });
      await _showCodeSentAlert(reenviado: true);

      setState(() => _resendCooldown = 30);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_resendCooldown <= 1) {
          t.cancel();
          setState(() => _resendCooldown = 0);
        } else {
          setState(() => _resendCooldown--);
        }
      });
    } on DioException catch (e) {
      final msg = _errorFromDio(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e')),
      );
    }
  }

  // ---------- Helpers ----------
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

    if (code == 401 || code == 403) {
      return 'Código inválido ou expirado.';
    }
    if (code >= 500) {
      return 'Servidor indisponível ($code).';
    }
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List && m.isNotEmpty) return m.join('\n');
      return m.toString();
    }
    return 'Não foi possível redefinir a senha. Tente novamente.';
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

  Future<void> _showCodeSentAlert({bool reenviado = false}) {
    final emailTxt = widget.email != null ? ' ${widget.email}' : ' seu e-mail';
    final title = reenviado ? 'Código reenviado' : 'Código enviado';
    final msg = reenviado
        ? 'Acabamos de reenviar um código para$emailTxt.'
        : 'Um código foi enviado para$emailTxt.';

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(msg, style: GoogleFonts.poppins()),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          SizedBox(
            height: 40,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                const SizedBox(height: 6),
                Text(
                  'Esqueci minha senha',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 48),

                // Código
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: _validateCode,
                  decoration: inputDecoration('Código').copyWith(counterText: ''),
                ),

                const SizedBox(height: 8),

                // Reenviar código
                Row(
                  children: [
                    Text(
                      'Não recebeu o código? ',
                      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF4A4A55)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _resendCooldown == 0 ? _resendCode : null,
                      child: Text(
                        _resendCooldown == 0
                            ? 'Enviar novamente'
                            : 'Reenviar em ${_resendCooldown}s',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _resendCooldown == 0
                              ? AppColors.primary
                              : const Color(0xFF8B8B97),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Nova senha
                TextFormField(
                  controller: _passCtrl,
                  textInputAction: TextInputAction.next,
                  obscureText: _obscure1,
                  validator: _validatePassword,
                  decoration: inputDecoration(
                    'Nova senha',
                    helperText: 'A senha deve conter no mínimo 8 caracteres',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                      icon: Icon(
                        _obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      color: AppColors.suffix,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Confirmar nova senha
                TextFormField(
                  controller: _pass2Ctrl,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscure2,
                  validator: (v) {
                    final msg = _validatePassword(v);
                    if (msg != null) return msg;
                    if (v != _passCtrl.text) return 'As senhas não coincidem';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                  decoration: inputDecoration(
                    'Repita a nova senha',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                      icon: Icon(
                        _obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      color: AppColors.suffix,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Botão salvar
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                          )
                        : Text(
                            'Salvar senha',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
