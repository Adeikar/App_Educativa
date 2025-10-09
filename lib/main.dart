// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screen/login_screen.dart';
import 'screen/registro_screen.dart';
import 'screen/home_screen.dart';
import 'screen/screen_estudiante/estudiante_screen.dart';
import 'screen/screen_docente_tutor/docente_tutor_screen.dart';
import 'screen/screen_docente_tutor/temas_crud_screen.dart';
import 'screen/screen_estudiante/tema_detalle_screen.dart';
import 'screen/screen_estudiante/repaso_screen.dart';
import 'package:app_aprendizaje/services/fcm_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    await FCMService().initialize();
  } else {
    try {
      await FCMService().initializeWebSafe();
    } catch (_) {}
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Educativa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // Verificar sesión al iniciar
      routes: {
        '/login'        : (_) => const LoginScreen(),
        '/registro'     : (_) => const RegistroScreen(),
        '/home'         : (_) => const HomeScreen(),
        '/estudiante'   : (_) => const EstudianteScreen(),
        '/docente_tutor': (_) => const DocenteTutorScreen(),
        '/temas_crud'   : (_) => const TemasCrudScreen(),
        '/tema_detalle' : (_) => const TemaDetalleScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/repaso' && settings.arguments is Map) {
          final args = settings.arguments as Map;
          final tema = (args['tema'] ?? '').toString();
          return MaterialPageRoute(
            builder: (_) => RepasoScreen(tema: tema),
          );
        }
        return null;
      },
    );
  }
}

// Widget que verifica si hay sesión activa
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostrar splash mientras verifica sesión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, size: 80, color: Colors.white),
                    SizedBox(height: 20),
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Cargando...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Si hay usuario logueado, ir a Home
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Si no hay sesión, mostrar Login
        return const LoginScreen();
      },
    );
  }
}