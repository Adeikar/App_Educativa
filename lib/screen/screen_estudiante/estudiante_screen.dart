import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// tabs
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

  // Paleta consistente con el resto del proyecto
  static const _bg = Color(0xFFF7F8FA);
  static const _primary = Color(0xFF0B57D0); // azul fuerte
  static const _onPrimary = Colors.white;
  static const _selected = Color(0xFF083B8A);
  static const _card = Colors.white;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final nombreUsuario =
        widget.nombre ?? (currentUser?.displayName ?? 'Estudiante');

    final tabs = [
      const TemasTab(),
      const InicioTab(),
      const ProgresoTab(),
      PerfilTab(nombre: nombreUsuario),
    ];

    // Tema local para esta pantalla
    final localTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _primary,
            onPrimary: _onPrimary,
            surface: _card,
            onSurface: Colors.black87,
          ),
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
        appBar: _HeaderAppBarEstudiante(nombre: nombreUsuario),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Semantics(
              container: true,
              label: _semanticForIndex(_index),
              child: tabs[_index],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            HapticFeedback.selectionClick();
          },
          destinations: [
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

  // Item accesible de la barra inferior
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

/// AppBar con degradé y saludo (mismo estilo que Docente, adaptado a Estudiante).
class _HeaderAppBarEstudiante extends StatelessWidget
    implements PreferredSizeWidget {
  final String nombre;
  const _HeaderAppBarEstudiante({required this.nombre});

  static const _primary = Color(0xFF0B57D0);
  static const _onPrimary = Colors.white;

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      toolbarHeight: 96,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.90), // mantiene coherencia con el tema
              _primary,
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
            CircleAvatar(
              radius: 26,
              backgroundColor: _onPrimary.withOpacity(0.15),
              child: const Icon(Icons.school, color: _onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Panel del Estudiante',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hola, $nombre',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _onPrimary.withOpacity(0.95),
                        ),
                  ),
                ],
              ),
            ),
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
                      '• “Perfil”: edita tus datos y preferencia de estudio.',
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
              icon: const Icon(Icons.help_outline, color: _onPrimary),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );
  }
}
