import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/login_page.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.onTapEntrar});

  /// Callback quando clica em "Entrar"
  final VoidCallback? onTapEntrar;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSubmitting = false;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o email';
    final email = v.trim();
    final ok = RegExp(r"^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$").hasMatch(email);
    if (!ok) return 'Email inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 8) return 'Mínimo de 8 caracteres';
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    setState(() => _isSubmitting = true);

    // TODO: integrar com seu backend/Firebase/Supabase
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conta criada com sucesso!')),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'MEDITRACK',
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      letterSpacing: 2,
                      color: const Color(0xFF9DA0A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Criar Conta',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3A2E7C),
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Nome completo
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.poppins(),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe seu nome completo' : null,
                    decoration: inputDecoration('Nome completo'),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(),
                    validator: _validateEmail,
                    decoration: inputDecoration('Email'),
                  ),
                  const SizedBox(height: 16),

                  // Senha
                  TextFormField(
                    controller: _passCtrl,
                    textInputAction: TextInputAction.next,
                    obscureText: _obscure1,
                    style: GoogleFonts.poppins(),
                    validator: _validatePassword,
                    decoration: inputDecoration(
                      'Senha',
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

                  // Repita a senha
                  TextFormField(
                    controller: _pass2Ctrl,
                    textInputAction: TextInputAction.done,
                    obscureText: _obscure2,
                    style: GoogleFonts.poppins(),
                    validator: (v) {
                      final msg = _validatePassword(v);
                      if (msg != null) return msg;
                      if (v != _passCtrl.text) return 'As senhas não coincidem';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                    decoration: inputDecoration(
                      'Repita a senha',
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

                  // Botão Criar conta (com loader)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Criar conta',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Já tem uma conta? ',
                      style: GoogleFonts.poppins(color: const Color(0xFF8B8B97)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          // se o Register foi aberto a partir do Login, apenas volta
                          Navigator.pop(context);
                        } else {
                          // se chegou aqui por deep link ou outra rota, abre o Login
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        }
                      },
                      child: Text(
                        'Entrar',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
