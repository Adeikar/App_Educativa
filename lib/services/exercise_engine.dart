import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart'; 

enum FormatoEnunciado { simbolo, texto }

class Exercise {
  final String enunciado;
  final int respuesta;
  final List<int> opciones;
  final String nivel;
  final String tema;
  final int? opA;
  final int? opB;

  Exercise({
    required this.enunciado,
    required this.respuesta,
    required this.opciones,
    required this.nivel,
    required this.tema,
    this.opA,
    this.opB,
  });
}

class ExerciseEngine {
  //enunciado en formato con simbolos o en texto
  ExerciseEngine({this.formato = FormatoEnunciado.simbolo});
  final FormatoEnunciado formato;

  static const niveles = ['muy_basico', 'basico', 'medio', 'alto'];

  final Map<String, List<int>> _rangos = const {
    'muy_basico': [1, 7],
    'basico': [1, 12],
    'medio': [4, 16],
    'alto': [8, 25],
  };

  final Map<String, int> _topeResultado = const {
    'muy_basico': 14,
    'basico': 24,
    'medio': 32,
    'alto': 80,
  };

  final Map<String, Map<String, int>> _usedPairsWithCounter = {
    'suma': <String, int>{},
    'resta': <String, int>{},
    'multiplicacion': <String, int>{},
    'conteo': <String, int>{},
  };

  // Contador global de ejercicios 
  final Map<String, int> _exerciseCounter = {
    'suma': 0,
    'resta': 0,
    'multiplicacion': 0,
    'conteo': 0,
  };

  static const int _expirationThreshold = 5;
  static const int _maxPairsMem = 500;

// Retorna el valor mínimo, máximo tope
  int _min(String nivel) => (_rangos[nivel] ?? [1, 7])[0];
  int _max(String nivel) => (_rangos[nivel] ?? [1, 7])[1];
  int getTopeResultado(String nivel) => _topeResultado[nivel] ?? 14;

  // Retorna el valor del "salto grande" para subir el objetivo (usado por Q-Learning).
  int bigStepAddSub(String nivel) => switch (nivel) {
        'muy_basico' => 3,
        'basico' => 4,
        'medio' => 5,
        _ => 6,
      };

  // Retorna el valor del "salto pequeño" para bajar el objetivo (usado por Q-Learning).
  int smallStepAddSub(String nivel) => switch (nivel) {
        'muy_basico' => 2,
        'basico' => 3,
        'medio' => 4,
        _ => 5,
      };

  // Crea una clave única para un par de números, independientemente del orden (e.g., 2-5).
  String _pairKey(int a, int b) {
    if (a <= b) return '$a-$b';
    return '$b-$a';
  }

  // Verifica si un par de números fue usado recientemente y no ha "expirado" aún.
  bool _isPairUsed(String tema, int a, int b) {
    final key = _pairKey(a, b);
    final usedPairs = _usedPairsWithCounter[tema]!;
    
    if (!usedPairs.containsKey(key)) return false;
    
    final whenUsed = usedPairs[key]!;
    final currentCount = _exerciseCounter[tema]!;
    
    // Si la diferencia supera el umbral, el par se considera expirado y se remueve.
    if (currentCount - whenUsed >= _expirationThreshold) {
      usedPairs.remove(key);
      return false;
    }
    
    return true;
  }

  // Marca un par de números como usado con el valor del contador actual.
  void _markPairUsed(String tema, int a, int b) {
    final key = _pairKey(a, b);
    final usedPairs = _usedPairsWithCounter[tema]!;
    final currentCount = _exerciseCounter[tema]!;
    
    usedPairs[key] = currentCount;
    
    // Lógica de limpieza: remueve pares muy viejos si se supera el límite de memoria.
    if (usedPairs.length > _maxPairsMem) {
      final toRemove = <String>[];
      usedPairs.forEach((k, v) {
        if (currentCount - v > _expirationThreshold * 2) {
          toRemove.add(k);
        }
      });
      for (final k in toRemove) {
        usedPairs.remove(k);
      }
    }
  }

  void _incrementExerciseCounter(String tema) {
    _exerciseCounter[tema] = (_exerciseCounter[tema] ?? 0) + 1;
  }

  // Genera una lista de 4 opciones de respuesta, incluyendo la correcta, y las mezcla.
  List<int> _opciones(int correct, {int minVal = 0}) {
    final set = <int>{correct};
    int delta = 1;
    while (set.length < 4) {
      final c1 = correct + delta;
      final c2 = correct - delta;
      if (c1 >= minVal) set.add(c1);
      if (c2 >= minVal) set.add(c2);
      delta++;
      if (delta > 100) break;
    }
    final list = set.toList()..shuffle();
    return list;
  }

  // Formatea el enunciado 
  String _formatEnunciadoSuma(int a, int b) {
    return formato == FormatoEnunciado.simbolo
        ? '$a + $b = ?'
        : '¿Cuánto es $a más $b?';
  }

  String _formatEnunciadoResta(int a, int b) {
    return formato == FormatoEnunciado.simbolo
        ? '$a - $b = ?'
        : '¿Cuánto es $a menos $b?';
  }

  String _formatEnunciadoMult(int a, int b) {
    return formato == FormatoEnunciado.simbolo
        ? '$a × $b = ?'
        : '¿Cuánto es $a por $b?';
  }

  // Intenta encontrar un par de números válidos para una suma que dé un 'target'.
  bool _trySumPair(String nivel, int target, String tema, List<int> out) {
    final lo = _min(nivel), hi = _max(nivel);
    final aValues = List.generate(hi - lo + 1, (i) => lo + i)..shuffle();
    for (final a in aValues) {
      final b = target - a;
      if (b < lo || b > hi) continue;
      if (_isPairUsed(tema, a, b)) continue;
      out
        ..clear()
        ..addAll([a, b]);
      return true;
    }
    return false;
  }

  // Busca un par de números para suma, probando el 'target' y valores cercanos.
  List<int>? _pairForSum(String nivel, int target, String tema) {
    for (final t in [target, target - 1, target + 1, target - 2, target + 2]) {
      if (t < 2 || t > getTopeResultado(nivel)) continue;
      final out = <int>[];
      if (_trySumPair(nivel, t, tema, out)) return out;
    }
    return null;
  }

  // Intenta encontrar un par de números válidos para una resta que dé una 'diff'.
  bool _tryDiffPair(String nivel, int diff, String tema, List<int> out) {
    final lo = _min(nivel), hi = _max(nivel);
    final bValues = List.generate(hi - lo + 1, (i) => lo + i)..shuffle();
    for (final b in bValues) {
      final a = b + diff;
      if (a < lo || a > hi) continue;
      if (_isPairUsed(tema, a, b)) continue;
      out
        ..clear()
        ..addAll([a, b]);
      return true;
    }
    return false;
  }

  // Busca un par de números para resta, probando la 'diff' y valores cercanos.
  List<int>? _pairForDiff(String nivel, int diff, String tema) {
    final lo = _min(nivel), hi = _max(nivel);
    final maxDiff = hi - lo;
    for (final d in [diff, diff - 1, diff + 1, diff - 2, diff + 2]) {
      if (d < 0 || d > maxDiff) continue;
      final out = <int>[];
      if (_tryDiffPair(nivel, d, tema, out)) return out;
    }
    return null;
  }

  // Intenta encontrar un par de números válidos para una multiplicación que dé un 'target'.
  bool _tryProductPair(String nivel, int target, String tema, List<int> out) {
    final lo = max(1, _min(nivel)), hi = _max(nivel);
    final aValues = List.generate(hi - lo + 1, (i) => lo + i)..shuffle();
    for (final a in aValues) {
      if (a == 0) continue;
      if (target % a != 0) continue;
      final b = target ~/ a;
      if (b < lo || b > hi) continue;
      if (_isPairUsed(tema, a, b)) continue;
      out
        ..clear()
        ..addAll([a, b]);
      return true;
    }
    return false;
  }

  // Busca un par de números para multiplicación, probando el 'target' y valores cercanos.
  List<int>? _pairForProduct(String nivel, int target, String tema) {
    for (final t in [target, target - 1, target + 1, target - 2, target + 2]) {
      if (t < 1 || t > getTopeResultado(nivel)) continue;
      final out = <int>[];
      if (_tryProductPair(nivel, t, tema, out)) return out;
    }
    return null;
  }

  // Función de emergencia: encuentra el par no usado más cercano al 'target'.
  List<int> _fallbackClosestPair(String nivel, String tema, int target) {
    final lo = _min(nivel), hi = _max(nivel);
    final candidates = <List<int>>[];
    
    // Rellena los candidatos con todos los pares posibles si es necesario, y resetea el historial si no hay no usados.
    for (int a = lo; a <= hi; a++) {
      for (int b = lo; b <= hi; b++) {
        if (!_isPairUsed(tema, a, b)) candidates.add([a, b]);
      }
    }
    
    if (candidates.isEmpty) {
      _usedPairsWithCounter[tema]?.clear();
      for (int a = lo; a <= hi; a++) {
        for (int b = lo; b <= hi; b++) {
          candidates.add([a, b]);
        }
      }
    }
    
    // Ordena los pares por la diferencia absoluta de su resultado respecto al 'target'.
    candidates.sort((p1, p2) {
      int res1, res2;
      switch (tema) {
        case 'resta':
          res1 = (p1[0] - p1[1]).abs();
          res2 = (p2[0] - p2[1]).abs();
          break;
        case 'multiplicacion':
          res1 = p1[0] * p1[1];
          res2 = p2[0] * p2[1];
          break;
        default:
          res1 = p1[0] + p1[1];
          res2 = p2[0] + p2[1];
      }
      return (res1 - target).abs().compareTo((res2 - target).abs());
    });
    
    return candidates.first;
  }

  // Genera un ejercicio de suma basado en el nivel y objetivo deseado.
  Exercise genSuma(String nivel, int objetivo) {
    _incrementExerciseCounter('suma');
    
    final tope = getTopeResultado(nivel);
    final tgt = max(2, min(tope, objetivo));
    final pair = _pairForSum(nivel, tgt, 'suma') ?? _fallbackClosestPair(nivel, 'suma', tgt);
    final a = pair[0], b = pair[1];
    final res = a + b;
    final ex = Exercise(
      enunciado: _formatEnunciadoSuma(a, b),
      respuesta: res,
      opciones: _opciones(res, minVal: 0),
      nivel: nivel,
      tema: 'suma',
      opA: a,
      opB: b,
    );
    _markPairUsed('suma', a, b);
    return ex;
  }

  // Genera un ejercicio de resta basado en el nivel y objetivo deseado (diferencia).
  Exercise genResta(String nivel, int objetivo) {
    _incrementExerciseCounter('resta');
    
    final maxDiff = _max(nivel) - _min(nivel);
    final tgt = max(0, min(maxDiff, objetivo));
    final pair = _pairForDiff(nivel, tgt, 'resta') ?? _fallbackClosestPair(nivel, 'resta', tgt);
    int a = pair[0], b = pair[1];
    if (a < b) {
      final tmp = a; a = b; b = tmp;
    }
    final res = a - b;
    final ex = Exercise(
      enunciado: _formatEnunciadoResta(a, b),
      respuesta: res,
      opciones: _opciones(res, minVal: 0),
      nivel: nivel,
      tema: 'resta',
      opA: a,
      opB: b,
    );
    _markPairUsed('resta', a, b);
    return ex;
  }

  // Genera un ejercicio de multiplicación basado en el nivel y objetivo deseado (producto).
  Exercise genMult(String nivel, int objetivo) {
    _incrementExerciseCounter('multiplicacion');
    
    final tope = getTopeResultado(nivel);
    final tgt = max(1, min(tope, objetivo));
    final pair = _pairForProduct(nivel, tgt, 'multiplicacion') ??
        _fallbackClosestPair(nivel, 'multiplicacion', tgt);
    final a = pair[0], b = pair[1];
    final res = a * b;
    final ex = Exercise(
      enunciado: _formatEnunciadoMult(a, b),
      respuesta: res,
      opciones: _opciones(res, minVal: 0),
      nivel: nivel,
      tema: 'multiplicacion',
      opA: a,
      opB: b,
    );
    _markPairUsed('multiplicacion', a, b);
    return ex;
  }

  // Repite un emoji una cantidad 'n' de veces.
  String _repeatEmoji(String emoji, int n) {
    final buf = StringBuffer();
    for (var i = 0; i < n; i++) {
      buf.write(emoji);
    }
    return buf.toString();
  }

  // Genera un ejercicio de conteo de figuras.
  Exercise genConteo(String nivel, int objetivo) {
    _incrementExerciseCounter('conteo');
    
    final maxV = switch (nivel) {
      'muy_basico' => 7,
      'basico'     => 12,
      'medio'      => 15,
      _            => 20,
    };

    // Lógica para seleccionar un número objetivo no usado recientemente.
    int tgt = objetivo.clamp(1, maxV);
    
    final candidates = <int>[];
    for (int candidate = max(1, tgt - 2); candidate <= min(maxV, tgt + 2); candidate++) {
      if (!_isPairUsed('conteo', candidate, 1)) {
        candidates.add(candidate);
      }
    }
    
    // Si no hay candidatos, resetea el historial.
    if (candidates.isNotEmpty) {
      tgt = candidates[Random().nextInt(candidates.length)];
    } else {
      _usedPairsWithCounter['conteo']?.clear();
    }

    const emoji = '⭐';
    final figuras = _repeatEmoji(emoji, tgt);
    final enunciado = 'Cuenta las $emoji:\n$figuras';

    final ex = Exercise(
      enunciado: enunciado,
      respuesta: tgt,
      opciones: _opciones(tgt, minVal: 0),
      nivel: nivel,
      tema: 'conteo',
      opA: tgt,
      opB: 1,
    );
    _markPairUsed('conteo', tgt, 1);
    return ex;
  }

  // Función principal: genera el siguiente ejercicio ajustando el objetivo según la acción del Q-Learning.
  Exercise generateNextByAction(
    String tema,
    String nivel, {
    required String accion,
    required int objetivo,
  }) {
    final tope = getTopeResultado(nivel);
    final maxDiff = _max(nivel) - _min(nivel);
    int tgt = tema == 'resta' ? objetivo.clamp(0, maxDiff) : objetivo.clamp(1, tope);

    final parts = accion.split('-');
    final accionObj = parts.length > 1 ? parts[1] : 'mantener_obj';

    // Se actualiza el 'target' (tgt) del objetivo según la acciónObj y los saltos definidos.
    switch (accionObj) {
      case 'subir_obj':
        tgt = min(tema == 'resta' ? maxDiff : tope, objetivo + bigStepAddSub(nivel));
        break;
      case 'bajar_obj':
        // Asegura que el objetivo no baje de 0 para resta, o de 1 para otros temas.
        tgt = max(tema == 'resta' ? 0 : 1, objetivo - smallStepAddSub(nivel));
        break;
      case 'mantener_obj':
      default:
        break;
    }

    // Llama a la función de generación específica para el tema.
    switch (tema) {
      case 'suma':
        return genSuma(nivel, tgt);
      case 'resta':
        return genResta(nivel, tgt);
      case 'multiplicacion':
        return genMult(nivel, tgt);
      case 'conteo':
        return genConteo(nivel, tgt);
      default:
        throw ArgumentError('tema no válido: $tema');
    }
  }

  // Restablece el historial de pares usados y el contador para un tema.
  void resetPrevExercises(String tema) {
    _usedPairsWithCounter[tema]?.clear();
    _exerciseCounter[tema] = 0;
  }

  // Carga el historial de pares de ejercicios usados por el usuario desde Firestore.
  Future<void> loadUsedPairs(String uid, String tema) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      
      final data = doc.data();
      final recientes = data?['ejerciciosRecientes'] as Map<String, dynamic>?;
      final temaPairs = recientes?[tema] as Map<String, dynamic>?;
      
      if (temaPairs != null) {
        final loadedPairs = <String, int>{};
        temaPairs.forEach((key, value) {
          if (value is int) {
            loadedPairs[key] = value;
          }
        });
        
        _usedPairsWithCounter[tema] = loadedPairs;
        
        final maxCounter = loadedPairs.values.isEmpty 
             ? 0 
             : loadedPairs.values.reduce((a, b) => a > b ? a : b);
        _exerciseCounter[tema] = maxCounter;
      } else {

      }
    } catch (__) {

    }
  }

  // Guarda el historial de pares de ejercicios usados por el usuario en Firestore.
  Future<void> saveUsedPairs(String uid, String tema) async {
    try {
      final pairs = _usedPairsWithCounter[tema] ?? {};
      
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({
        'ejerciciosRecientes': {
          tema: pairs,
        },
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (__) {

    }
  }
}