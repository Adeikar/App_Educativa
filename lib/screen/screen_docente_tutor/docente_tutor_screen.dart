import 'package:flutter/material.dart';

class DocenteTutorScreen extends StatelessWidget {
  final String? nombre;
  const DocenteTutorScreen({super.key, this.nombre});

  @override
  Widget build(BuildContext context) {
    final n = nombre ?? 'Usuario';
    return Scaffold(
      appBar: AppBar(title: Text('Panel de $n')),
      body: const Center(child: Text('Gestión de estudiantes (placeholder)')),
    );
  }
}
