import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../repaso_screen.dart';

class InicioTab extends StatefulWidget {
  const InicioTab({super.key});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTts();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _speak("Bienvenido. Elige un tema para practicar");
    });
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void _goTema(BuildContext context, String tema, String descripcion) async {
    await _speak("Iniciando práctica de $tema");
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RepasoScreen(tema: tema)),
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 6),

            _TemaButton(
              color: Colors.green.shade600,
              icon: Icons.add_circle,
              text: 'SUMA',
              descripcion: 'Juntar números',
              emoji: '➕',
              onTap: () => _goTema(context, 'suma', 'suma'),
              onLongPress: () => _speak('Suma: aprender a juntar números'),
            ),
            
            const SizedBox(height: 12),
            
            _TemaButton(
              color: Colors.red.shade600,
              icon: Icons.remove_circle,
              text: 'RESTA',
              descripcion: 'Quitar números',
              emoji: '➖',
              onTap: () => _goTema(context, 'resta', 'resta'),
              onLongPress: () => _speak('Resta: aprender a quitar números'),
            ),
            
            const SizedBox(height: 12),
            
            _TemaButton(
              color: Colors.blue.shade600,
              icon: Icons.close,
              text: 'MULTIPLICACIÓN',
              descripcion: 'Repetir números',
              emoji: '✖️',
              onTap: () => _goTema(context, 'multiplicacion', 'multiplicación'),
              onLongPress: () => _speak('Multiplicación: aprender a multiplicar números'),
            ),
            
            const SizedBox(height: 12),
            
            _TemaButton(
              color: Colors.orange.shade600,
              icon: Icons.format_list_numbered,
              text: 'CONTEO',
              descripcion: 'Contar objetos',
              emoji: '🔢',
              onTap: () => _goTema(context, 'conteo', 'conteo'),
              onLongPress: () => _speak('Conteo: aprender a contar objetos'),
            ),
            
            const SizedBox(height: 24),
            
            _buildInstructions(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 10),
              Text(
                'Ayuda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionRow(
            Icons.touch_app,
            'Toca un tema para comenzar',
          ),
          const SizedBox(height: 8),
          _buildInstructionRow(
            Icons.volume_up,
            'Mantén presionado para escuchar',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _TemaButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String text;
  final String descripcion;
  final String emoji;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TemaButton({
    required this.color,
    required this.icon,
    required this.text,
    required this.descripcion,
    required this.emoji,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_TemaButton> createState() => _TemaButtonState();
}

class _TemaButtonState extends State<_TemaButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: _isPressed ? 8 : 20,
              offset: Offset(0, _isPressed ? 2 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color, widget.color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    
                    const SizedBox(width: 14),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5, 
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, 
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.descripcion,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}