// lib/screen/screen_estudiante/tema_detalle_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TemaDetalleScreen extends StatefulWidget {
  const TemaDetalleScreen({super.key});

  @override
  State<TemaDetalleScreen> createState() => _TemaDetalleScreenState();
}

class _TemaDetalleScreenState extends State<TemaDetalleScreen> with TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  String _currentSection = '';
  
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeAnimations();
    
    // Auto-leer el título al entrar
    Future.delayed(const Duration(milliseconds: 800), () {
      final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
      final nombre = (args['fallbackNombre'] ?? '').toString();
      if (nombre.isNotEmpty) {
        _speak("Tema: $nombre. Toca cualquier sección para escuchar");
      }
    });
  }

  void _initializeAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _speak(String text, {String section = ''}) async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = true;
      _currentSection = section;
    });
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _currentSection = '';
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final docId = (args['docId'] ?? '').toString();
    final fallbackNombre = (args['fallbackNombre'] ?? '').toString();

    if (docId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tema')),
        body: const Center(child: Text('Tema no especificado')),
      );
    }

    final ref = FirebaseFirestore.instance.collection('temas').doc(docId);

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 6));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}', style: const TextStyle(fontSize: 18)),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(
              child: Text('No se encontró el tema', style: TextStyle(fontSize: 18)),
            );
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
          final nombre = (data['nombre'] ?? fallbackNombre).toString();
          final concepto = (data['concepto'] ?? '').toString();
          final contenido = (data['contenido'] ?? '').toString();
          final ejemplos = (data['ejemplos'] as List?)?.cast<String>() ?? const <String>[];

          final config = _getTemaConfig(nombre);

          return CustomScrollView(
            slivers: [
              // App Bar animado con gradiente
              _buildAnimatedAppBar(nombre, config),
              
              // Contenido principal
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Mascota animada del tema
                    _buildAnimatedMascot(config),
                    
                    const SizedBox(height: 24),
                    
                    // Controles de audio
                    _buildAudioControls(),
                    
                    const SizedBox(height: 16),
                    
                    // Concepto
                    if (concepto.isNotEmpty)
                      _buildInteractiveCard(
                        title: '💡 ¿Qué es?',
                        content: concepto,
                        color: config.color,
                        icon: Icons.psychology,
                        section: 'concepto',
                      ),
                    
                    // Contenido
                    if (contenido.isNotEmpty)
                      _buildInteractiveCard(
                        title: '📚 Aprende más',
                        content: contenido,
                        color: config.color.withBlue(200),
                        icon: Icons.menu_book,
                        section: 'contenido',
                      ),
                    
                    // Ejemplos interactivos
                    if (ejemplos.isNotEmpty)
                      _buildExamplesSection(ejemplos, config),
                    
                    const SizedBox(height: 24),
                    
                    // Botón de práctica gigante
                    _buildPracticeButton(nombre, config),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedAppBar(String nombre, _TemaConfig config) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          nombre.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [config.color, config.color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(
                    config.icon,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMascot(_TemaConfig config) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [config.color, config.color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: config.color.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(config.icon, size: 70, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildAudioControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSpeaking ? Icons.volume_up : Icons.hearing,
            color: Colors.blue.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isSpeaking 
                  ? '🔊 Reproduciendo...' 
                  : '👆 Toca cualquier sección para escuchar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle, size: 32),
              color: Colors.red.shade600,
              onPressed: _stopSpeaking,
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard({
    required String title,
    required String content,
    required Color color,
    required IconData icon,
    required String section,
  }) {
    final isActive = _isSpeaking && _currentSection == section;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isActive ? color.withOpacity(0.4) : Colors.black12,
              blurRadius: isActive ? 20 : 8,
              spreadRadius: isActive ? 2 : 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => _speak(content, section: section),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive ? color : color.withOpacity(0.3),
                  width: isActive ? 3 : 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      Icon(
                        isActive ? Icons.pause_circle : Icons.play_circle,
                        color: color,
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamplesSection(List<String> ejemplos, _TemaConfig config) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: config.color, size: 28),
              const SizedBox(width: 8),
              Text(
                '✨ Ejemplos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: config.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...ejemplos.asMap().entries.map((entry) {
            final index = entry.key;
            final ejemplo = entry.value;
            final isActive = _isSpeaking && _currentSection == 'ejemplo_$index';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isActive ? config.color.withOpacity(0.3) : Colors.black12,
                      blurRadius: isActive ? 15 : 5,
                    ),
                  ],
                ),
                child: Material(
                  color: isActive ? config.color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  elevation: isActive ? 8 : 2,
                  child: InkWell(
                    onTap: () => _speak(ejemplo, section: 'ejemplo_$index'),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: config.color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              ejemplo,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Icon(
                            isActive ? Icons.volume_up : Icons.volume_off_outlined,
                            color: config.color,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPracticeButton(String nombre, _TemaConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [config.color, config.color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: config.color.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await _speak("¡Vamos a practicar $nombre!");
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) {
                  Navigator.pushNamed(
                    context,
                    '/repaso',
                    arguments: {'tema': nombre},
                  );
                }
              },
              borderRadius: BorderRadius.circular(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    '¡PRACTICAR AHORA!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
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