// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  final _auth = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'El correo es requerido';
    final email = v.trim();
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(email)) return 'Correo inválido';
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es requerida';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    // Fuerte: 1 mayúscula, 1 minúscula, 1 número, 1 símbolo
    final upper = RegExp(r'[A-Z]');
    final lower = RegExp(r'[a-z]');
    final num   = RegExp(r'[0-9]');
    final sym   = RegExp(r'[!@#\$%\^&\*\(\)_\-\+=\{\}\[\]:;\"\<>,\.\?\/\\]');
    if (!upper.hasMatch(v)) return 'Incluye al menos una mayúscula';
    if (!lower.hasMatch(v)) return 'Incluye al menos una minúscula';
    if (!num.hasMatch(v))   return 'Incluye al menos un número';
    if (!sym.hasMatch(v))   return 'Incluye al menos un símbolo';
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    try {
      final cred = await _auth.signIn(email, pass);

      // Si no está verificado, se envía verificación y no entra
      if (!cred.user!.emailVerified) {
        await _auth.sendEmailVerification(cred.user!);
        await _auth.signOut();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verifica tu correo'),
            content: Text('Te envié un enlace a $email. Verifica y vuelve a iniciar sesión.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok'))],
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');

    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-credential':
          msg = 'Correo o contraseña incorrectos';
          break;
        case 'user-disabled':
          msg = 'Tu cuenta fue deshabilitada';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde';
          break;
        case 'network-request-failed':
          msg = 'Sin conexión. Reintenta';
          break;
        case 'user-not-found':
          msg = 'Ese correo no está registrado';
          break;
        case 'wrong-password':
          msg = 'Contraseña incorrecta';
          break;
        default:
          msg = 'Error de autenticación: ${e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu correo para enviarte el enlace')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te envié un enlace para restablecer tu contraseña')),
      );
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'invalid-email')
          ? 'Correo inválido'
          : 'No pude enviar el correo: ${e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicia sesión')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: _validatePass,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                  ),
                  TextButton(onPressed: _forgot, child: const Text('¿Olvidaste tu contraseña?')),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/registro'),
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
