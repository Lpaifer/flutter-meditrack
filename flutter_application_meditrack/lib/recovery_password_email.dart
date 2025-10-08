import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/forget_password_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/register_page.dart';


class SendResetCodePage extends StatefulWidget {
  const SendResetCodePage({super.key});

  @override
  State<SendResetCodePage> createState() => _SendResetCodePageState();
}

class _SendResetCodePageState extends State<SendResetCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);

    // TODO: chame sua API (NestJS/Firebase/etc.) para enviar o código ao e-mail
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Leva para a página que digita o código (ela já mostra o alerta de "código enviado")
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(email: _emailCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),
                // Subtítulo
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

                // Título
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

                // Campo de e-mail
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: inputDecoration('Digite seu email'),
                ),

                const SizedBox(height: 48),

                // Botão "Entrar" (enviar código) — pode trocar o texto para "Enviar código"
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
                            // troque para 'Enviar código' se preferir
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Link "Não tem uma conta? Criar uma"
                Row(
                  children: [
                    Text(
                      'Não tem uma conta? ',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF8B8B97),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: Text(
                        'Criar uma',
                        style: GoogleFonts.poppins(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
