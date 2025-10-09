import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/q_learning_service.dart';
import '../../services/exercise_engine.dart';
import 'package:app_aprendizaje/services/notification_service.dart';

class RepasoScreen extends StatefulWidget {
  final String tema;
  const RepasoScreen({super.key, required this.tema});

  @override
  State<RepasoScreen> createState() => _RepasoScreenState();
}

class _RepasoScreenState extends State<RepasoScreen> with TickerProviderStateMixin {
  final ExerciseEngine _engine = ExerciseEngine();
  late final QLearningService _ql;
  final FlutterTts _flutterTts = FlutterTts();

  Exercise? _ex;
  String _s = 'muy_basico';
  String _a = 'mantener-mantener_obj';
  String _sPrime = 'muy_basico';
  int _objetivo = 2;
  int _objetivoPrime = 2;

  int _idx = 0;
  int _aciertos = 0;
  int _errores = 0;
  final int _max = 10;
  late DateTime _inicio;

  bool _bloqueado = false;
  int? _seleccion;
  bool _showOverlay = false;
  Color _overlayColor = Colors.transparent;
  bool _showCelebration = false;
  
  late AnimationController _progressController;
  late AnimationController _celebrationController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    _ql = QLearningService(engine: _engine);
    super.initState();
    _inicio = DateTime.now();
    _initializeTts();
    _initializeAnimations();
    _cargarPrimero();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _cargarPrimero() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    await _engine.loadUsedPairs(uid, widget.tema);
    await _ql.getEpsilon(uid, widget.tema);
    
    final guardado = await _ql.getNivelActual(uid, widget.tema);
    final objGuardado = await _ql.getObjetivo(uid, widget.tema);
    
    setState(() {
      _s = guardado ?? 'muy_basico';
      _objetivo = objGuardado ?? 2;
    });
    
    await _planificarYSometerSiguiente(uid);
  }

  Future<void> _planificarYSometerSiguiente(String uid) async {
    _a = await _ql.pickAction(uid, widget.tema, _s, _objetivo);
    final result = _ql.applyAction(_s, _objetivo, _a);
    _sPrime = result['nivel'];
    _objetivoPrime = result['objetivo'];
    await _cargarEjercicio(_sPrime, accion: _a);
  }

  Future<void> _cargarEjercicio(String nivel, {required String accion}) async {
    setState(() {
      _ex = _engine.generateNextByAction(
        widget.tema,
        nivel,
        accion: _a,
        objetivo: _objetivoPrime,
      );
      _bloqueado = false;
      _seleccion = null;
      _showOverlay = false;
      _overlayColor = Colors.transparent;
      _showCelebration = false;
    });
    _progressController.forward(from: 0);
  }

  Future<void> _contestar(int valor) async {
    if (_bloqueado || _ex == null) return;

    setState(() {
      _bloqueado = true;
      _seleccion = valor;
    });

    final correcto = (valor == _ex!.respuesta);
    final diff = (valor - _ex!.respuesta).abs();
    
    double reward;
    
    if (correcto) {
      double baseReward = 1.0;
      final tope = _engine.getTopeResultado(_sPrime);
      final bonusDificultad = (_objetivoPrime / tope) * 0.5;
      reward = baseReward + bonusDificultad;
        
      _aciertos++;
      setState(() {
        _overlayColor = Colors.green;
        _showOverlay = true;
        _showCelebration = true;
      });
      _celebrationController.forward(from: 0);
      await _speak("¡Muy bien! Correcto");
      
    } else {
      if (diff == 1) {
        reward = 0.3;
      } else if (diff == 2) {
        reward = 0.0;
      } else {
        reward = -0.3;
      }
      
      _errores++;
      setState(() {
        _overlayColor = Colors.red;
        _showOverlay = true;
      });
      _shakeController.forward(from: 0);
      await _speak("Ups, la respuesta correcta es ${_ex!.respuesta}");
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final esTerminal = (_idx + 1 >= _max);
    
    await _ql.updateQ(
      uid: uid,
      tema: widget.tema,
      nivel: _s,
      objetivo: _objetivo,
      a: _a,
      r: reward,
      nivelPrime: _sPrime,
      objetivoPrime: _objetivoPrime,
      terminal: esTerminal,
    );
    
    await _ql.decayEpsilon(uid, widget.tema);
    await _ql.setObjetivo(uid, widget.tema, _objetivoPrime);
    await _ql.setNivelActual(uid, widget.tema, _sPrime);
    await _guardarContadorAccion(uid);

    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;
    setState(() {
      _showOverlay = false;
      _showCelebration = false;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (esTerminal) {
      await _guardarSesionYMostrarResumen();
    } else {
      await _siguiente();
    }
  }

  Future<void> _guardarContadorAccion(String uid) async {

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      
      final data = doc.data();
      final progreso = data?['progreso'] as Map<String, dynamic>?;
      final temaProg = progreso?[widget.tema] as Map<String, dynamic>?;
      final ultimaAccion = temaProg?['ultimaAccion'] as String?;
      
      final vecesRepetida = (ultimaAccion == _a) 
          ? ((temaProg?['vecesRepetidaAccion'] as int? ?? 0) + 1)
          : 1;

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'progreso': {
          widget.tema: {
            'ultimaAccion': _a,
            'vecesRepetidaAccion': vecesRepetida,
            'actualizadoEn': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));
  }

  Future<void> _siguiente() async {
    setState(() {
      _idx++;
    });

    if (_idx >= _max) {
      await _guardarSesionYMostrarResumen();
      return;
    }

    _s = _sPrime;
    _objetivo = _objetivoPrime;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _planificarYSometerSiguiente(uid);
    
    if (_ex != null) {
      await _speak("Ejercicio ${_idx + 1}. ${_ex!.enunciado}");
    }
  }

  Future<void> _guardarSesionYMostrarResumen() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dur = DateTime.now().difference(_inicio).inSeconds;

    try {
      await _engine.saveUsedPairs(uid, widget.tema);
    } catch (__) {}

    try {
      await FirebaseFirestore.instance.collection('sesiones').add({
        'fecha': FieldValue.serverTimestamp(),
        'estudianteId': uid,
        'tema': widget.tema,
        'duracion': dur,
        'aciertos': _aciertos,
        'errores': _errores,
      });
    } catch (_) {}
    // ===== NUEVO: Enviar notificación a docentes/tutores =====
  try {
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final userName = userDoc.data()?['nombre'] ?? 'Estudiante';
    
    final notifService = NotificationService();
    await notifService.notificarSesionCompletada(
      estudianteId: uid,
      estudianteNombre: userName,
      tema: widget.tema,
      aciertos: _aciertos,
      errores: _errores,
      duracion: dur,
    );
  } catch (e) {
    print('⚠️ Error enviando notificación: $e');
  }

    if (!mounted) return;
    final min = dur ~/ 60;
    final seg = dur % 60;
    final porcentaje = ((_aciertos / _max) * 100).round();

    String mensaje = '';
    if (porcentaje >= 90) {
      mensaje = '¡Excelente trabajo! Obtuviste $_aciertos respuestas correctas';
    } else if (porcentaje >= 70) {
      mensaje = '¡Muy bien! Lograste $_aciertos respuestas correctas';
    } else {
      mensaje = 'Buen intento. Sigue practicando';
    }
    await _speak(mensaje);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildSummaryDialog(min, seg, porcentaje),
    );
  }

  Widget _buildSummaryDialog(int min, int seg, int porcentaje) {
    final temaConfig = _getTemaConfig(widget.tema);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, temaConfig.color.withOpacity(0.1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [temaConfig.color, temaConfig.color.withOpacity(0.7)],
                ),
              ),
              child: Icon(
                porcentaje >= 70 ? Icons.emoji_events : Icons.thumb_up,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              porcentaje >= 90
                  ? '¡EXCELENTE!'
                  : porcentaje >= 70
                      ? '¡MUY BIEN!'
                      : '¡BUEN INTENTO!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: temaConfig.color,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatRow(Icons.check_circle, 'Correctas', '$_aciertos/$_max', Colors.green),
            _buildStatRow(Icons.cancel, 'Incorrectas', '$_errores/$_max', Colors.red),
            _buildStatRow(Icons.timer, 'Tiempo', '${min > 0 ? '$min min ' : ''}$seg s', Colors.blue),
            _buildStatRow(Icons.percent, 'Porcentaje', '$porcentaje%', temaConfig.color),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [temaConfig.color, temaConfig.color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.popUntil(context, ModalRoute.withName('/home')),
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Text(
                      'VOLVER AL INICIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _progressController.dispose();
    _celebrationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ex == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 6)),
      );
    }

    final mostrado = (_idx + 1 <= _max) ? (_idx + 1) : _max;
    final progreso = mostrado / _max;
    final temaConfig = _getTemaConfig(widget.tema);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  temaConfig.color.withOpacity(0.1),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(mostrado, progreso, temaConfig),

                Expanded(
                  child: IgnorePointer(
                    ignoring: _bloqueado,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: _buildQuestionCard(temaConfig),
                          ),

                          const SizedBox(height: 24),

                          ..._ex!.opciones.map((o) => _buildOptionCard(o, temaConfig)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedOpacity(
            opacity: _showOverlay ? 0.4 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: true,
              child: Container(color: _overlayColor),
            ),
          ),

          if (_showCelebration) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader(int mostrado, double progreso, _TemaConfig config) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.tema.toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: config.color,
                      ),
                    ),
                    Text(
                      'Ejercicio $mostrado/$_max',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, size: 28),
                color: config.color,
                onPressed: () => _speak(_ex!.enunciado),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 12,
                width: MediaQuery.of(context).size.width * progreso,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [config.color, config.color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreBadge(Icons.check_circle, _aciertos, Colors.green),
              _buildScoreBadge(Icons.cancel, _errores, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_TemaConfig config) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: config.color, width: 3),
        boxShadow: [
          BoxShadow(
            color: config.color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(config.icon, size: 48, color: config.color),
          const SizedBox(height: 16),
          Text(
            _ex!.enunciado,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int opcion, _TemaConfig config) {
    final isSelected = (_seleccion == opcion);
    final isCorrect = (opcion == _ex!.respuesta);
    
    Color borderColor = config.color.withOpacity(0.3);
    Color? bgColor;
    IconData? icon;
    
    if (_seleccion != null) {
      if (isSelected && isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
        icon = Icons.check_circle;
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
        icon = Icons.cancel;
      } else if (isCorrect) {
        borderColor = Colors.green;
        icon = Icons.check;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected ? borderColor.withOpacity(0.3) : Colors.black12,
              blurRadius: isSelected ? 15 : 5,
            ),
          ],
        ),
        child: Material(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _contestar(opcion),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: config.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        opcion.toString(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: config.color,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (icon != null)
                    Icon(icon, size: 36, color: borderColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0, end: 1.5).animate(
              CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
            ),
            child: const Text(
              '🎉',
              style: TextStyle(fontSize: 120),
            ),
          ),
        ),
      ),
    );
  }

  _TemaConfig _getTemaConfig(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'suma':
        return _TemaConfig(icon: Icons.add_circle, color: Colors.green.shade600);
      case 'resta':
        return _TemaConfig(icon: Icons.remove_circle, color: Colors.red.shade600);
      case 'multiplicacion':
        return _TemaConfig(icon: Icons.close, color: Colors.blue.shade600);
      case 'division':
        return _TemaConfig(icon: Icons.percent, color: Colors.purple.shade600);
      case 'conteo':
        return _TemaConfig(icon: Icons.format_list_numbered, color: Colors.orange.shade600);
      default:
        return _TemaConfig(icon: Icons.menu_book, color: Colors.teal.shade600);
    }
  }
}

class _TemaConfig {
  final IconData icon;
  final Color color;
  _TemaConfig({required this.icon, required this.color});
}