// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screen/login_screen.dart';
import 'screen/registro_screen.dart';
import 'screen/home_screen.dart';
import 'screen/screen_estudiante/estudiante_screen.dart';
import 'screen/screen_docente_tutor/docente_tutor_screen.dart';
import 'screen/screen_docente_tutor/temas_crud_screen.dart';
import 'screen/screen_estudiante/tema_detalle_screen.dart';
import 'screen/screen_estudiante/repaso_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      initialRoute: '/login',
      routes: {
        '/login'        : (_) => const LoginScreen(),
        '/registro'     : (_) => const RegistroScreen(),
        '/home'         : (_) => const HomeScreen(),
        '/estudiante'   : (_) => const EstudianteScreen(),
        '/docente_tutor': (_) => const DocenteTutorScreen(),
        '/temas_crud'   : (_) => const TemasCrudScreen(),
        '/tema_detalle' : (_) => const TemaDetalleScreen(),
      },
      // Para evitar errores si alguien navega accidentalmente a '/repaso'
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
