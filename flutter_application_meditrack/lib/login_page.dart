import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // teclado

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(27, 32, 27, 16 + bottomInset),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              // Título e subtítulo
              const Text(
                "MEDITRACK",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
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
              // Inputs
              const CupertinoTextField(
                cursorColor: Color.fromARGB(255, 0, 0, 0),
                padding: EdgeInsets.all(24),
                placeholder: "Digite seu e-mail",
                placeholderStyle: TextStyle(color: Colors.black45, fontSize: 14),
                style: TextStyle(color: Colors.black87, fontSize: 14),
                decoration: BoxDecoration(
                  color: Color(0x0F000000),
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                ),
              ),
              const SizedBox(height: 18),
              const CupertinoTextField(
                cursorColor: Color.fromARGB(255, 0, 0, 0),
                padding: EdgeInsets.all(24),
                placeholder: "Digite sua senha",
                placeholderStyle: TextStyle(color: Colors.black45, fontSize: 14),
                style: TextStyle(color: Colors.black87, fontSize: 14),
                obscureText: true,
                decoration: BoxDecoration(
                  color: Color(0x0F000000),
                  borderRadius: BorderRadius.all(Radius.circular(7)),
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
                  onPressed: () {},
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
                  onPressed: () {},
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
                      // use pushNamed se preferir rotas nomeadas
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Criar uma",
                      style: TextStyle(
                        color: Color(0xFF5808DA),
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
    );
  }
}

// Tela de registro placeholder
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Register Page')),
    );
  }
}
