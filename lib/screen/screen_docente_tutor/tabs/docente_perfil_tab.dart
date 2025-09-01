// lib/screen/screen_docente_tutor/tabs/docente_perfil_tab.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DocentePerfilTab extends StatefulWidget {
  const DocentePerfilTab({super.key});

  @override
  State<DocentePerfilTab> createState() => _DocentePerfilTabState();
}

class _DocentePerfilTabState extends State<DocentePerfilTab> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _saving = false;
  XFile? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      setState(() {
        _user = snap.data();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    try {
      final p = ImagePicker();
      final x = await p.pickImage(source: ImageSource.gallery, imageQuality: 35);
      if (x != null && mounted) setState(() => _file = x);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<void> _upload() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una imagen primero')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await _file!.readAsBytes();
      final b64 = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({'fotoPerfil': b64}, SetOptions(merge: true));
      setState(() => _user = {...?_user, 'fotoPerfil': b64});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Cerrar sesión?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Se cerrará tu sesión en este dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, cerrar')),
        ],
      ),
    );
    if (ok1 != true) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmación'),
        content: const Text('¿Seguro que deseas salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok2 != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final nombre = (_user?['nombre'] as String?)?.trim().isNotEmpty == true
        ? _user!['nombre'] as String
        : 'Docente';

    final docente = (_user?['docente'] as Map<String, dynamic>?) ?? {};
    final pais = (docente['pais'] as String?)?.trim().isNotEmpty == true ? docente['pais'] : '—';
    final ciudad = (docente['ciudad'] as String?)?.trim().isNotEmpty == true ? docente['ciudad'] : '—';
    final area = (docente['area'] as String?)?.trim().isNotEmpty == true ? docente['area'] : '—';
    final institucion =
        (docente['institucion'] as String?)?.trim().isNotEmpty == true ? docente['institucion'] : '—';

    Uint8List? fotoBytes;
    final fp = _user?['fotoPerfil'];
    if (fp is String && fp.isNotEmpty) {
      try {
        fotoBytes = base64Decode(fp);
      } catch (_) {}
    }

    return Semantics(
      label: 'Perfil del docente',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header con avatar
          Center(
            child: Column(
              children: [
                Semantics(
                  label: 'Foto de perfil',
                  child: ClipOval(
                    child: Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade300,
                      child: _file != null
                          ? FutureBuilder<Uint8List>(
                              future: _file!.readAsBytes(),
                              builder: (_, s) {
                                if (s.hasData) {
                                  return Image.memory(s.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            )
                          : (fotoBytes != null
                              ? Image.memory(fotoBytes, fit: BoxFit.cover)
                              : const Icon(Icons.person, size: 60, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Elegir foto de perfil',
                      child: OutlinedButton.icon(
                        onPressed: _pick,
                        icon: const Icon(Icons.photo),
                        label: const Text('Elegir foto'),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Subir foto de perfil',
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _upload,
                        icon: _saving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: const Text('Subir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sección información (no editable, estilo estudiante)
          Text(
            'Información',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.public,
            label: 'País',
            value: '$pais',
          ),
          _InfoCard(
            icon: Icons.location_city,
            label: 'Ciudad',
            value: '$ciudad',
          ),
          _InfoCard(
            icon: Icons.work,
            label: 'Área',
            value: '$area',
          ),
          _InfoCard(
            icon: Icons.account_balance,
            label: 'Institución',
            value: '$institucion',
          ),

          const SizedBox(height: 24),
          // Cerrar sesión
          Semantics(
            button: true,
            label: 'Cerrar sesión',
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 12,
      ),
    );
  }
}
