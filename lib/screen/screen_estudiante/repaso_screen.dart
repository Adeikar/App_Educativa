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

  // ejercicio actual
  Exercise? _ex;
  String? _nivel;

  // estado de sesión
  int _idx = 0;                 // índice 0.._max-1 (lo que mostramos será _idx+1, sin pasarse de _max)
  int _aciertos = 0;
  int _errores = 0;
  final int _max = 10;
  late DateTime _inicio;

  // feedback de pregunta
  bool _bloqueado = false;      // para evitar múltiples taps
  int? _seleccion;              // opción seleccionada por el usuario

  // control de dificultad local (evita saltos bruscos)
  final List<String> _orden = ['muy_basico', 'basico', 'medio', 'alto'];
  int _streakOK = 0;            // racha de aciertos

  @override
  void initState() {
    super.initState();
    _inicio = DateTime.now();
    _cargarPrimero();
  }

  Future<void> _cargarPrimero() async {
    // primer nivel según Q-Table (sin exploración aleatoria visualmente molesta)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final nivel = await _ql.selectNivel(uid, widget.tema);
    await _cargarEjercicio(nivel);
  }

  Future<void> _cargarEjercicio(String nivel) async {
    setState(() {
      _nivel = nivel;
      _ex = _engine.generate(widget.tema, nivel);
      _bloqueado = false;
      _seleccion = null;
    });
  }

  int _clampNivelIndex(int i) => i.clamp(0, _orden.length - 1);

  String _bajarNivel(String actual) {
    final i = _clampNivelIndex(_orden.indexOf(actual) - 1);
    return _orden[i];
    }

  String _subirNivel(String actual) {
    final i = _clampNivelIndex(_orden.indexOf(actual) + 1);
    return _orden[i];
  }

  Future<void> _contestar(int valor) async {
    if (_bloqueado || _ex == null || _nivel == null) return;
    setState(() {
      _bloqueado = true;
      _seleccion = valor;
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final correcto = (valor == _ex!.respuesta);
    final reward = correcto ? 1.0 : -1.0;

    // actualizar métrica local
    if (correcto) {
      _aciertos++;
      _streakOK++;
    } else {
      _errores++;
      _streakOK = 0;
    }

    // actualizar Q-Table en Firestore
    await _ql.updateQ(uid, widget.tema, _nivel!, reward);

    // feedback visual inmediato
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
    // avanzar índice SOLO cuando el usuario pulsa “Siguiente”
    setState(() => _idx++);

    if (_idx >= _max) {
      await _guardarSesionYMostrarResumen();
      return;
    }

    // lógica de dificultad adaptativa (local, sin “explorar” aleatoriamente)
    String proximo = _nivel ?? 'muy_basico';
    if (_seleccion == _ex!.respuesta) {
      // si va bien dos seguidas, subir un nivel
      if (_streakOK >= 2) {
        proximo = _subirNivel(proximo);
        _streakOK = 0; // reinicia para exigir otra racha en el nuevo nivel
      }
    } else {
      // si falla, bajar inmediatamente
      proximo = _bajarNivel(proximo);
    }

    await _cargarEjercicio(proximo);
  }

  Future<void> _guardarSesionYMostrarResumen() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dur = DateTime.now().difference(_inicio).inSeconds;

    // Intento de guardado (no rompemos la UI si falla)
    try {
      await FirebaseFirestore.instance.collection('sesiones').add({
        'fecha': FieldValue.serverTimestamp(),
        'estudianteId': uid,
        'tema': widget.tema,
        'duracion': dur,
        'aciertos': _aciertos,
        'errores': _errores,
        // puedes añadir el detalle por ejercicio si quieres
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

    // índice mostrado (no pasa de _max)
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
