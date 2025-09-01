// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/tema.dart';
import '../../services/tema_service.dart';

class TemasCrudScreen extends StatefulWidget {
  const TemasCrudScreen({super.key});

  @override
  State<TemasCrudScreen> createState() => _TemasCrudScreenState();
}

class _TemasCrudScreenState extends State<TemasCrudScreen> {
  final _service = TemaService();
  bool _allowed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _allowed = false;
        _loading = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final rol = doc.data()?['rol']?.toString();
    setState(() {
      _allowed = (rol == 'docente');
      _loading = false;
    });
  }

  Future<void> _openNewOrEditDialog({Tema? tema}) async {
    final form = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: tema?.nombre ?? '');
    final conceptoCtrl = TextEditingController(text: tema?.concepto ?? '');
    final editMode = tema != null;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editMode ? 'Editar Tema' : 'Nuevo Tema'),
        content: Form(
          key: form,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre (suma, resta, multiplicacion, conteo)',
                      prefixIcon: Icon(Icons.book),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nombre requerido';
                      if (!RegExp(r'^[a-z_áéíóúñ]+$', caseSensitive: false).hasMatch(v.trim())) {
                        return 'Solo letras y guiones bajos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto (breve explicación)',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Concepto requerido' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final nombre = nombreCtrl.text.trim().toLowerCase();
              final concepto = conceptoCtrl.text.trim();

              try {
                if (editMode) {
                  // si cambias el "nombre", preferimos sobrescribir por idDoc (antiguo)
                  await _service.actualizarTema(tema.id, nombre: nombre, concepto: concepto);
                } else {
                  // crear con doc(nombre)
                  await _service.crearTema(nombre: nombre, concepto: concepto);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(editMode ? 'Tema actualizado' : 'Tema creado')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(editMode ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Tema t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Seguro que deseas eliminar "${t.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.eliminarTema(t.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tema eliminado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Temas')),
        body: const Center(child: Text('No autorizado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Temas (Docente)'),
        actions: [
          IconButton(
            tooltip: 'Nuevo tema',
            onPressed: () => _openNewOrEditDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Tema>>(
        stream: _service.streamTemas(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final temas = snap.data ?? [];
          if (temas.isEmpty) {
            return const Center(child: Text('Aún no hay temas'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: temas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = temas[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(t.nombre),
                  subtitle: Text(t.concepto),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openNewOrEditDialog(tema: t),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(t),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Tema'),
      ),
    );
  }
}
