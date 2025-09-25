import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/q_learning_service.dart';
import '../../services/exercise_engine.dart';

class RepasoScreen extends StatefulWidget {
  final String tema;
  const RepasoScreen({super.key, required this.tema});

  @override
  State<RepasoScreen> createState() => _RepasoScreenState();
}

class _RepasoScreenState extends State<RepasoScreen> {
  final _ql = QLearningService();
  final _engine = ExerciseEngine();

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

  
  bool _bloqueado = false;         // Bloquea toda interacción durante feedback
  int? _seleccion;                // Opción elegida
  bool _showOverlay = false;       // Muestra “pantallazo” semitransparente
  Color _overlayColor = Colors.transparent;

  static const double _rCorrecto = 1.0;
  static const double _rIncorrecto = -0.5;

  // inicializa la pantalla y carga los datos guardados del usuario.
  @override
  void initState() {
    super.initState();
    _inicio = DateTime.now();
    _cargarPrimero();
  }

  Future<void> _cargarPrimero() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final guardado = await _ql.getNivelActual(uid, widget.tema);
    final objGuardado = await _ql.getObjetivo(uid, widget.tema);
    _engine.resetPrevExercises(widget.tema); // Reiniciar historial al iniciar
    setState(() {
      _s = guardado ?? 'muy_basico';
      _objetivo = objGuardado ?? 2;
    });
    await _planificarYSometerSiguiente(uid);
  }

  // usamos el motor de Q-Learning para planificar la siguiente acción y cargar el ejercicio.
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
    });
  }

  // Este bloque maneja la lógica cuando el usuario responde a una pregunta incluyendo el feedback el cálculo de la recompensa y la actualización del modelo de Q-Learning.
  Future<void> _contestar(int valor) async {
    if (_bloqueado || _ex == null) return;

    // Bloquea inmediatamente e ilumina 
    setState(() {
      _bloqueado = true;
      _seleccion = valor;
    });

    final correcto = (valor == _ex!.respuesta);
    final diff = (valor - _ex!.respuesta).abs();
    final reward = correcto ? _rCorrecto : (diff <= 2 ? 0.5 : _rIncorrecto);

    if (correcto) _aciertos++; else _errores++;

    // Feedback visual inmediato
    setState(() {
      _overlayColor = correcto ? Colors.green : Colors.red;
      _showOverlay = true;
    });

    //Actualiza Q-Learning en paralelo 
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
    _ql.decayEpsilon();
    await _ql.setObjetivo(uid, widget.tema, _objetivoPrime);
    await _ql.setNivelActual(uid, widget.tema, _sPrime);


    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _showOverlay = false; // se desvanece con AnimatedOpacity
    });

    await Future.delayed(const Duration(milliseconds: 150)); // pequeño fade-out

    if (esTerminal) {
      await _guardarSesionYMostrarResumen();
    } else {
      await _siguiente();
    }
  }

  //avance al siguiente ejercicio o la finalización de la sesión.
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
  }

  // lógica para aplicar reglas de promoción o descenso basadas en el rendimiento general del usuario.
  String _nextLevel(String nivel) {
    const order = ['muy_basico', 'basico', 'medio', 'alto'];
    final i = order.indexOf(nivel);
    return i < order.length - 1 ? order[i + 1] : nivel;
  }

  String _prevLevel(String nivel) {
    const order = ['muy_basico', 'basico', 'medio', 'alto'];
    final i = order.indexOf(nivel);
    return i > 0 ? order[i - 1] : nivel;
  }

  Future<void> _aplicarReglasNivelPorSesion(String uid, int durSegundos) async {
    final intentos = (_idx + 1).clamp(1, _max); // cuántos se resolvieron
    final acc = _aciertos / intentos;
    final avgSeg = durSegundos / intentos;

    // Nivel base = donde terminaste la sesión según RL
    String nivelOficial = _sPrime;

    // Sube si domina: >=85% y <=8s por ítem
    if (acc >= 0.85 && avgSeg <= 8 && nivelOficial != 'alto') {
      nivelOficial = _nextLevel(nivelOficial);
    }
    // Baja si le cuesta: <=60% y >=12s por ítem
    else if (acc <= 0.60 && avgSeg >= 12 && nivelOficial != 'muy_basico') {
      nivelOficial = _prevLevel(nivelOficial);
    }
    // Sino, se mantiene.

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'progreso': {
        widget.tema: {
          'nivelActual': nivelOficial,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));
  }


  //guarda los datos de la sesión y muestra un resumen al usuario.
  Future<void> _guardarSesionYMostrarResumen() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dur = DateTime.now().difference(_inicio).inSeconds;

    // 1) Aplica PROMOCIÓN/DESCENSO OFICIAL al cerrar sesión
    try {
      await _aplicarReglasNivelPorSesion(uid, dur);
    } catch (_) {
      // no hacer nada si falla
    }

    // Garda resumen de la sesión
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

    if (!mounted) return;
    final min = dur ~/ 60;
    final seg = dur % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('¡Sesión completada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema: ${widget.tema}'),
            Text('Tiempo: ${min > 0 ? '$min min ' : ''}$seg s'),
            Text('Aciertos: $_aciertos'),
            Text('Errores: $_errores'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/home')),
            child: const Text('Volver al inicio'),
          ),
        ],
      ),
    );
  }

  // Este bloque contiene la estructura visual de la pantalla
  @override
  Widget build(BuildContext context) {
    if (_ex == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mostrado = (_idx + 1 <= _max) ? (_idx + 1) : _max;

    return Scaffold(
      appBar: AppBar(title: Text('Repaso - ${widget.tema}')),
      body: Stack(
        children: [
          // Capa principal
          IgnorePointer(
            ignoring: _bloqueado, // bloquea taps durante feedback
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ejercicio $mostrado/$_max',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _ex!.enunciado,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._ex!.opciones.map((o) {
                    final isSelected = (_seleccion == o);
                    final isCorrect = (o == _ex!.respuesta);
                    IconData? trailing;
                    Color? tileColor;

                    if (_seleccion != null) {
                      if (isSelected && isCorrect) {
                        trailing = Icons.check_circle;
                        tileColor = Colors.green.withOpacity(0.08);
                      } else if (isSelected && !isCorrect) {
                        trailing = Icons.cancel;
                        tileColor = Colors.red.withOpacity(0.08);
                      } else if (isCorrect) {
                        trailing = Icons.check;
                      }
                    }

                    return Card(
                      child: ListTile(
                        tileColor: tileColor,
                        title: Text(o.toString(), style: const TextStyle(fontSize: 18)),
                        trailing: trailing != null ? Icon(trailing) : null,
                        onTap: () => _contestar(o),
                      ),
                    );
                  }),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Overlay de feedback
          AnimatedOpacity(
            opacity: _showOverlay ? 0.35 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: true,
              child: Container(color: _overlayColor),
            ),
          ),
        ],
      ),
    );
  }
}