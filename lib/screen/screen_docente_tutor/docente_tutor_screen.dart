import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tabs/docente_inicio_tab.dart';
import 'tabs/docente_reportes_tab.dart';
import 'tabs/docente_notificaciones_tab.dart';
import 'tabs/docente_perfil_tab.dart';

class DocenteTutorScreen extends StatefulWidget {
  final String? nombre;
  const DocenteTutorScreen({super.key, this.nombre});

  @override
  State<DocenteTutorScreen> createState() => _DocenteTutorScreenState();
}

class _DocenteTutorScreenState extends State<DocenteTutorScreen>
    with TickerProviderStateMixin {
  int _index = 0;

  // Para abrir Reportes desde Inicio con un alumno específico
  String? _selectedStudentId;
  String? _selectedStudentName;

  // Animación suave al cambiar de tab
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

  void _openReportFor(String estudianteId, String estudianteNombre) {
    setState(() {
      _selectedStudentId = estudianteId;
      _selectedStudentName = estudianteNombre;
      _index = 1; // pestaña "Reportes"
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final display = widget.nombre ?? user?.displayName ?? 'Docente';

    final tabs = [
      DocenteInicioTab(onOpenReport: _openReportFor),
      DocenteReportesTab(
        initialStudentId: _selectedStudentId,
        initialStudentName: _selectedStudentName,
        onClearSelection: () => setState(() {
          _selectedStudentId = null;
          _selectedStudentName = null;
        }),
      ),
      const DocenteNotificacionesTab(),
      const DocentePerfilTab(),
    ];

    _fadeCtrl
      ..reset()
      ..forward();

    return Scaffold(
      backgroundColor:
          ColorScheme.fromSeed(seedColor: Colors.blue).surfaceContainerLowest,
      appBar: _HeaderAppBar(nombre: display),
      body: SafeArea(
        child: Semantics(
          label: 'Contenido de la pestaña ${_labelForIndex(_index)}',
          child: FadeTransition(
            opacity: _fade,
            child: IndexedStack(index: _index, children: tabs),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Avisos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),

      
    );
  }


  String _labelForIndex(int i) => switch (i) {
        0 => 'Inicio',
        1 => 'Reportes',
        2 => 'Avisos',
        _ => 'Perfil',
      };
}

/// AppBar con saludo y ayuda (sin botón extra de “Gestionar temas” para evitar duplicar acciones).
class _HeaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String nombre;
  const _HeaderAppBar({required this.nombre});

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 96,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.primary.withOpacity(0.90)],
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
              backgroundColor: cs.onPrimary.withOpacity(0.15),
              child: Icon(Icons.school, color: cs.onPrimary),
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
                      'Panel del Docente',
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
            IconButton(
              tooltip: 'Ayuda',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Consejos rápidos'),
                    content: const Text(
                      '• “Inicio”: vincula y gestiona alumnos.\n'
                      '• “Reportes”: busca un estudiante, vista previa y PDF.\n'
                      '• “Avisos”: envía y revisa mensajes.\n'
                      '• “Perfil”: datos del docente y foto.\n'
                      '• Usa el botón “Acciones” para Vincular o Gestionar temas.',
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
