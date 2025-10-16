import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import './exercise_engine.dart'; 

class QLearningService {
  //Inicializams
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ExerciseEngine _engine;

  double alpha;
  double gamma;
  double epsilon;

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

  // Constructor que inicializa el motor y los hiperparámetros.
  QLearningService({
    required ExerciseEngine engine, 
    this.alpha = 0.3,
    this.gamma = 0.9,
    this.epsilon = 0.25,
  }) : _engine = engine;

  Future<Map<String, dynamic>> _getUserDoc(String uid) async {
    final snap = await _db.collection('usuarios').doc(uid).get();
    return snap.data() ?? <String, dynamic>{};
  }

  Future<void> _saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<String?> getNivelActual(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    final nivel = t?['nivelActual'] as String?;

    return nivel;
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

  // Recupera el objetivo de aciertos o cantidad de ejercicios del usuario para un tema.
  Future<int?> getObjetivo(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    final obj = t?['objetivo'];
    
    if (obj is int) return obj;
    if (obj is num) return obj.toInt();
    
    return null;
  }

  // Guarda el objetivo de aciertos 
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

  // Calcula y obtiene el valor de epsilon, aplicando lógica de decaimiento basada en sesiones.
  Future<double> getEpsilon(String uid, String tema) async {
    final user = await _getUserDoc(uid);
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    final eps = t?['epsilon'];
    
    final sesiones = t?['totalSesiones'] as int? ?? 0;
    
    double epsilonBase;
    
    if (sesiones < 3) {
      epsilonBase = 0.5;
    } else if (sesiones < 10) {
      epsilonBase = 0.3;
    } else {
      epsilonBase = 0.15;
    }
    
    if (eps is double || eps is num) {
      final savedEps = (eps is double) ? eps : (eps as num).toDouble();
      return max(epsilonBase * 0.5, savedEps);
    }

    return epsilonBase;
  }

  // Guarda el valor de e.
  Future<void> setEpsilon(String uid, String tema, double eps) async {

    await _db.collection('usuarios').doc(uid).set({
      'progreso': {
        tema: {
          'epsilon': eps,
          'actualizadoEn': FieldValue.serverTimestamp(),
        }
      },
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Mapea el valor
  String bucketObj(int obj, String nivel) {
    switch (nivel) {
      case 'muy_basico':
        if (obj <= 3) return 'L1';
        if (obj <= 6) return 'L2';
        if (obj <= 10) return 'L3';
        return 'L4';
        
      case 'basico':
        if (obj <= 5) return 'L1';
        if (obj <= 10) return 'L2';
        if (obj <= 15) return 'L3';
        return 'L4';
        
      case 'medio':
        if (obj <= 8) return 'L1';
        if (obj <= 16) return 'L2';
        if (obj <= 24) return 'L3';
        return 'L4';
        
      case 'alto':
        if (obj <= 15) return 'L1';
        if (obj <= 30) return 'L2';
        if (obj <= 50) return 'L3';
        return 'L4';
        
      default:
        if (obj <= 4) return 'L1';
        if (obj <= 8) return 'L2';
        if (obj <= 12) return 'L3';
        return 'L4';
    }
  }

  // Encuentra y retorna la acción con el mayor valor Q para un estado dado (explotación).
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

  // Implementa la estrategia Epsilon-Greedy para seleccionar la próxima acción.
  Future<String> pickAction(String uid, String tema, String nivel, int objetivo) async {
    final estado = '$tema:$nivel:${bucketObj(objetivo, nivel)}';
    final user = await _getUserDoc(uid);
    final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
    final topicTable = qTable[tema] as Map<String, dynamic>?;
    final qState = topicTable?[estado] as Map<String, dynamic>? ?? {};

    if (qState.isEmpty) {
      return 'mantener-mantener_obj';
    }

    epsilon = await getEpsilon(uid, tema);
    
    final prog = user['progreso'] as Map<String, dynamic>?;
    final t = prog?[tema] as Map<String, dynamic>?;
    final ultimaAccion = t?['ultimaAccion'] as String?;
    final vecesRepetida = t?['vecesRepetidaAccion'] as int? ?? 0;
    
    // Forzar exploracion
    if (ultimaAccion == 'mantener-mantener_obj' && vecesRepetida >= 3) {

      final opcionesExploracion = [
        'subir-mantener_obj',
        'mantener-subir_obj',
        'subir-subir_obj',
      ];
      
      return opcionesExploracion[Random().nextInt(opcionesExploracion.length)];
    }
    
    final random = Random().nextDouble();
    
    if (random < epsilon) {
      final randomAction = acciones[Random().nextInt(acciones.length)];
      return randomAction; // Exploración
    }
    
    return _bestAction(qState); // Explotación
  }

  // Calcula el nuevo estado
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
        
      case 'mantener':
        break;
    }

    int objetivoPrime = objetivo;
    
    final tope = _engine.getTopeResultado(nivelPrime);
    final stepBig = _engine.bigStepAddSub(nivel);
    final stepSmall = _engine.smallStepAddSub(nivel);
    
    switch (accionObj) {
      case 'subir_obj':
        objetivoPrime = min(tope, objetivo + stepBig);
        break;
        
      case 'bajar_obj':
        objetivoPrime = max(2, objetivo - stepSmall);
        break;
        
      case 'mantener_obj':
        break;
    }
      return {'nivel': nivelPrime, 'objetivo': objetivoPrime};
  }

  // Función formula
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

  final s = '$tema:$nivel:${bucketObj(objetivo, nivel)}';
  final sPrime = '$tema:$nivelPrime:${bucketObj(objetivoPrime, nivelPrime)}';
  final user = await _getUserDoc(uid);
  final qTable = Map<String, dynamic>.from(user['qTable'] ?? {});
  final topic = Map<String, dynamic>.from(qTable[tema] ?? {});
  
  final qState = Map<String, dynamic>.from(topic[s] ?? {
    for (var act in acciones) act: 0.0, // Inicializa acciones nuevas.
  });

  final qActual = (qState[a] is num) ? (qState[a] as num).toDouble() : 0.0;

  double maxQNext = 0.0; // Recompensa futura máxima.
  
  if (!terminal) {
    // Carga la fila de valores Q para el Siguiente Estado (S').
    final qNext = Map<String, dynamic>.from(topic[sPrime] ?? {});
    
    if (qNext.isNotEmpty) {
      maxQNext = qNext.values.fold<double>(
        -1e18, // Valor inicial muy bajo.
        (maxVal, qValue) {
          final v = (qValue is num) ? qValue.toDouble() : 0.0;
          return v > maxVal ? v : maxVal;
        },
      );

      if (maxQNext < -1e17) maxQNext = 0.0;
    }

  } 

  final target = r + gamma * maxQNext;

  final tdError = target - qActual;

  final qNuevo = qActual + alpha * tdError;
  
  qState[a] = qNuevo;

  topic[s] = qState;

  qTable[tema] = topic;

  await _saveUserDoc(uid, {
    'qTable': qTable,
    'ultimoAcceso': FieldValue.serverTimestamp(), // Marca la hora.
  });
  
}

  // Reduce el valor de epsilon para favorecer la explotación.
  Future<void> decayEpsilon(String uid, String tema, {
    double decayRate = 0.995,
    double minEpsilon = 0.05,
  }) async {
    epsilon = await getEpsilon(uid, tema);
    
    final epsilonNuevo = max(minEpsilon, epsilon * decayRate);
    
    epsilon = epsilonNuevo;
    await setEpsilon(uid, tema, epsilonNuevo);
  }
}