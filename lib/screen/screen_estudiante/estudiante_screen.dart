import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tabs/temas_tab.dart';
import 'tabs/inicio_tab.dart';
import 'tabs/progreso_tab.dart';
import 'tabs/perfil_tab.dart';

class EstudianteScreen extends StatefulWidget {
  final String? nombre;
  const EstudianteScreen({super.key, this.nombre});

  @override
  State<EstudianteScreen> createState() => _EstudianteScreenState();
}

class _EstudianteScreenState extends State<EstudianteScreen> {
  int _index = 0;

  // Paleta local para fondo y cards.
  static const _bg = Color(0xFFF7F8FA);
  static const _card = Colors.white;
  static const _selected = Color(0xFF083B8A);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final nombreUsuario = widget.nombre ?? (currentUser?.displayName ?? 'Estudiante');

    // Lista de las vistas (tabs) a mostrar.
    final tabs = [
      const TemasTab(),
      const InicioTab(),
      const ProgresoTab(),
      PerfilTab(nombre: nombreUsuario),
    ];

    // ignore: unused_local_variable
    final cs = Theme.of(context).colorScheme;

    // Tema local para barra inferior y cards.
    final localTheme = Theme.of(context).copyWith(
      navigationBarTheme: const NavigationBarThemeData(
        height: 78,
        backgroundColor: _card,
        indicatorColor: Color(0xFFE7F0FF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: const IconThemeData(size: 28),
      cardTheme: CardThemeData(
        color: _card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        backgroundColor: _bg,
        // AppBar personalizado con gradiente y saludo.
        appBar: _HeaderAppBarEstudiante(nombre: nombreUsuario),
        body: SafeArea(
          // Animación de transición entre tabs.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            // Widget Semantics para accesibilidad (lectores de pantalla).
            child: Semantics(
              container: true,
              label: _semanticForIndex(_index),
              child: tabs[_index],
            ),
          ),
        ),
        // Barra de navegación inferior.
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            // Actualiza el índice seleccionado y usa feedback háptico.
            setState(() => _index = i);
            HapticFeedback.selectionClick();
          },
          destinations: [
            // Definición de los botones de la barra de navegación.
            _navItem(
              icon: Icons.menu_book_rounded,
              label: 'Temas',
              semantics: 'Abrir Temas: teoría y contenido',
            ),
            _navItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              semantics: 'Abrir Inicio: botones de práctica',
            ),
            _navItem(
              icon: Icons.insights_rounded,
              label: 'Progreso',
              semantics: 'Abrir Progreso: ver resultados',
            ),
            _navItem(
              icon: Icons.person_rounded,
              label: 'Perfil',
              semantics: 'Abrir Perfil del estudiante',
            ),
          ],
        ),
      ),
    );
  }

  // Crea un NavigationDestination con accesibilidad mejorada.
  NavigationDestination _navItem({
    required IconData icon,
    required String label,
    required String semantics,
  }) {
    return NavigationDestination(
      icon: Semantics(
        button: true,
        label: label,
        hint: semantics,
        child: Icon(icon, color: Colors.black54),
      ),
      selectedIcon: Semantics(
        button: true,
        label: '$label (seleccionado)',
        child: Icon(icon, color: _selected),
      ),
      label: label,
      tooltip: label,
    );
  }

  // Devuelve la etiqueta semántica para el tab actual.
  String _semanticForIndex(int i) {
    switch (i) {
      case 0:
        return 'Sección Temas';
      case 1:
        return 'Sección Inicio';
      case 2:
        return 'Sección Progreso';
      case 3:
        return 'Sección Perfil';
      default:
        return 'Sección';
    }
  }
}

// Widget AppBar personalizado con altura definida y diseño con gradiente.
class _HeaderAppBarEstudiante extends StatelessWidget
    implements PreferredSizeWidget {
  final String nombre;
  const _HeaderAppBarEstudiante({required this.nombre});

  // Define la altura fija del AppBar.
  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      // Estilo del sistema para la barra de estado (transparente con iconos claros).
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      toolbarHeight: 96,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // Contenedor con gradiente para el fondo del AppBar.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer,
              cs.primary.withOpacity(0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // Avatar de perfil (icono de escuela).
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.onPrimary.withOpacity(0.15),
              child: Icon(Icons.school, color: cs.onPrimary),
            ),
            const SizedBox(width: 12),
            // Columna con saludo y nombre del usuario.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Bienvenido de Nuevo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hola, $nombre',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onPrimary.withOpacity(0.95),
                        ),
                  ),
                ],
              ),
            ),
            // Botón de ayuda que muestra un diálogo con consejos.
            IconButton(
              tooltip: 'Ayuda',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Consejos rápidos'),
                    content: const Text(
                      '• “Temas”: revisa teoría y ejemplos.\n'
                      '• “Inicio”: práctica rápida por categorías.\n'
                      '• “Progreso”: mira tus resultados y avances.\n'
                      '• “Perfil”: edita tus datos y preferencias.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.help_outline, color: cs.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}