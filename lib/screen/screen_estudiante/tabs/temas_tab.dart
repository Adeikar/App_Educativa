import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TemasTab extends StatefulWidget {
  const TemasTab({super.key});

  @override
  State<TemasTab> createState() => _TemasTabState();
}

class _TemasTabState extends State<TemasTab> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.6); // Más lento para mejor comprensión
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Solo header simple sin búsqueda por voz
        _buildHeader(),
        
        // Lista de temas
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('temas')
                .orderBy('nombre')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 6),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                  ),
                );
              }
              
              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay temas disponibles',
                        style: TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final data = (docs[i].data() as Map<String, dynamic>?) ?? {};
                  final nombre = (data['nombre'] ?? '').toString();
                  final concepto = (data['concepto'] ?? '').toString();

                  return _buildTemaCard(
                    nombre: nombre,
                    concepto: concepto,
                    docId: docs[i].id,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Selecciona un tema para practicar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildTemaCard({
    required String nombre,
    required String concepto,
    required String docId,
  }) {
    final temaConfig = _getTemaConfig(nombre);

    return Card(
      elevation: 4,
      shadowColor: temaConfig.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: temaConfig.color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          _speak("Abriendo tema de $nombre");
          Navigator.pushNamed(
            context,
            '/tema_detalle',
            arguments: {
              'docId': docId,
              'fallbackNombre': nombre,
            },
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Ícono grande y colorido
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      temaConfig.color,
                      temaConfig.color.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: temaConfig.color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  temaConfig.icon,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Contenido del tema
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: temaConfig.color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      concepto,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Botón de reproducir concepto
              Material(
                color: temaConfig.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    _speak("$nombre. $concepto");
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.volume_up,
                      color: temaConfig.color,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TemaConfig _getTemaConfig(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'suma':
        return _TemaConfig(
          icon: Icons.add_circle,
          color: Colors.green.shade600,
        );
      case 'resta':
        return _TemaConfig(
          icon: Icons.remove_circle,
          color: Colors.red.shade600,
        );
      case 'multiplicacion':
        return _TemaConfig(
          icon: Icons.close,
          color: Colors.blue.shade600,
        );
      case 'division':
        return _TemaConfig(
          icon: Icons.percent,
          color: Colors.purple.shade600,
        );
      case 'conteo':
        return _TemaConfig(
          icon: Icons.format_list_numbered,
          color: Colors.orange.shade600,
        );
      default:
        return _TemaConfig(
          icon: Icons.menu_book,
          color: Colors.teal.shade600,
        );
    }
  }
}

class _TemaConfig {
  final IconData icon;
  final Color color;

  _TemaConfig({required this.icon, required this.color});
}