// lib/screen/screen_estudiante/tabs/temas_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TemasTab extends StatelessWidget {
  const TemasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('temas')               // <-- minúsculas
          .orderBy('nombre')                 // <-- existe y es string
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No hay temas disponibles'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final data = (docs[i].data() as Map<String, dynamic>? ) ?? {};
            final nombre   = (data['nombre'] ?? '').toString();
            final concepto = (data['concepto'] ?? '').toString();

            IconData icon;
            Color color;
            switch (nombre) {
              case 'suma':            icon = Icons.add;     color = Colors.green.shade400; break;
              case 'resta':           icon = Icons.remove;  color = Colors.red.shade400;   break;
              case 'multiplicacion':  icon = Icons.clear;   color = Colors.blue.shade400;  break;
              case 'conteo':          icon = Icons.numbers; color = Colors.orange.shade400;break;
              default:                icon = Icons.menu_book; color = Colors.grey.shade600;
            }

            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(concepto, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/tema_detalle',
                    arguments: {
                      'docId': docs[i].id,               // <-- id del documento
                      'fallbackNombre': nombre,          // por si quieres mostrar el título de inmediato
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
