// lib/screen/screen_estudiante/tema_detalle_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TemaDetalleScreen extends StatelessWidget {
  const TemaDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final docId = (args['docId'] ?? '').toString();
    final fallbackNombre = (args['fallbackNombre'] ?? '').toString();

    if (docId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tema')),
        body: const Center(child: Text('Tema no especificado')),
      );
    }

    final ref = FirebaseFirestore.instance.collection('temas').doc(docId);

    return Scaffold(
      appBar: AppBar(title: Text(fallbackNombre.isEmpty ? 'Tema' : fallbackNombre)),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('No se encontró el tema'));
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
          final nombre   = (data['nombre'] ?? fallbackNombre).toString();
          final concepto = (data['concepto'] ?? '').toString();        // texto corto
          final contenido= (data['contenido'] ?? '').toString();       // texto largo opcional
          final ejemplos = (data['ejemplos'] as List?)?.cast<String>() ?? const <String>[];

          IconData icon;
          Color color;
          switch (nombre) {
            case 'suma':            icon = Icons.add;     color = Colors.green.shade400; break;
            case 'resta':           icon = Icons.remove;  color = Colors.red.shade400;   break;
            case 'multiplicacion':  icon = Icons.clear;   color = Colors.blue.shade400;  break;
            case 'conteo':          icon = Icons.numbers; color = Colors.orange.shade400;break;
            default:                icon = Icons.menu_book; color = Colors.grey.shade600;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombre.isEmpty ? 'Tema' : nombre,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (concepto.isNotEmpty) ...[
                const Text('Concepto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(concepto, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
              ],
              if (contenido.isNotEmpty) ...[
                const Text('Contenido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(contenido, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
              ],
              if (ejemplos.isNotEmpty) ...[
                const Text('Ejemplos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...ejemplos.map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.lightbulb_outline),
                    title: Text(e),
                  ),
                )),
                const SizedBox(height: 12),
              ],
              const Divider(height: 32),
              FilledButton.icon(
                onPressed: () {
                  // si ya tienes la ruta /repaso, la reutilizamos
                  Navigator.pushNamed(context, '/repaso', arguments: {'tema': nombre});
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Practicar este tema'),
              ),
            ],
          );
        },
      ),
    );
  }
}
