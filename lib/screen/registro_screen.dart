import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _nombre = TextEditingController();
  String _rol = 'estudiante';

  final _auth = AuthService();
  final _db = FirestoreService();
  final _uuid = const Uuid();

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    try {
      final cred = await _auth.signUp(_email.text.trim(), _pass.text.trim());
      final uid = cred.user!.uid;

      final Map<String, dynamic> data = {
        'uid': uid,
        'nombre': _nombre.text.trim(),
        'correo': _email.text.trim(),
        'rol': _rol,
        'estado': 'activo',
        'ultimoAcceso': DateTime.now().toIso8601String(),
      };

      if (_rol == 'estudiante') {
        data['estudiante'] = {
          'codigoVinculacion': _uuid.v4().substring(0, 6).toUpperCase(),
        };
      } else if (_rol == 'docente') {
        data['docente'] = {};
      } else if (_rol == 'tutor') {
        data['tutor'] = {};
      }

      await _db.upsertUser(uid, data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error al registrar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: _rol,
                  items: const [
                    DropdownMenuItem(value: 'estudiante', child: Text('Estudiante')),
                    DropdownMenuItem(value: 'docente', child: Text('Docente')),
                    DropdownMenuItem(value: 'tutor', child: Text('Tutor')),
                  ],
                  onChanged: (v) => setState(() => _rol = v!),
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                TextFormField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6' : null,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _registrar, child: const Text('Crear cuenta')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
