import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'tabs/docente_inicio_tab.dart';
import 'tabs/docente_reportes_tab.dart';
import 'tabs/docente_notificaciones_tab.dart';
import 'tabs/docente_perfil_tab.dart';
import 'tabs/docentes_solicitudes_tab.dart';

// ===== Contador de solicitudes pendientes (fuera de la clase) =====
Stream<int> _solicitudesPendientesCountStream() {
  return FirebaseFirestore.instance
      .collection('solicitudes_docente')
      .where('estado', isEqualTo: 'pendiente')
      .snapshots()
      .map((snap) => snap.size);
}

// ===== Contador de notificaciones no leídas (fuera de la clase) =====
Stream<int> _unreadCountStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream<int>.value(0);

  return FirebaseFirestore.instance
      .collection('notificaciones')
      .where('destinatarioId', isEqualTo: uid)
      .where('leida', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.size);
}

class DocenteTutorScreen extends StatefulWidget {
  final String? nombre;
  const DocenteTutorScreen({super.key, this.nombre});

  @override
  State<DocenteTutorScreen> createState() => _DocenteTutorScreenState();
}

class _DocenteTutorScreenState extends State<DocenteTutorScreen>
    with TickerProviderStateMixin {
  int _index = 0;
  String? _selectedStudentId;
  String? _selectedStudentName;

  // animación
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

  // flag admin/director
  bool _isAdmin = false;

  // suscripción a cambios del documento de usuario (para actualizar flag en vivo)
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _watchRole();
  }

  void _watchRole() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userStream = FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots();
    _sub = _userStream!.listen((doc) {
      final rol = (doc.data()?['rol'] ?? '').toString().trim().toLowerCase();
      final adminNow = (rol == 'admin' || rol == 'director');
      if (_isAdmin != adminNow && mounted) {
        setState(() => _isAdmin = adminNow);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _openReportFor(String estudianteId, String estudianteNombre) {
    setState(() {
      _selectedStudentId = estudianteId;
      _selectedStudentName = estudianteNombre;
      _index = 1; // pestaña "Reportes"
    });
  }

  // ===== Destination con Badge para "Avisos" =====
  NavigationDestination _avisosDestination() {
    Widget withBadge(Icon base) {
      return StreamBuilder<int>(
        stream: _unreadCountStream(),
        builder: (context, snap) {
          final c = snap.data ?? 0;
          return Badge(
            isLabelVisible: c > 0,
            label: Text(c > 99 ? '99+' : '$c'),
            child: base,
          );
        },
      );
    }

    return NavigationDestination(
      icon: withBadge(const Icon(Icons.notifications_outlined)),
      selectedIcon: withBadge(const Icon(Icons.notifications)),
      label: 'Avisos',
    );
  }

  // ===== Destination con Badge para "Solicitudes" (SOLO admin) =====
  NavigationDestination _solicitudesDestination() {
    Widget withBadge(Icon base) {
      return StreamBuilder<int>(
        stream: _solicitudesPendientesCountStream(),
        builder: (context, snap) {
          final c = snap.data ?? 0;
          return Badge(
            isLabelVisible: c > 0,
            label: Text(c > 99 ? '99+' : '$c'),
            backgroundColor: Colors.orange, // Color diferente para solicitudes
            child: base,
          );
        },
      );
    }

    return NavigationDestination(
      icon: withBadge(const Icon(Icons.assignment_turned_in_outlined)),
      selectedIcon: withBadge(const Icon(Icons.assignment_turned_in)),
      label: 'Solicitudes',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final display = widget.nombre ?? user?.displayName ?? 'Usuario';

    final tabs = <Widget>[
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
      if (_isAdmin) const DocentesSolicitudesTab(), // SOLO admin/director
      const DocentePerfilTab(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.assessment_outlined),
        selectedIcon: Icon(Icons.assessment),
        label: 'Reportes',
      ),
      _avisosDestination(), // Badge rojo para notificaciones
      if (_isAdmin) _solicitudesDestination(), // Badge naranja para solicitudes
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];

    if (_index >= tabs.length) _index = tabs.length - 1;

    _fadeCtrl..reset()..forward();

    return Scaffold(
      backgroundColor: ColorScheme.fromSeed(seedColor: Colors.blue).surfaceContainerLowest,
      appBar: _HeaderAppBar(nombre: display),
      body: SafeArea(
        child: Semantics(
          label: 'Contenido de la pestaña ${_labelForIndex(_index, isAdmin: _isAdmin)}',
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
        destinations: destinations,
      ),
    );
  }

  String _labelForIndex(int i, {required bool isAdmin}) {
    final labels = <String>['Inicio', 'Reportes', 'Avisos', if (isAdmin) 'Solicitudes', 'Perfil'];
    return (i >= 0 && i < labels.length) ? labels[i] : 'Sección';
  }
}

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
                      'Panel',
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
                      '• Inicio: vincula y gestiona alumnos.\n'
                      '• Reportes: busca un estudiante, vista previa y PDF.\n'
                      '• Avisos: avisos generales.\n'
                      '• Solicitudes (solo admin): aprobar/rechazar docentes.\n'
                      '• Perfil: datos y foto.',
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