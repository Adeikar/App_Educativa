import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:app_aprendizaje/services/notification_service.dart';

class DocenteNotificacionesTab extends StatefulWidget {
  const DocenteNotificacionesTab({super.key});

  @override
  State<DocenteNotificacionesTab> createState() => _DocenteNotificacionesTabState();
}

class _DocenteNotificacionesTabState extends State<DocenteNotificacionesTab> {
  final _notifService = NotificationService();

  String _formatFecha(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return DateFormat('dd/MM/yy HH:mm').format(date);
  }

  String _formatDuracion(int segundos) {
    final min = segundos ~/ 60;
    final seg = segundos % 60;
    if (min == 0) return '${seg}s';
    return '${min}m ${seg}s';
  }

  Color _colorPorcentaje(int porcentaje) {
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _iconTema(String tema) {
    switch (tema.toLowerCase()) {
      case 'suma': return Icons.add_circle;
      case 'resta': return Icons.remove_circle;
      case 'multiplicacion': return Icons.close;
      case 'conteo': return Icons.format_list_numbered;
      default: return Icons.school;
    }
  }

  Color _colorTema(String tema) {
    switch (tema.toLowerCase()) {
      case 'suma': return Colors.green;
      case 'resta': return Colors.red;
      case 'multiplicacion': return Colors.blue;
      case 'conteo': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildNotificacionCard(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  final leida = data['leida'] as bool? ?? false;
  final tipo = data['tipo'] as String? ?? 'desconocido';
  final fecha = data['fecha'] as Timestamp?;
  final fechaFormat = _formatFecha(fecha);

  // 1. SOLICITUD APROBADA (Dirigido al Docente/Tutor)
  if (tipo == 'solicitud_aprobada') {
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _notifService.eliminarNotificacion(doc.id),
      child: Card(
        color: leida ? null : Colors.lightGreen.shade50,
        elevation: leida ? 1 : 3,
        child: InkWell(
          onTap: () async {
            if (!leida) {
              await _notifService.marcarComoLeida(doc.id);
            }
            // TO DO: Navegar al perfil o al home del docente
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
            ),
            title: Text(
              '¡Cuenta Aprobada! 🎉',
              style: TextStyle(
                fontSize: 16,
                fontWeight: leida ? FontWeight.w500 : FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Tu solicitud ha sido aprobada. ¡Ya eres Docente en la plataforma!',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            trailing: Text(fechaFormat, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ),
      ),
    );
  }

  // 2. SOLICITUD RECHAZADA (Dirigido al Docente/Tutor)
  else if (tipo == 'solicitud_rechazada') {
    final motivo = data['motivo'] as String? ?? 'Rechazo sin motivo especificado.';
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _notifService.eliminarNotificacion(doc.id),
      child: Card(
        color: leida ? null : Colors.red.shade50,
        elevation: leida ? 1 : 3,
        child: InkWell(
          onTap: () async {
            if (!leida) {
              await _notifService.marcarComoLeida(doc.id);
            }
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            ),
            title: Text(
              '❌ Solicitud Rechazada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: leida ? FontWeight.w500 : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Motivo: $motivo',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            trailing: Text(fechaFormat, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ),
      ),
    );
  }

  // 3. SOLICITUD DOCENTE (Dirigido a Administradores)
  else if (tipo == 'solicitud_docente') {
    final nombreDocente = data['nombreDocente'] as String? ?? 'Docente';
    final institucion = data['institucion'] as String? ?? 'una institución';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _notifService.eliminarNotificacion(doc.id),
      child: Card(
        color: leida ? null : Colors.orange.shade50,
        elevation: leida ? 1 : 3,
        child: InkWell(
          onTap: () async {
            if (!leida) {
              await _notifService.marcarComoLeida(doc.id);
            }
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add, color: Colors.orange, size: 24),
            ),
            title: Text(
              nombreDocente,
              style: TextStyle(
                fontSize: 16,
                fontWeight: leida ? FontWeight.w500 : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Solicita ser docente en $institucion',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fechaFormat, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                if (!leida)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 4. SESIÓN COMPLETADA (Caso Estudiante/Docente Vinculado)
  // Esto se ejecuta si el 'tipo' es 'sesion_completada' o si es un 'tipo' desconocido.
  { 
    final estudianteNombre = data['estudianteNombre'] as String? ?? 'Estudiante';
    final tema = data['tema'] as String? ?? 'Tema';
    final aciertos = data['aciertos'] as int? ?? 0;
    final errores = data['errores'] as int? ?? 0;
    final total = data['total'] as int? ?? 0;
    final porcentaje = data['porcentaje'] as int? ?? 0;
    final duracion = data['duracion'] as int? ?? 0;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _notifService.eliminarNotificacion(doc.id),
      child: Card(
        color: leida ? null : Colors.blue.shade50,
        elevation: leida ? 1 : 3,
        child: InkWell(
          onTap: () async {
            if (!leida) {
              await _notifService.marcarComoLeida(doc.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _colorTema(tema).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconTema(tema), color: _colorTema(tema)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estudianteNombre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: leida ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Completó sesión de $tema',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fechaFormat,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(Icons.check_circle, '$aciertos/$total', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.cancel, '$errores', Colors.red),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.percent, '$porcentaje%', _colorPorcentaje(porcentaje)),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.timer, _formatDuracion(duracion), Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Actividad de tus estudiantes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _notifService.marcarTodasComoLeidas(),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Marcar todas'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notifService.obtenerNotificaciones(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin notificaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aquí verás cuando tus estudiantes\ncompleten sesiones de práctica',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return _buildNotificacionCard(docs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}