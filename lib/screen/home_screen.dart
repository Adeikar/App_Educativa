import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screen_estudiante/estudiante_screen.dart';
import 'screen_docente_tutor/docente_tutor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body: Center(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snap.hasError || !snap.hasData || !snap.data!.exists) {
              return const Text('Error o usuario sin datos');
            }
            final data = snap.data!.data() as Map<String, dynamic>;
            final rol = (data['rol'] ?? '') as String;
            final nombre = (data['nombre'] ?? '') as String;

            if (rol == 'estudiante') {
              return EstudianteScreen(nombre: nombre);
            } else {
              return DocenteTutorScreen(nombre: nombre);
            }
          },
        ),
      ),
    );
  }
}
