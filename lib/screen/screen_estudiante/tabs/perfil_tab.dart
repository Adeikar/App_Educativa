// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


class PerfilTab extends StatefulWidget {
  final String nombre;
  const PerfilTab({super.key, required this.nombre});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  bool _loading = true;
  Map<String, dynamic>? _userData;
  XFile? _picked;
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _userData = null;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      setState(() {
        _userData = doc.data();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar perfil: $e')),
      );
    }
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _picked = x;
      _preview = bytes;
    });
  }

  Future<void> _savePhoto() async {
    if (_preview == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final base64img = base64Encode(_preview!);
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
        {'fotoPerfil': base64img},
        SetOptions(merge: true),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto actualizada')),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar foto: $e')),
      );
    }
  }

  Future<void> _logout() async {
    // Confirmación 1
    final c1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (c1 != true) return;

    // Confirmación 2
    final c2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('De verdad, ¿deseas salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, salir')),
        ],
      ),
    );
    if (c2 != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final email = FirebaseAuth.instance.currentUser?.email ?? '—';
    final rol = _userData?['rol']?.toString() ?? '—';
    final nivel = (_userData?['nivelEducativo']?.toString() ?? '').isEmpty
        ? 'No especificado'
        : _userData!['nivelEducativo'].toString();
    final disc = (_userData?['discapacidad']?.toString() ?? '').isEmpty
        ? 'No especificado'
        : _userData!['discapacidad'].toString();
    final codigo = _userData?['estudiante']?['codigoVinculacion']?.toString() ?? 'No asignado';

    Uint8List? foto;
    final f = _userData?['fotoPerfil'];
    if (f is String && f.isNotEmpty) {
      try {
        foto = base64Decode(f);
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: _preview != null
                ? MemoryImage(_preview!)
                : (foto != null ? MemoryImage(foto) : null),
            child: (foto == null && _preview == null)
                ? const Icon(Icons.person, size: 48, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo),
              label: const Text('Seleccionar'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _preview == null ? null : _savePhoto,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Guardar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Nombre'),
            subtitle: Text(widget.nombre),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Correo'),
            subtitle: Text(email),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Rol'),
            subtitle: Text(rol),
          ),
        ),
        if (rol == 'estudiante') ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Nivel educativo'),
              subtitle: Text(nivel),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.accessibility_new),
              title: const Text('Discapacidad'),
              subtitle: Text(disc),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Código de vinculación'),
              subtitle: Text(codigo),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }
}
