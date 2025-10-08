import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_meditrack/home_page.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:google_fonts/google_fonts.dart';

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

  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Mostra o alerta quando a tela renderiza pela primeira vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCodeSentAlert(); // "Um código foi enviado ao seu e-mail ..."
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

    setState(() => _isSubmitting = true);

    // TODO: chamar backend para validar código e atualizar senha
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha atualizada com sucesso!')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;

    // TODO: chamar API para reenviar o código
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
  }

  // ---------- Alerta ----------
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
      backgroundColor: Colors.white,
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
                // Campo Código
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

                // Reenviar
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

                // Repita a nova senha
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
