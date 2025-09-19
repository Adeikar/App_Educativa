// lib/screen/screen_estudiante/repaso_screen.dart
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

  // Ejercicio actual
  Exercise? _ex;

  // Estado RL (MDP)
  String _s = 'muy_basico';            
  String _a = 'mantener';              
  String _sPrime = 'muy_basico';       
  DateTime? _qStart;                   

  // Sesión
  int _idx = 0;                       
  int _aciertos = 0;
  int _errores = 0;
  final int _max = 10;
  late DateTime _inicio;

  // UI
  bool _bloqueado = false;             
  int? _seleccion;                     

  // ---------- Parámetros de recompensa ----------
  static const int _bonusRapidoSeg = 5;     // <5 s → bonus
  static const int _lentoSeg = 15;          // >15 s → pequeña penalización
  static const double _rCorrecto = 1.0;     // base por acierto
  static const double _rBonusRapido = 0.2;  // bonus por rapidez
  static const double _rIncorrectoCerca = -0.2; // castigo suave si estuvo cerca (±2)
  static const double _rIncorrectoLejano = -0.4; // castigo si estuvo lejos
  static const double _rPenalLento = -0.1;  // penalización suave por tardanza
  static const int _umbralCercania = 2;     // “cerca” = diferencia ≤ 2
  static const double _rMax = 1.3, _rMin = -0.5; // clamp para estabilidad

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
    // Puedes inicializar _s con un nivel guardado del usuario si quieres.
    _s = 'muy_basico';
    await _planificarYSometerSiguiente(uid);
  }

  /// Planifica el próximo paso con el AGENTE (ε-greedy) y genera el ejercicio en s'
  Future<void> _planificarYSometerSiguiente(String uid) async {
    // 1) El agente elige acción en el estado actual (nivel actual)
    _a = await _ql.pickAction(uid, widget.tema, _s);

    // 2) Aplicas la acción → nuevo nivel (estado siguiente s')
    _sPrime = _ql.applyAction(_s, _a);

    // 3) Generas el ejercicio en el NUEVO nivel (s')
    await _cargarEjercicio(_sPrime);
  }

  Future<void> _cargarEjercicio(String nivel) async {
    setState(() {
      _ex = _engine.generate(widget.tema, nivel);
      _bloqueado = false;
      _seleccion = null;
      _qStart = DateTime.now(); // inicio por pregunta
    });
  }

  // --------- Regla de recompensa inclusiva ----------
  double _calcularReward({
    required bool correcto,
    required int valorUsuario,
    required int respuestaCorrecta,
    required int duracionSeg,
  }) {
    double r;

    if (correcto) {
      r = _rCorrecto;
      if (duracionSeg < _bonusRapidoSeg) r += _rBonusRapido;     // bonus por rapidez
    } else {
      final diff = (valorUsuario - respuestaCorrecta).abs();
      r = (diff <= _umbralCercania) ? _rIncorrectoCerca : _rIncorrectoLejano; // castigos suaves
    }

    // penalización suave por tardanza (evita alargar sin foco)
    if (duracionSeg > _lentoSeg) r += _rPenalLento;

    // clamp para mantener rangos estables
    if (r > _rMax) r = _rMax;
    if (r < _rMin) r = _rMin;

    return r;
  }

  Future<void> _contestar(int valor) async {
    if (_bloqueado || _ex == null) return;
    setState(() {
      _bloqueado = true;
      _seleccion = valor;
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final correcto = (valor == _ex!.respuesta);

    final durSeg = _qStart == null
        ? 0
        : DateTime.now().difference(_qStart!).inSeconds;

    // <<< AQUÍ defines premio/castigo >>>
    final reward = _calcularReward(
      correcto: correcto,
      valorUsuario: valor,
      respuestaCorrecta: _ex!.respuesta,
      duracionSeg: durSeg,
    );

    // Stats locales
    if (correcto) {
      _aciertos++;
    } else {
      _errores++;
    }

    // Bellman update con (s, a, r, s')
    await _ql.updateQ(
      uid: uid,
      tema: widget.tema,
      s: _s,
      a: _a,
      r: reward,
      sPrime: _sPrime,
    );

    // Feedback visual
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correcto ? '¡Correcto!' : 'Incorrecto. Respuesta: ${_ex!.respuesta}',
          ),
          backgroundColor: correcto ? Colors.green : Colors.red,
          duration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  Future<void> _siguiente() async {
    setState(() => _idx++);

    if (_idx >= _max) {
      await _guardarSesionYMostrarResumen();
      return;
    }

    // Avanza el proceso de decisión: s ← s'
    _s = _sPrime;

    // Planifica el siguiente paso con el agente
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _planificarYSometerSiguiente(uid);
  }

  Future<void> _guardarSesionYMostrarResumen() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dur = DateTime.now().difference(_inicio).inSeconds;

    // Guardado best-effort
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

  @override
  Widget build(BuildContext context) {
    if (_ex == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mostrado = (_idx + 1 <= _max) ? (_idx + 1) : _max;

    return Scaffold(
      appBar: AppBar(title: Text('Repaso - ${widget.tema}')),
      body: Padding(
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
              final esSeleccion = _seleccion == o;
              final esCorrecta = o == _ex!.respuesta;

              Color? tileColor;
              if (_bloqueado) {
                if (esCorrecta) tileColor = Colors.green.withOpacity(0.15);
                if (esSeleccion && !esCorrecta) tileColor = Colors.red.withOpacity(0.15);
              }

              return Card(
                color: tileColor,
                child: ListTile(
                  title: Text(o.toString(), style: const TextStyle(fontSize: 18)),
                  onTap: _bloqueado ? null : () => _contestar(o),
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _bloqueado ? _siguiente : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_idx + 1 >= _max ? 'Finalizar' : 'Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
