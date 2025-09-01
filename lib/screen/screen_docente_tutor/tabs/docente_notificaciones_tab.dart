import 'package:flutter/material.dart';

class DocenteNotificacionesTab extends StatelessWidget {
  const DocenteNotificacionesTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder amigable. Luego puedes conectar FCM y traer avisos reales.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('Sin notificaciones'),
            subtitle: const Text('Aquí verás avisos relevantes para tus estudiantes.'),
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ),
        ),
      ],
    );
  }
}
