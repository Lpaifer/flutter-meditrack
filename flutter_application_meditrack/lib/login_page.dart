import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_meditrack/forget_password_page.dart';
import 'package:flutter_application_meditrack/register_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v.trim());
    if (!ok) return 'E-mail inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 8) return 'Mínimo de 8 caracteres';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // TODO: autenticar no seu backend / Firebase / Supabase
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login efetuado (mock).')),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(27, 32, 27, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  "Login",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 80),

                // E-mail (mesmo estilo da RegisterPage)
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(),
                  validator: _validateEmail,
                  decoration: inputDecoration('Digite seu e-mail'),
                ),
                const SizedBox(height: 18),

                // Senha (mesmo estilo + toggle de visibilidade)
                TextFormField(
                  controller: _passCtrl,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscure,
                  style: GoogleFonts.poppins(),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: inputDecoration(
                    'Digite sua senha',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      color: const Color(0xFF6F6F79),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text(
                      "Esqueceu a senha?",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 128),

                // Botão Entrar
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(24),
                    color: const Color(0xFF5808DA),
                    onPressed: _submit,
                    child: const Text(
                      "Entrar",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Link Criar conta
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text(
                      "Não tem uma conta? ",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                      child: const Text(
                        "Criar uma",
                        style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
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
