// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/tema_service.dart';
import 'temas_crud_screen.dart';

class DocenteTutorScreen extends StatefulWidget {
  final String? nombre;
  const DocenteTutorScreen({super.key, this.nombre});

  @override
  State<DocenteTutorScreen> createState() => _DocenteTutorScreenState();
}

class _DocenteTutorScreenState extends State<DocenteTutorScreen> {
  bool _loading = true;
  bool _isDocente = false;
  String _nombre = 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _isDocente = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = snap.data() ?? {};
      final rol = (data['rol'] ?? '').toString();
      final nombre = widget.nombre ?? (data['nombre'] ?? 'Usuario').toString();

      setState(() {
        _nombre = nombre;
        _isDocente = (rol == 'docente');
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _isDocente = false;
      });
    }
  }

  Future<void> _seedTemasBasicos() async {
    final service = TemaService();
    final seeds = const [
      {'nombre': 'suma', 'concepto': 'Combina cantidades. Ej: 2 + 3 = 5'},
      {'nombre': 'resta', 'concepto': 'Quita una cantidad. Ej: 5 - 2 = 3'},
      {'nombre': 'multiplicacion', 'concepto': 'Sumas repetidas. Ej: 3 × 4 = 12'},
      {'nombre': 'conteo', 'concepto': 'Enumerar elementos para conocer la cantidad.'},
    ];
    try {
      for (final t in seeds) {
        await service.crearTema(nombre: t['nombre']!, concepto: t['concepto']!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temas básicos sembrados')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isDocente) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel')),
        body: const Center(child: Text('No autorizado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel del Docente — Hola, $_nombre'),
        actions: [
          IconButton(
            tooltip: 'Gestionar Temas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemasCrudScreen()),
              );
            },
            icon: const Icon(Icons.menu_book),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Herramientas del docente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Gestionar Temas'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TemasCrudScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // OPCIONAL: botón de semilla para crear los 4 temas rápido
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Sembrar temas básicos'),
                    onPressed: _seedTemasBasicos,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aquí luego puedes agregar: lista de estudiantes, reportes, notificaciones, etc.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
