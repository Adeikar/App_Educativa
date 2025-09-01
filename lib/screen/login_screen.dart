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
  final _passCtrl = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;
  bool _obscure = true;
  bool _easyMode = true; // <-- Modo sencillo por defecto
  String? _errorMsg;     // <-- Mensaje corto y claro arriba del formulario

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Validaciones suaves: en modo sencillo no exigimos contraseña “fuerte”.
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
    final email = v.trim();
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(email)) return 'Revisa el formato del correo';
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Escribe tu contraseña';
    if (_easyMode) return null;
    if (v.length < 8) return 'Mínimo 8 caracteres';
    final upper = RegExp(r'[A-Z]');
    final lower = RegExp(r'[a-z]');
    final num   = RegExp(r'[0-9]');
    final sym   = RegExp(r'[!@#\$%\^&\*\(\)_\-\+=\{\}\[\]:;\"<>,\.\?\/\\]');
    if (!upper.hasMatch(v)) return 'Agrega una mayúscula';
    if (!lower.hasMatch(v)) return 'Agrega una minúscula';
    if (!num.hasMatch(v))   return 'Agrega un número';
    if (!sym.hasMatch(v))   return 'Agrega un símbolo';
    return null;
  }

  Future<void> _login() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMsg = 'Revisa lo que falta arriba.');
      return;
    }

    setState(() => _loading = true);
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    try {
      final cred = await _auth.signIn(email, pass);

      // Si el correo no está verificado, mensaje breve y claro
      if (!cred.user!.emailVerified) {
        await _auth.sendEmailVerification(cred.user!);
        await _auth.signOut();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verifica tu correo'),
            content: Text(
              'Te enviamos un enlace a:\n$email\n\nAbre el correo y vuelve a iniciar sesión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
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
        case 'user-not-found':
        case 'wrong-password':
          msg = 'Correo o contraseña incorrectos';
          break;
        case 'user-disabled':
          msg = 'Tu cuenta está deshabilitada';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Espera un momento';
          break;
        case 'network-request-failed':
          msg = 'Sin internet. Reintenta';
          break;
        default:
          msg = 'No pudimos iniciar sesión';
      }
      setState(() => _errorMsg = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Escribe tu correo arriba para enviarte el enlace.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te enviamos un enlace para cambiar tu contraseña')),
      );
    } on FirebaseAuthException catch (_) {
      setState(() => _errorMsg = 'No pudimos enviar el enlace. Revisa el correo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.2);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: textScale),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Encabezado amigable y de alto contraste
                    _HeaderWelcome(),
                    const SizedBox(height: 16),

                    // Tarjeta con formulario
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Mensaje de apoyo (lenguaje simple)
                              Semantics(
                                header: true,
                                child: Text(
                                  'Ingresa tus datos para entrar',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Si te equivocas, no pasa nada. Vamos paso a paso 🙂',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),

                              // Banner de error claro
                              if (_errorMsg != null) ...[
                                _ErrorBanner(msg: _errorMsg!),
                                const SizedBox(height: 8),
                              ],

                              // Campo correo
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: 'Correo',
                                  hintText: 'tucorreo@ejemplo.com',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 12),

                              // Campo contraseña
                              TextFormField(
                                controller: _passCtrl,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  hintText: _easyMode ? 'Escríbela aquí' : 'Mín. 8 caracteres',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: _obscure,
                                validator: _validatePass,
                                onFieldSubmitted: (_) => _loading ? null : _login(),
                              ),

                              // Ayuda visual de contraseña (solo en modo detallado)
                              AnimatedCrossFade(
                                firstChild: const SizedBox.shrink(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _PasswordHint(),
                                ),
                                crossFadeState: _easyMode
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                                duration: const Duration(milliseconds: 180),
                              ),

                              const SizedBox(height: 16),

                              // Botón Entrar: grande y de alto contraste
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: _loading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  onPressed: _loading ? null : _login,
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Entrar', style: TextStyle(fontSize: 18)),
                                  ),
                                ),
                              ),

                              // Acciones secundarias, separadas visualmente
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.help_outline, size: 18),
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _loading ? null : _forgot,
                                    child: const Text('Olvidé mi contraseña'),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.person_add_alt_1, size: 18),
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pushReplacementNamed(context, '/registro'),
                                    child: const Text('Crear cuenta nueva'),
                                  ),
                                ],
                              ),

                              const Divider(height: 20),

                              // Conmutador de Modo sencillo/detallado (lenguaje llano)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Modo sencillo'),
                                subtitle: const Text(
                                  'Textos simples y menos requisitos.\n'
                                  'Puedes desactivarlo si prefieres más detalle.',
                                ),
                                value: _easyMode,
                                onChanged: (v) => setState(() => _easyMode = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Nota amable y corta
                    Text(
                      'Tus datos están protegidos. Si necesitas ayuda, pide apoyo a tu docente o tutor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado grande con alto contraste y pictograma.
class _HeaderWelcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primary.withOpacity(0.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.onPrimary.withOpacity(0.15),
            child: Icon(Icons.school, color: cs.onPrimary, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bienvenido/a',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de reglas de contraseña (solo se muestra en modo detallado).
class _PasswordHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consejos para tu contraseña:', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          _HintLine(text: '• Usa mínimo 8 caracteres'),
          _HintLine(text: '• Incluye MAYÚSCULAS y minúsculas'),
          _HintLine(text: '• Agrega números (0–9)'),
          _HintLine(text: '• Agrega un símbolo (por ejemplo: @, #, !)'),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  final String text;
  const _HintLine({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }
}

/// Banner de error de alto contraste con lenguaje simple.
class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner({required this.msg});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Error',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.10),
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
