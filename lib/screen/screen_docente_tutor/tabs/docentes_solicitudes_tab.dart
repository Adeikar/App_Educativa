import 'package:app_aprendizaje/services/solicitud_docente_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DocentesSolicitudesTab extends StatefulWidget {
  const DocentesSolicitudesTab({super.key});
  @override
  State<DocentesSolicitudesTab> createState() => _DocentesSolicitudesTabState();
}

enum _View { solicitudes, gestion, papelera }

class _DocentesSolicitudesTabState extends State<DocentesSolicitudesTab> {
  final _solCol = FirebaseFirestore.instance.collection('solicitudes_docente');
  final _userCol = FirebaseFirestore.instance.collection('usuarios');
  final _solicitudService = SolicitudDocenteService();

Future<void> _aprobarSolicitud(String solicitudId, String uid) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final solRef = _solCol.doc(solicitudId);
    final userRef = _userCol.doc(uid);

    // Obtener datos de la solicitud para la notificación
    final solicitudDoc = await solRef.get();
    final nombreDocente = solicitudDoc.data()?['nombre'] ?? 'Docente';

    batch.update(solRef, {
      'estado': 'aprobada',
      'actualizadoEn': FieldValue.serverTimestamp(),
      'aprobadoEn': FieldValue.serverTimestamp(),
    });

    batch.set(
      userRef,
      {
        'rol': 'docente',
        'estado': 'activo',
        'actualizadoEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();


    await _solicitudService.notificarSolicitudAprobada(
      docenteId: uid,
      nombreDocente: nombreDocente,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Solicitud aprobada y docente notificado')));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error al aprobar: $e')));
  }
}

  _View _view = _View.solicitudes;


Future<void> _rechazarSolicitud(String solicitudId) async {
  try {
    final solicitudDoc = await _solCol.doc(solicitudId).get();
    final data = solicitudDoc.data();
    final uid = data?['uid'] as String?;
    final nombreDocente = data?['nombre'] ?? 'Docente';

    await _solCol.doc(solicitudId).update({
      'estado': 'rechazada',
      'actualizadoEn': FieldValue.serverTimestamp(),
      'rechazadoEn': FieldValue.serverTimestamp(),
    });

    if (uid != null) {
      await _solicitudService.notificarSolicitudRechazada(
        docenteId: uid,
        nombreDocente: nombreDocente,
        motivo: 'Tu solicitud ha sido revisada y no cumple con los requisitos en este momento.',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error al rechazar: $e')));
  }
}

  // ----------------------- Acciones: Gestión -----------------------
  Future<void> _activarDocente(String uid) async {
    try {
      await _userCol.doc(uid).set({
        'estado': 'activo',
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Docente activado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al activar: $e')));
    }
  }

  Future<void> _bloquearDocente(String uid) async {
    try {
      await _userCol.doc(uid).set({
        'estado': 'bloqueado',
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Docente bloqueado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al bloquear: $e')));
    }
  }

  Future<void> _moverAPapelera(String uid) async {
    try {
      await _userCol.doc(uid).set({
        'estado': 'eliminado',
        'eliminadoEn': FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enviado a la papelera')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _restaurarDocente(String uid) async {
    try {
      await _userCol.doc(uid).set({
        'estado': 'activo',
        'actualizadoEn': FieldValue.serverTimestamp(),
        'eliminadoEn': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Docente restaurado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al restaurar: $e')));
    }
  }

  Future<void> _borrarDefinitivo(String uid) async {
    try {
      await _userCol.doc(uid).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eliminado definitivamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  // ----------------------- UI -----------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _ViewSwitcher(view: _view, onChanged: (v) => setState(() => _view = v)),
        const Divider(height: 16),
        Expanded(
          child: switch (_view) {
            _View.solicitudes => _buildSolicitudes(),
            _View.gestion => _buildGestion(),
            _View.papelera => _buildPapelera(),
          },
        ),
      ],
    );
  }

  // -------- Solicitudes--------
  Widget _buildSolicitudes() {
    final stream =
        _solCol.where('estado', isEqualTo: 'pendiente').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snap.data?.docs ?? const []);
        docs.sort((a, b) {
          final ta = a.data()['creadoEn'];
          final tb = b.data()['creadoEn'];
          final sa = (ta is Timestamp)
              ? ta.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final sb = (tb is Timestamp)
              ? tb.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return sb.compareTo(sa); // desc
        });

        if (docs.isEmpty) {
          return const Center(child: Text('No hay solicitudes pendientes'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final uid = (m['uid'] ?? '').toString();

            return _SolicitudCard(
              nombre: (m['nombre'] ?? '—').toString(),
              correo: (m['correo'] ?? '—').toString(),
              pais: (m['pais'] ?? '—').toString(),
              ciudad: (m['ciudad'] ?? '—').toString(),
              area: (m['area'] ?? '—').toString(),
              institucion: (m['institucion'] ?? '—').toString(),
              onAprobar: uid.isEmpty ? null : () => _aprobarSolicitud(d.id, uid),
              onRechazar: () => _rechazarSolicitud(d.id),
            );
          },
        );
      },
    );
  }

  // -------- Gestión (activos/bloqueados) --------
  Widget _buildGestion() {

    final stream = _userCol.where('rol', isEqualTo: 'docente').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final all = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snap.data?.docs ?? const []);

        // Filtramos solo activos/bloqueados
        final docs = all.where((d) {
          final est = (d.data()['estado'] ?? '').toString();
          return est == 'activo' || est == 'bloqueado';
        }).toList();

        docs.sort((a, b) {
          final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
          final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });

        if (docs.isEmpty) {
          return const Center(child: Text('No hay docentes activos/bloqueados'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final uid = d.id;
            final nombre = (m['nombre'] ?? '—').toString();
            final correo = (m['correo'] ?? '—').toString();
            final estado = (m['estado'] ?? '—').toString();

            final isActivo = estado == 'activo';

            return Card(
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(child: Icon(Icons.person)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(correo,
                                style:
                                    const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _EstadoPill(
                        text: isActivo ? 'Activo' : 'Bloqueado',
                        color: isActivo ? Colors.green : Colors.red,
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _moverAPapelera(uid),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Papelera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isActivo
                            ? OutlinedButton.icon(
                                onPressed: () => _bloquearDocente(uid),
                                icon: const Icon(Icons.lock_outline,
                                    color: Colors.red),
                                label: const Text('Bloquear',
                                    style: TextStyle(color: Colors.red)),
                              )
                            : FilledButton.icon(
                                onPressed: () => _activarDocente(uid),
                                icon: const Icon(Icons.lock_open),
                                label: const Text('Activar'),
                              ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------- Papelera (eliminados) --------
  Widget _buildPapelera() {

    final stream = _userCol.where('rol', isEqualTo: 'docente').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snap.data?.docs ?? const [])
          ..retainWhere((d) => (d.data()['estado'] ?? '') == 'eliminado');

        docs.sort((a, b) {
          final ta = a.data()['eliminadoEn'];
          final tb = b.data()['eliminadoEn'];
          final sa = (ta is Timestamp)
              ? ta.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final sb = (tb is Timestamp)
              ? tb.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return sb.compareTo(sa);
        });

        if (docs.isEmpty) {
          return const Center(child: Text('La papelera está vacía'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();
            final uid = d.id;
            final nombre = (m['nombre'] ?? '—').toString();
            final correo = (m['correo'] ?? '—').toString();

            return Card(
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(child: Icon(Icons.person_off)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(correo,
                                style:
                                    const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _EstadoPill(text: 'En papelera', color: Colors.orange),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _restaurarDocente(uid),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restaurar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(uid),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Borrar definitivo',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar definitivamente'),
        content: const Text(
          'Esta acción eliminará el documento del docente en Firestore. '
          'No se podrá deshacer (no borra la cuenta de Auth).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) {
      await _borrarDefinitivo(uid);
    }
  }
}

// --------- Widgets auxiliares ---------
class _ViewSwitcher extends StatelessWidget {
  final _View view;
  final ValueChanged<_View> onChanged;
  const _ViewSwitcher({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Solicitudes'),
          selected: view == _View.solicitudes,
          onSelected: (_) => onChanged(_View.solicitudes),
        ),
        ChoiceChip(
          label: const Text('Gestión'),
          selected: view == _View.gestion,
          onSelected: (_) => onChanged(_View.gestion),
        ),
        ChoiceChip(
          label: const Text('Papelera'),
          selected: view == _View.papelera,
          onSelected: (_) => onChanged(_View.papelera),
        ),
      ],
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  final String nombre, correo, pais, ciudad, area, institucion;
  final VoidCallback? onAprobar;
  final VoidCallback onRechazar;
  const _SolicitudCard({
    required this.nombre,
    required this.correo,
    required this.pais,
    required this.ciudad,
    required this.area,
    required this.institucion,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(correo, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EstadoPill(text: 'Pendiente', color: Colors.orange),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _ChipInfo(icon: Icons.public, label: 'País', value: pais),
                _ChipInfo(icon: Icons.location_city, label: 'Ciudad', value: ciudad),
                _ChipInfo(icon: Icons.work, label: 'Área', value: area),
                _ChipInfo(icon: Icons.account_balance, label: 'Institución', value: institucion),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRechazar,
                  icon: const Icon(Icons.block, color: Colors.red),
                  label: const Text('Rechazar',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAprobar,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Aprobar'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ChipInfo({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
      side: const BorderSide(color: Colors.black12),
      backgroundColor: Colors.grey.shade50,
    );
  }
}

class _EstadoPill extends StatelessWidget {
  final String text;
  final Color color;
  const _EstadoPill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
