// Lista de estudiantes vinculados + buscar + Acciones (Vincular / Gestionar temas)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DocenteInicioTab extends StatefulWidget {
  final void Function(String estudianteId, String estudianteNombre) onOpenReport;
  const DocenteInicioTab({super.key, required this.onOpenReport});

  @override
  State<DocenteInicioTab> createState() => _DocenteInicioTabState();
}

class _DocenteInicioTabState extends State<DocenteInicioTab> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _items = [];
        _filtered = [];
        _loading = false;
      });
      return;
    }

    try {
      final vSnap = await FirebaseFirestore.instance
          .collection('vinculaciones')
          .where('docenteId', isEqualTo: uid)
          .where('estado', isEqualTo: 'activa')
          .get();

      final list = <Map<String, dynamic>>[];
      for (final v in vSnap.docs) {
        final data = v.data();
        final estId = data['estudianteId'] as String?;
        if (estId == null) continue;

        final estDoc = await FirebaseFirestore.instance.collection('usuarios').doc(estId).get();
        if (!estDoc.exists) continue;

        final u = estDoc.data()!;
        list.add({
          'vinculacionId': v.id,
          'estudianteId'  : estId,
          'nombre'        : u['nombre'] ?? 'Estudiante',
          'email'         : u['email'] ?? '',
          'nivelEducativo': u['nivelEducativo'] ?? u['estudiante']?['nivelEducativo'] ?? '—',
          'fotoPerfil'    : u['fotoPerfil'] ?? '',
        });
      }

      setState(() {
        _items = list..sort((a,b)=> (a['nombre'] as String).compareTo(b['nombre'] as String));
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar: $e')),
      );
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.of(_items);
    } else {
      _filtered = _items.where((e) {
        final n = (e['nombre'] as String).toLowerCase();
        final em = (e['email'] as String).toLowerCase();
        final niv = (e['nivelEducativo'] as String).toLowerCase();
        return n.contains(q) || em.contains(q) || niv.contains(q);
      }).toList();
    }
    setState(() {});
  }

  // ---------- Acciones (bottom sheet) ----------
  void _showAcciones() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.link, color: cs.primary),
                title: const Text('Vincular alumno'),
                subtitle: const Text('Ingresar código de vinculación'),
                onTap: () {
                  Navigator.pop(context);
                  _vincularPorCodigo();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.menu_book, color: cs.primary),
                title: const Text('Gestionar temas'),
                subtitle: const Text('Crear, editar y eliminar contenidos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/temas_crud');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _vincularPorCodigo() async {
    final ctrl = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vincular estudiante'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Código de vinculación',
            hintText: 'Ej: ABC123',
            prefixIcon: Icon(Icons.key),
          ),
          onSubmitted: (_) => Navigator.pop(context, ctrl.text.trim()),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: ()=> Navigator.pop(context, ctrl.text.trim()), child: const Text('Vincular')),
        ],
      ),
    );

    if (code == null || code.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Buscar estudiante por código
      final q = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'estudiante')
          .where('estudiante.codigoVinculacion', isEqualTo: code)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código no válido o estudiante no encontrado')),
        );
        return;
      }

      final est = q.docs.first;
      final estId = est.id;

      // ¿ya vinculado con este docente?
      final dup = await FirebaseFirestore.instance
          .collection('vinculaciones')
          .where('estudianteId', isEqualTo: estId)
          .where('docenteId', isEqualTo: uid)
          .where('estado', isEqualTo: 'activa')
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese estudiante ya está vinculado contigo')),
        );
        return;
      }

      // Crear vinculación
      await FirebaseFirestore.instance.collection('vinculaciones').add({
        'estudianteId': estId,
        'docenteId'   : uid,
        'tutorId'     : null,
        'estado'      : 'activa',
        'codigoVinculacion': code,
        'fechaVinculacion' : FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Vinculación exitosa!')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al vincular: $e')),
      );
    }
  }

  void _showFicha(Map<String, dynamic> est) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16,16,16,32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.blue.shade200,
              child: const Icon(Icons.person, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 8),
            Text(est['nombre'] ?? 'Estudiante', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(est['email'] ?? '', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text('Nivel: ${est['nivelEducativo']}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ()=> Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenReport(est['estudianteId'], est['nombre'] ?? 'Estudiante');
                    },
                    icon: const Icon(Icons.assessment),
                    label: const Text('Ver progreso'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Semantics(
                label: 'Buscar estudiante por nombre, correo o nivel',
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar estudiante...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No hay estudiantes vinculados'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final e = _filtered[i];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(e['nombre'] ?? 'Estudiante'),
                            subtitle: Text('Nivel: ${e['nivelEducativo']}'),
                            trailing: FilledButton(
                              onPressed: () => widget.onOpenReport(e['estudianteId'], e['nombre'] ?? 'Estudiante'),
                              child: const Text('Progreso'),
                            ),
                            onTap: () => _showFicha(e),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),

        // FAB “Acciones” (flotante dentro del tab)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _showAcciones,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Acciones'),
          ),
        ),
      ],
    );
  }
}
