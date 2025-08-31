import 'package:flutter/material.dart';

class EstudianteScreen extends StatelessWidget {
  final String? nombre;
  const EstudianteScreen({super.key, this.nombre});

  @override
  Widget build(BuildContext context) {
    final nombreUsuario = nombre ?? 'Estudiante';
    return Scaffold(
      appBar: AppBar(title: Text('Hola, $nombreUsuario')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Temas (próximo paso: Repaso + Q-Learning)'),
        ],
      ),
    );
  }
}
