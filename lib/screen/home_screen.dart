// Home que rutea por rol e incluye pantalla DocentePendiente.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screen_estudiante/estudiante_screen.dart';
import 'screen_docente_tutor/docente_tutor_screen.dart';

/// Pantalla para cuentas de docente aún no aprobadas
class DocentePendienteScreen extends StatelessWidget {
  const DocentePendienteScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en revisión')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_bottom, size: 64, color: Colors.amber),
              const SizedBox(height: 12),
              const Text('Tu solicitud para Docente está en revisión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Un administrador debe aprobarla. Te avisaremos cuando se actualice.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  // Vuelve a login
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            if (!snap.hasData || !snap.data!.exists) {
              return const Text('Usuario sin datos.');
            }
            final data = snap.data!.data() as Map<String, dynamic>;
            final rol = (data['rol'] ?? '').toString();
            final nombre = (data['nombre'] ?? '').toString();

            // Enrutamiento por rol
            if (rol == 'estudiante') return EstudianteScreen(nombre: nombre);
            if (rol == 'docente_solicitado') return const DocentePendienteScreen();

            // Docente/Tutor/Admin/Director usan el mismo panel con tabs condicionales
            if (rol == 'docente' || rol == 'tutor' || rol == 'admin' || rol == 'director') {
              return DocenteTutorScreen(nombre: nombre);
            }

            // Fallback
            return const Text('Rol no reconocido. Contacta al administrador.');
          },
        ),
      ),
    );
  }
}
