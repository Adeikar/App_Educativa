import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class QLearningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double alpha;   // tasa de aprendizaje
  double gamma;   // descuento de futuro
  double epsilon; // exploración

  static const niveles = ['muy_basico', 'basico', 'medio', 'alto'];
  static const acciones = [
    'bajar-bajar_obj',
    'bajar-mantener_obj',
    'bajar-subir_obj',
    'mantener-bajar_obj',
    'mantener-mantener_obj',
    'mantener-subir_obj',
    'subir-bajar_obj',
    'subir-mantener_obj',
    'subir-subir_obj',
  ];

  QLearningService({
    this.alpha = 0.4,
    this.gamma = 0.95,
    this.epsilon = 0.2,
  });

  // lectura y escritura de documentos de usuario en Firestore.
  Future<Map<String, dynamic>> _getUserDoc(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    return snap.data() ?? <String, dynamic>{};
  }

  Future<void> _saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  //gestiona el nivel y objetivo de aprendizaje del usuario.
  Future<String?> getNivelActual(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    return t?['nivelActual'] as String?;
  }

  Future<void> setNivelActual(String uid, String tema, String nivel) {
    return _db.collection('usuarios').doc(uid).set({
      'progreso': {
        tema: {
          'nivelActual': nivel,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }
      },
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int?> getObjetivo(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    final obj = t?['objetivo'];
    if (obj is int) return obj;
    if (obj is num) return obj.toInt();
    return null;
  }

  Future<void> setObjetivo(String uid, String tema, int objetivo) async {
    await _db.collection('usuarios').doc(uid).set({
      'progreso': {
        tema: {
          'objetivo': objetivo,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }
      },
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // lógica de decisión para elegir una acción (exploración vs. explotación).
  String bucketObj(int obj) {
    if (obj <= 4) return 'L1';
    if (obj <= 8) return 'L2';
    if (obj <= 12) return 'L3';
    return 'L4';
  }

  String _bestAction(Map<String, dynamic> qState) {
    double best = -1e18;
    String bestA = acciones.first;
    for (final a in acciones) {
      final v = (qState[a] is num) ? (qState[a] as num).toDouble() : 0.0;
      if (v > best) {
        best = v;
        bestA = a;
      }
    }
    return bestA;
  }

  Future<String> pickAction(String uid, String tema, String nivel, int objetivo) async {
    final estado = '$tema:$nivel:${bucketObj(objetivo)}';
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
    final qState = qTable[tema]?[estado] as Map<String, dynamic>? ?? {};

    if (qState.isEmpty) {
      return 'mantener-mantener_obj'; // default neutro
    }
    //ver si nos conviene random o la mejora accion
    if (Random().nextDouble() < epsilon) {
      return acciones[Random().nextInt(acciones.length)]; // exploración
    }
    return _bestAction(qState);
  }

  // aplica la acción elegida para calcular el nuevo estado.
  Map<String, dynamic> applyAction(String nivel, int objetivo, String accion) {
    int i = niveles.indexOf(nivel);
    if (i < 0) i = 0;

    final parts = accion.split('-');
    final accionNivel = parts[0];
    final accionObj = parts.length > 1 ? parts[1] : 'mantener_obj';

    String nivelPrime = nivel;
    switch (accionNivel) {
      case 'bajar':
        nivelPrime = niveles[max(0, i - 1)];
        break;
      case 'subir':
        nivelPrime = niveles[min(niveles.length - 1, i + 1)];
        break;
    }

    int objetivoPrime = objetivo;
    final tope = _topeResultado[nivelPrime] ?? 10;
    final stepBig = bigStepAddSub(nivel);
    final stepSmall = smallStepAddSub(nivel);
    switch (accionObj) {
      case 'subir_obj':
        objetivoPrime = min(tope, objetivo + stepBig);
        break;
      case 'bajar_obj':
        objetivoPrime = max(2, objetivo - stepSmall);
        break;
    }

    return {'nivel': nivelPrime, 'objetivo': objetivoPrime};
  }

  // Actualizamos la tabla Q con la recompensa y el nuevo estado, que es el núcleo del aprendizaje.
  Future<void> updateQ({
    required String uid,
    required String tema,
    required String nivel,
    required int objetivo,
    required String a,
    required double r,
    required String nivelPrime,
    required int objetivoPrime,
    bool terminal = false,
  }) async {
    final s = '$tema:$nivel:${bucketObj(objetivo)}';
    final sPrime = '$tema:$nivelPrime:${bucketObj(objetivoPrime)}';
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
    final topic = Map<String, dynamic>.from(qTable[tema] ?? {});
    final qState = Map<String, dynamic>.from(topic[s] ?? {
      for (var act in acciones) act: 0.0,
    });

    final prev = (qState[a] is num) ? (qState[a] as num).toDouble() : 0.0;  

    double bestNext = 0.0;
    if (!terminal) {
      //mejor valor futur
      final qNext = Map<String, dynamic>.from(topic[sPrime] ?? {});
      if (qNext.isNotEmpty) {
        //la mejor accioin futura
        bestNext = qNext.values.fold<double>(
          -1e18,
          (p, e) => (e is num && e.toDouble() > p) ? e.toDouble() : p,
        );
      }
      if (bestNext < -1e17) bestNext = 0.0;
    }

    final target = r + gamma * bestNext;
    final updated = prev + alpha * (target - prev);
    qState[a] = updated;

    topic[s] = qState;
    qTable[tema] = topic;

    await _saveUserDoc(uid, {
      'qTable': qTable,
      'ultimoAcceso': FieldValue.serverTimestamp(),
    });
  }

  // gestiona la disminución de la tasa de exploración y los valores auxiliares.
  void decayEpsilon({double decayRate = 0.995, double minEpsilon = 0.01}) {
    epsilon = max(minEpsilon, epsilon * decayRate);
  }

  static const _topeResultado = {
    'muy_basico': 10,
    'basico': 20,
    'medio': 30,
    'alto': 80,
  };

  int bigStepAddSub(String nivel) => switch (nivel) {
        'muy_basico' => 3,
        'basico' => 4,
        'medio' => 5,
        _ => 6,
      };

  int smallStepAddSub(String nivel) => switch (nivel) {
        'muy_basico' => 2,
        'basico' => 3,
        'medio' => 4,
        _ => 5,
      };
}