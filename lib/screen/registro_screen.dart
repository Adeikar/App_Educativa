import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/solicitud_docente_service.dart'; // ← NUEVO IMPORT

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
  bool _obscurePass = true;
  bool _loading = false;
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  final _fs   = FirestoreService();
  final _solicitudService = SolicitudDocenteService(); // ← NUEVO SERVICIO

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

  // ---------- Estilo unificado ----------
  InputDecoration _deco({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      suffixIcon: suffixIcon,
    );
  }

  // ---------- Validaciones ----------
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

  // ---------- Registro principal ----------
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

      // 4) Si es Docente, crear solicitud Y NOTIFICAR
      if (_rol == 'docente') {
        // Crear documento de solicitud
        final docRef = await _db.collection('solicitudes_docente').add({
          'uid'          : cred.user!.uid,
          'nombre'       : _nombreCtrl.text.trim(),
          'correo'       : _emailCtrl.text.trim().toLowerCase(),
          'pais'         : _paisCtrl.text.trim(),
          'ciudad'       : _ciudadCtrl.text.trim(),
          'area'         : _areaCtrl.text.trim(),
          'institucion'  : _instCtrl.text.trim(),
          'estado'       : 'pendiente',
          'creadoEn'     : FieldValue.serverTimestamp(),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });

        // ===== NUEVO: Notificar a administradores =====
        try {
          await _solicitudService.notificarNuevaSolicitud(
            solicitudId: docRef.id,
            nombreDocente: _nombreCtrl.text.trim(),
            correo: _emailCtrl.text.trim(),
            institucion: _instCtrl.text.trim(),
          );
          print('✅ Notificación enviada a administradores');
        } catch (e) {
          // No bloqueamos el registro si falla la notificación
          print('⚠️ Error al enviar notificación (no crítico): $e');
        }
      }

      // 5) Verificación de correo y salida
      if (!cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        await _auth.signOut();

        final extra = (_rol == 'docente')
            ? '\n\n✅ Tu solicitud para Docente fue enviada. Un administrador la revisará pronto y recibirás una notificación.'
            : '';
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Revisa tu correo'),
            content: Text(
              'Te envié un enlace a ${_emailCtrl.text.trim()} para verificar tu cuenta.$extra',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
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

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                    decoration: _deco(label: 'Rol', icon: Icons.badge),
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
                    decoration: _deco(label: 'Nombre completo', icon: Icons.person),
                    validator: _validateNombre,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _emailCtrl,
                    decoration: _deco(label: 'Correo', icon: Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    decoration: _deco(
                      label: 'Contraseña',
                      icon: Icons.lock,
                      hint: 'Mín. 8 caracteres',
                      suffixIcon: IconButton(
                        tooltip: _obscurePass ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: _validatePass,
                  ),
                  const SizedBox(height: 16),

                  // Estudiante
                  if (_rol == 'estudiante') ...[
                    TextFormField(
                      controller: _nivelEducCtrl,
                      decoration: _deco(
                        label: 'Nivel educativo (opcional)',
                        icon: Icons.school,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discapCtrl,
                      decoration: _deco(
                        label: 'Discapacidad (opcional)',
                        icon: Icons.accessibility,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Tutor
                  if (_rol == 'tutor') ...[
                    TextFormField(
                      controller: _relacionCtrl,
                      decoration: _deco(
                        label: 'Relación familiar',
                        icon: Icons.family_restroom,
                      ),
                      validator: _requiredIfTutor,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Docente
                  if (_rol == 'docente') ...[
                    TextFormField(
                      controller: _paisCtrl,
                      decoration: _deco(label: 'País', icon: Icons.public),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ciudadCtrl,
                      decoration: _deco(label: 'Ciudad', icon: Icons.location_city),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaCtrl,
                      decoration: _deco(label: 'Área', icon: Icons.work),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instCtrl,
                      decoration: _deco(label: 'Institución', icon: Icons.account_balance),
                      validator: _requiredIfDocente,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '📋 Nota: Tu solicitud será revisada por un administrador. Recibirás una notificación cuando sea aprobada.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
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