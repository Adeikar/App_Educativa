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

  // Colores de alto contraste y consistentes
  static const _bg = Color(0xFFF7F8FA);
  static const _primary = Color(0xFF0B57D0); // azul fuerte
  static const _onPrimary = Colors.white;
  static const _selected = Color(0xFF083B8A);
  static const _card = Colors.white;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final nombreUsuario = widget.nombre ?? (currentUser?.displayName ?? 'Estudiante');

    final tabs = [
      const TemasTab(),
      const InicioTab(),
      const ProgresoTab(),
      PerfilTab(nombre: nombreUsuario),
    ];

    // Tema local de alto contraste para esta pantalla
    final localTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _primary,
            onPrimary: _onPrimary,
            surface: _card,
            onSurface: Colors.black87,
          ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 78, // toque cómodo
        backgroundColor: _card,
        indicatorColor: Color(0xFFE7F0FF), // resaltado suave pero visible
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: const IconThemeData(size: 28), // iconos grandes
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
        appBar: AppBar(
          backgroundColor: _card,
          surfaceTintColor: _card,
          elevation: 0.5,
          titleSpacing: 16,
          title: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, $nombreUsuario',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                  'Elige una pestaña para continuar',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150), // animación breve (evitar sobrecarga)
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Semantics(
              container: true,
              label: _semanticForIndex(_index),
              child: tabs[_index],
            ),
          ),
        ),

        // NavigationBar (Material 3) con etiquetas SIEMPRE visibles
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            // feedback sutil (opcional)
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

  // Helper: destino accesible con semántica
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
      tooltip: label, // aparece al mantener pulsado/hover (web)
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
