// RegistroScreen: guarda como 'docente_solicitado' y crea solicitud para admins.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // Form y controladores
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  // Rol y campos extra
  String _rol = 'estudiante';
  final _nivelEducCtrl = TextEditingController();
  final _discapCtrl    = TextEditingController();
  final _relacionCtrl  = TextEditingController();
  final _paisCtrl   = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _areaCtrl   = TextEditingController();
  final _instCtrl   = TextEditingController();

  // Estado y servicios
  bool _loading = false;
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  final _fs   = FirestoreService();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nivelEducCtrl.dispose();
    _discapCtrl.dispose();
    _relacionCtrl.dispose();
    _paisCtrl.dispose();
    _ciudadCtrl.dispose();
    _areaCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  // Validaciones simples
  String? _validateNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
    if (v.trim().length > 80) return 'Máximo 80 caracteres';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'El correo es requerido';
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(v.trim())) return 'Correo inválido';
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es requerida';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    final upper = RegExp(r'[A-Z]');
    final lower = RegExp(r'[a-z]');
    final num   = RegExp(r'[0-9]');
    final sym   = RegExp(r'[!@#\$%\^&\*\(\)_\-\+=\{\}\[\]:;\"\,<>,\.\?\/\\]');
    if (!upper.hasMatch(v)) return 'Incluye al menos una mayúscula';
    if (!lower.hasMatch(v)) return 'Incluye al menos una minúscula';
    if (!num.hasMatch(v))   return 'Incluye al menos un número';
    if (!sym.hasMatch(v))   return 'Incluye al menos un símbolo';
    return null;
  }

  String? _requiredIfTutor(String? v) {
    if (_rol == 'tutor' && (v == null || v.trim().isEmpty)) {
      return 'Requerido para tutor';
    }
    return null;
  }

  String? _requiredIfDocente(String? v) {
    if (_rol == 'docente' && (v == null || v.trim().isEmpty)) {
      return 'Requerido para docente';
    }
    return null;
  }

  // Registro principal
  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // 1) Alta en Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user!.updateDisplayName(_nombreCtrl.text.trim());

      // 2) Rol a guardar ('docente_solicitado' si eligió Docente)
      final rolAguardar = (_rol == 'docente') ? 'docente_solicitado' : _rol;

      // 3) Guardar en 'usuarios'
      await _fs.guardarUsuario(
        uid: cred.user!.uid,
        nombre: _nombreCtrl.text.trim(),
        correo: _emailCtrl.text.trim(),
        rol: rolAguardar,
        nivelEducativo: _nivelEducCtrl.text,
        discapacidad: _discapCtrl.text,
        relacionFamiliar: _relacionCtrl.text,
        pais: _paisCtrl.text,
        ciudad: _ciudadCtrl.text,
        area: _areaCtrl.text,
        institucion: _instCtrl.text,
      );

      // 4) Si es Docente, crear solicitud
      if (_rol == 'docente') {
        await _db.collection('solicitudes_docente').add({
          'uid'         : cred.user!.uid,
          'nombre'      : _nombreCtrl.text.trim(),
          'correo'      : _emailCtrl.text.trim().toLowerCase(),
          'pais'        : _paisCtrl.text.trim(),
          'ciudad'      : _ciudadCtrl.text.trim(),
          'area'        : _areaCtrl.text.trim(),
          'institucion' : _instCtrl.text.trim(),
          'estado'      : 'pendiente',
          'creadoEn'    : FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }

      // 5) Verificación de correo y salida
      if (!cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        await _auth.signOut();

        final extra = (_rol == 'docente')
            ? '\n\nTu solicitud para Docente fue enviada. Un administrador debe aprobarla antes de que puedas ingresar.'
            : '';
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Revisa tu correo'),
            content: Text(
              'Te envié un enlace a ${_emailCtrl.text.trim()} para verificar tu cuenta.$extra',
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'Ese correo ya está registrado',
        'invalid-email'        => 'Correo inválido',
        'weak-password'        => 'La contraseña es muy débil',
        _ => 'Error de autenticación: ${e.code}',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rol
                  DropdownButtonFormField<String>(
                    value: _rol,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'estudiante', child: Text('Estudiante')),
                      DropdownMenuItem(value: 'docente', child: Text('Docente')),
                      DropdownMenuItem(value: 'tutor', child: Text('Tutor')),
                    ],
                    onChanged: (v) => setState(() => _rol = v!),
                  ),
                  const SizedBox(height: 12),

                  // Básicos
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: _validateNombre,
                  ),
                  const SizedBox(height: 12),
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
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: _validatePass,
                  ),
                  const SizedBox(height: 16),

                  // Estudiante
                  if (_rol == 'estudiante') ...[
                    TextFormField(
                      controller: _nivelEducCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nivel educativo (opcional)',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discapCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Discapacidad (opcional)',
                        prefixIcon: Icon(Icons.accessibility),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Tutor
                  if (_rol == 'tutor') ...[
                    TextFormField(
                      controller: _relacionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Relación familiar',
                        prefixIcon: Icon(Icons.family_restroom),
                      ),
                      validator: _requiredIfTutor,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Docente
                  if (_rol == 'docente') ...[
                    TextFormField(
                      controller: _paisCtrl,
                      decoration: const InputDecoration(
                        labelText: 'País',
                        prefixIcon: Icon(Icons.public),
                      ),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ciudadCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Área',
                        prefixIcon: Icon(Icons.work),
                      ),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Institución',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Nota: si eliges Docente, tu cuenta quedará en revisión por un administrador.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Botón
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _registrar,
                      child: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Crear cuenta'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Ya tengo cuenta'),
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
