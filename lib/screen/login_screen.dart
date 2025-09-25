import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores y variables de estado para el login.
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _auth = AuthService();

  bool _sendingReset = false;
  bool _loading = false;
  bool _obscure = true;
  bool _easyMode = true; // Modo sencillo por defecto (validación ligera).
  String? _errorMsg;      // Mensaje de error que aparece en el formulario.

  @override
  void dispose() {
    // Liberamos memoria de los controladores.
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Lógica de Validación de Correo
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
    final email = v.trim();
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(email)) return 'Revisa el formato del correo';
    return null;
  }

  // Lógica de Validación de Contraseña 
  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Escribe tu contraseña';
    if (_easyMode) return null; // Si está en modo sencillo, solo pide que no esté vacía.
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

  // Lógica Principal de Login y Verificación de Correo
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

      // Verifica si el correo ya fue confirmado.
      if (!cred.user!.emailVerified) {
        // Si no está verificado, enviamos el enlace de nuevo y cerramos la sesión para forzar la verificación.
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

      // Si todo está bien, navegamos a la pantalla principal.
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

  // Lógica de Recuperación de Contraseña
  Future<void> _forgot() async {
    setState(() => _errorMsg = null);

  
    final email = _emailCtrl.text.trim();
    final emailErr = _validateEmail(email);
    if (emailErr != null) {
      setState(() => _errorMsg = emailErr);
      return;
    }

    //Confirmación para evitar envíos accidentales. Muestra un diálogo.
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Enviar enlace de recuperación?'),
        content: Text('Te enviaremos un correo a:\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ),
    );

    if (ok != true) return;

    // 3) Envío con loading y manejo de errores específicos de la acción de reset.
    setState(() => _sendingReset = true);
    try {
      await _auth.sendPasswordResetEmail(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo. Revisa tu correo para cambiar la contraseña.')),
      );
    } on FirebaseAuthException catch (e) {
      // Manejo de errores específicos del envío del correo de recuperación.
      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = 'El correo no tiene un formato válido.';
          break;
        case 'user-not-found':
          msg = 'No existe una cuenta con ese correo.';
          break;
        case 'network-request-failed':
          msg = 'Sin conexión. Inténtalo de nuevo.';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Espera un momento.';
          break;
        default:
          msg = 'No pudimos enviar el enlace. Inténtalo de nuevo más tarde.';
      }
      setState(() => _errorMsg = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

 // El resto del código es la construcción de la interfaz de usuario

  @override
  Widget build(BuildContext context) {
    // Construcción de la interfaz de usuario del login.
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
                    // Encabezado visual superior.
                    _HeaderWelcome(),
                    const SizedBox(height: 16),

                    // Tarjeta con formulario de login.
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
                              // Texto de apoyo introductorio.
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

                              // Banner de error en caso de fallo.
                              if (_errorMsg != null) ...[
                                _ErrorBanner(msg: _errorMsg!),
                                const SizedBox(height: 8),
                              ],

                              // Campo de correo electrónico.
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

                              // Campo de contraseña con botón mostrar/ocultar.
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

                              // Consejos de contraseña en modo detallado.
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

                              // Botón principal de login.
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

                              // Botones secundarios: recuperar contraseña y crear cuenta.
                              const SizedBox(height: 8),
                              Row(
                                    children: [
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        icon: _sendingReset
                                            ? const SizedBox(
                                                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Icon(Icons.mark_email_read_outlined, size: 18), 
                                        onPressed: (_loading || _sendingReset) ? null : _forgot,
                                        label: const Text('Olvidé mi contraseña'),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.person_add_alt_1, size: 19),
                                        onPressed: _loading
                                            ? null
                                            : () => Navigator.pushReplacementNamed(context, '/registro'),
                                        label: const Text('Crear cuenta nueva'),
                                      ),
                                    ],
                                  ),

                              const Divider(height: 20),

                              // Switch para cambiar entre modo sencillo y detallado.
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

                    // Nota final de confianza para el usuario.
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

// Encabezado visual con icono y saludo.
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

// Widget con consejos para crear contraseñas seguras.
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

// Línea individual usada en la lista de consejos.
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

// Banner de error rojo con ícono y texto claro.
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
