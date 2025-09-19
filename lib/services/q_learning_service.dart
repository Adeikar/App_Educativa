import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class QLearningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double alpha;   // tasa aprendizaje
  double gamma;   // descuento de futuro
  double epsilon; // exploración (puede decaer)
  final _rand = Random();

  static const niveles = ['muy_basico', 'basico', 'medio', 'alto'];
  static const acciones = ['bajar', 'mantener', 'subir'];

  QLearningService({
    this.alpha = 0.2,
    this.gamma = 0.95,
    this.epsilon = 0.2,
  });

  Future<Map<String, dynamic>> _getUserDoc(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    return snap.data() ?? <String, dynamic>{};
  }

  Future<void> _saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  // ---------- Helpers de estructura y migración ----------

  Map<String, dynamic> _topic(Map<String, dynamic> qTable, String tema) {
    final raw = qTable[tema];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _ensureTopicState(
    Map<String, dynamic> qTable,
    String tema,
    String estado,
  ) {
    final topic = _topic(qTable, tema);
    final rawState = topic[estado];

    Map<String, dynamic> qState;

    if (rawState is Map) {
      qState = Map<String, dynamic>.from(rawState);
    } else if (rawState is num) {
      // MIGRACIÓN desde formato viejo: nivel -> double
      qState = {
        'bajar': 0.0,
        'mantener': (rawState as num).toDouble(),
        'subir': 0.0,
      };
    } else {
      // Estado nuevo
      qState = {'bajar': 0.0, 'mantener': 0.0, 'subir': 0.0};
    }

    // Asegura claves faltantes
    for (final a in acciones) {
      if (qState[a] is! num) qState[a] = 0.0;
    }

    // Vuelve a colocar en la estructura
    topic[estado] = qState;
    qTable[tema] = topic;
    return qState;
  }

  Map<String, dynamic> _getTopicStateReadonly(
    Map<String, dynamic> qTable,
    String tema,
    String estado,
  ) {
    final topic = _topic(qTable, tema);
    final raw = topic[estado];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
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

  // ---------- Política (ε-greedy) ----------

  Future<String> pickAction(String uid, String tema, String estado) async {
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});

    // Para elegir podemos leer "readonly"; si hay números viejos, igual elegimos aleatorio por ε
    final qState = _getTopicStateReadonly(qTable, tema, estado);

    if (_rand.nextDouble() < epsilon || qState.isEmpty) {
      return acciones[_rand.nextInt(acciones.length)];
    }
    return _bestAction(qState);
  }

  // ---------- Dinámica del nivel (transición de estado) ----------

  String applyAction(String estado, String accion) {
    int i = niveles.indexOf(estado);
    if (i < 0) i = 0;
    switch (accion) {
      case 'bajar':
        i = max(0, i - 1);
        break;
      case 'mantener':
        break;
      case 'subir':
        i = min(niveles.length - 1, i + 1);
        break;
      default:
        break;
    }
    return niveles[i];
  }

  // ---------- Actualización Bellman ----------

  Future<void> updateQ({
    required String uid,
    required String tema,
    required String s,       
    required String a,       
    required double r,       
    required String sPrime,  
  }) async {
    // Leemos doc
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});

    // Aseguramos/migramos los estados involucrados
    final qState = _ensureTopicState(qTable, tema, s);
    final qNext  = _ensureTopicState(qTable, tema, sPrime);

    final prev = (qState[a] is num) ? (qState[a] as num).toDouble() : 0.0;

    double bestNext = -1e18;
    for (final ap in acciones) {
      final v = (qNext[ap] is num) ? (qNext[ap] as num).toDouble() : 0.0;
      if (v > bestNext) bestNext = v;
    }
    if (bestNext == -1e18) bestNext = 0.0;

    final target = r + gamma * bestNext;
    final updated = prev + alpha * (target - prev);

    qState[a] = updated;

    // Persistimos estructura completa
    final topic = _topic(qTable, tema);
    topic[s] = qState;
    qTable[tema] = topic;

    await _saveUserDoc(uid, {
      'qTable': qTable,
      'ultimoAcceso': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Opcional: decaimiento de ε ----------

  void decayEpsilon({double minEps = 0.05, double factor = 0.995}) {
    epsilon = max(minEps, epsilon * factor);
  }
}
