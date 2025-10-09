import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TemasTab extends StatefulWidget {
  const TemasTab({super.key});

  @override
  State<TemasTab> createState() => _TemasTabState();
}

class _TemasTabState extends State<TemasTab> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeSpeech();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.8); // Más lento para mejor comprensión
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize(
      onError: (error) => print('Error: $error'),
      onStatus: (status) => print('Status: $status'),
    );
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _searchText = result.recognizedWords.toLowerCase();
            });
          },
          localeId: 'es_ES',
        );
        
        // Feedback auditivo
        await _speak("Escuchando, dime qué tema buscas");
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      await _speak("Búsqueda detenida");
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda accesible
        _buildAccessibleSearchBar(),
        
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
              
              // Filtrar por búsqueda de voz
              final filteredDocs = docs.where((doc) {
                if (_searchText.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                return nombre.contains(_searchText);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchText.isEmpty 
                            ? 'No hay temas disponibles'
                            : 'No se encontró "$_searchText"',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final data = (filteredDocs[i].data() as Map<String, dynamic>?) ?? {};
                  final nombre = (data['nombre'] ?? '').toString();
                  final concepto = (data['concepto'] ?? '').toString();

                  return _buildTemaCard(
                    nombre: nombre,
                    concepto: concepto,
                    docId: filteredDocs[i].id,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibleSearchBar() {
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
      child: Row(
        children: [
          // Botón de voz grande y accesible
          Expanded(
            child: GestureDetector(
              onTap: _startListening,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _isListening 
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isListening ? 'Escuchando...' : 'Buscar por voz',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Botón para limpiar búsqueda
          if (_searchText.isNotEmpty) ...[
            const SizedBox(width: 12),
            Material(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() => _searchText = '');
                  _speak("Búsqueda limpiada");
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Icon(Icons.clear, size: 28),
                ),
              ),
            ),
          ],
        ],
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