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
        title: Text(editMode ? 'Editar tema' : 'Nuevo tema'),
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
                      prefixIcon: Icon(Icons.menu_book),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nombre requerido';
                      if (!RegExp(r'^[a-z_áéíóúñ]+$', caseSensitive: false).hasMatch(v.trim())) {
                        return 'Solo letras (sin espacios)';
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
                  await _service.actualizarTema(tema.id, nombre: nombre, concepto: concepto);
                } else {
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed) {
      return Scaffold(
        appBar: const _TemasHeaderAppBar(),
        body: const Center(child: Text('No autorizado')),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: ColorScheme.fromSeed(seedColor: Colors.blue).surfaceContainerLowest,
      appBar: const _TemasHeaderAppBar(),
      body: SafeArea(
        child: StreamBuilder<List<Tema>>(
          stream: _service.streamTemas(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final temas = snap.data ?? [];
            if (temas.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 64, color: cs.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Aún no hay temas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Crea tus primeros contenidos desde el botón “Nuevo tema”.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: temas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = temas[i];
                return Card(
                  elevation: 1.5,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.menu_book, color: cs.onPrimaryContainer),
                    ),
                    title: Text(
                      t.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      t.concepto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo tema'),
      ),
    );
  }
}

/// AppBar con el mismo look & feel del panel del docente
class _TemasHeaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TemasHeaderAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 96,
      elevation: 0,
      automaticallyImplyLeading: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.primary.withOpacity(0.90)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.onPrimary.withOpacity(0.15),
              child: Icon(Icons.menu_book, color: cs.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Gestionar Temas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Crea, edita y elimina contenidos',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onPrimary.withOpacity(0.95),
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ayuda',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Consejos rápidos'),
                    content: const Text(
                      '• Usa “Nuevo tema” para crear contenidos (suma, resta, etc.).\n'
                      '• Cada tema tiene un “concepto” breve para los estudiantes.\n'
                      '• Puedes editar o eliminar desde los íconos del listado.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.help_outline, color: cs.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
