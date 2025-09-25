import 'dart:math';

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

  /// historial anti-repetición por tema 
  final Map<String, Set<String>> _usedPairs = {
    'suma': <String>{},
    'resta': <String>{},
    'multiplicacion': <String>{},
    'conteo': <String>{},
  };

  /// limita crecimiento del set por si alguien hace sesiones larguísimas
  static const int _maxPairsMem = 500;

  // métodos auxiliares para obtener valores de configuración.
  int _min(String nivel) => (_rangos[nivel] ?? [1, 7])[0];
  int _max(String nivel) => (_rangos[nivel] ?? [1, 7])[1];
  int getTopeResultado(String nivel) => _topeResultado[nivel] ?? 14;

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

  // métodos para gestionar el historial de pares de números ya utilizados.
  String _pairKey(int a, int b) {
    if (a <= b) return '$a-$b';
    return '$b-$a';
  }

  bool _isPairUsed(String tema, int a, int b) {
    final key = _pairKey(a, b);
    return _usedPairs[tema]?.contains(key) ?? false;
  }

  void _markPairUsed(String tema, int a, int b) {
    final key = _pairKey(a, b);
    final set = _usedPairs[tema]!;
    set.add(key);
    // control simple de tamaño
    if (set.length > _maxPairsMem) {
      // eliminamos los primeros 50 elementos arbitrariamente
      final toRemove = set.take(50).toList();
      for (final k in toRemove) {
        set.remove(k);
      }
    }
  }

  // genera un conjunto de opciones de respuesta, incluyendo la correcta 
  List<int> _opciones(int correct, {int minVal = 0}) {
    // 4 opciones numéricas, incluye la correcta y 3 distractores cercanos
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

  // formatea el enunciado de los ejercicios de acuerdo al tipo (símbolo o texto).
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

  // intenta encontrar un par de números que cumpla con el objetivo para la suma sin repetición.
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

  // busca un par de números para la suma
  List<int>? _pairForSum(String nivel, int target, String tema) {
    for (final t in [target, target - 1, target + 1, target - 2, target + 2]) {
      if (t < 2 || t > getTopeResultado(nivel)) continue;
      final out = <int>[];
      if (_trySumPair(nivel, t, tema, out)) return out;
    }
    return null;
  }

  // intenta encontrar un par de números para la resta
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

  // busca un par para la resta
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

  // intenta encontrar un par de números que cumpla con el objetivo de la multiplicación.
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

  // busca un par para la multiplicación
  List<int>? _pairForProduct(String nivel, int target, String tema) {
    for (final t in [target, target - 1, target + 1, target - 2, target + 2]) {
      if (t < 1 || t > getTopeResultado(nivel)) continue;
      final out = <int>[];
      if (_tryProductPair(nivel, t, tema, out)) return out;
    }
    return null;
  }

  // genera un par de números de respaldo si no se encuentra un par ideal.
  List<int> _fallbackClosestPair(String nivel, String tema, int target) {
    final lo = _min(nivel), hi = _max(nivel);
    final candidates = <List<int>>[];
    for (int a = lo; a <= hi; a++) {
      for (int b = lo; b <= hi; b++) {
        if (!_isPairUsed(tema, a, b)) candidates.add([a, b]);
      }
    }
    if (candidates.isEmpty) {
      final a = Random().nextInt(hi - lo + 1) + lo;
      final b = Random().nextInt(hi - lo + 1) + lo;
      return [a, b];
    }
    candidates.sort((p1, p2) {
      int res1, res2;
      switch (tema) {
        case 'resta':
          res1 = p1[0] - p1[1];
          res2 = p2[0] - p2[1];
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

  // genera un ejercicio de suma.
  Exercise genSuma(String nivel, int objetivo) {
    final tope = getTopeResultado(nivel);
    final tgt = max(2, min(tope, objetivo));
    final pair = _pairForSum(nivel, tgt, 'suma') ?? _fallbackClosestPair(nivel, 'suma', tgt);
    int a = pair[0], b = pair[1];
    if (a > b) {
      final tmp = a; a = b; b = tmp;
    }
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

  // genera un ejercicio de resta.
  Exercise genResta(String nivel, int objetivo) {
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

  // genera un ejercicio de multiplicación.
  Exercise genMult(String nivel, int objetivo) {
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

  // genera un ejercicio de conteo con estrellas (⭐).
  String _repeatEmoji(String emoji, int n) {
    final buf = StringBuffer();
    for (var i = 0; i < n; i++) {
      buf.write(emoji);
    }
    return buf.toString();
  }

  Exercise genConteo(String nivel, int objetivo) {
    final maxV = switch (nivel) {
      'muy_basico' => 7,
      'basico'     => 12,
      'medio'      => 15,
      _            => 20,
    };

    final tgt = objetivo.clamp(1, maxV);

    // objeto fijo: estrellas
    const emoji = '⭐';

    final figuras = _repeatEmoji(emoji, tgt);
    final enunciado = 'cuenta las $emoji:\n$figuras';

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

  // selecciona y genera el siguiente ejercicio según el tema, nivel y la acción de q-learning.
  Exercise generateNextByAction(
    String tema,
    String nivel, {
    required String accion,
    required int objetivo,
  }) {
    if (!['suma', 'resta', 'multiplicacion', 'conteo'].contains(tema)) {
      throw ArgumentError('tema no válido: $tema');
    }

    final tope = getTopeResultado(nivel);
    final maxDiff = _max(nivel) - _min(nivel);
    int tgt = tema == 'resta' ? objetivo.clamp(0, maxDiff) : objetivo.clamp(1, tope);

    final parts = accion.split('-');
    final accionObj = parts.length > 1 ? parts[1] : 'mantener_obj';

    switch (accionObj) {
      case 'subir_obj':
        tgt = min(tema == 'resta' ? maxDiff : tope, objetivo + bigStepAddSub(nivel));
        break;
      case 'bajar_obj':
        tgt = max(tema == 'resta' ? 0 : 1, objetivo - smallStepAddSub(nivel));
        break;
      case 'mantener_obj':
      default:
        break;
    }

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

  // resetea el historial de ejercicios no repetidos para un tema específico.
  void resetPrevExercises(String tema) {
    _usedPairs[tema]?.clear();
  }
}