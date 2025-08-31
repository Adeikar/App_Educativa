import 'dart:math';

class Exercise {
  final String enunciado;
  final int respuesta;
  final List<int> opciones;
  final String nivel;
  final String tema;

  Exercise({
    required this.enunciado,
    required this.respuesta,
    required this.opciones,
    required this.nivel,
    required this.tema,
  });
}

class ExerciseEngine {
  final _r = Random();

  // Rangos por nivel
  Map<String, List<int>> get _rangos => {
        'muy_basico': [0, 5],
        'basico': [0, 10],
        'medio': [5, 20],
        'alto': [10, 50],
      };

  int _n(String nivel) {
    final r = _rangos[nivel] ?? [0, 10];
    return r[0] + _r.nextInt(r[1] - r[0] + 1);
  }

  List<int> _opciones(int correct, {int dispersion = 5, int minVal = 0}) {
    final set = <int>{correct};
    while (set.length < 4) {
      final delta = _r.nextInt(dispersion) + 1;
      final cand = _r.nextBool() ? correct + delta : correct - delta;
      if (cand >= minVal) set.add(cand);
    }
    return set.toList()..shuffle();
  }

  Exercise generate(String tema, String nivel) {
    switch (tema) {
      case 'suma':
        final a = _n(nivel), b = _n(nivel);
        return Exercise(
          enunciado: '$a + $b = ?',
          respuesta: a + b,
          opciones: _opciones(a + b),
          nivel: nivel,
          tema: tema,
        );
      case 'resta':
        int a = _n(nivel), b = _n(nivel);
        if (b > a) {
          final t = a;
          a = b;
          b = t;
        }
        return Exercise(
          enunciado: '$a - $b = ?',
          respuesta: a - b,
          opciones: _opciones(a - b),
          nivel: nivel,
          tema: tema,
        );
      case 'multiplicacion':
        final a = _n(nivel), b = max(1, _n(nivel) ~/ 2);
        return Exercise(
          enunciado: '$a × $b = ?',
          respuesta: a * b,
          opciones: _opciones(a * b, dispersion: 10),
          nivel: nivel,
          tema: tema,
        );
      case 'conteo':
        final n = 1 + _r.nextInt(10);
        return Exercise(
          enunciado: 'Cuenta los objetos: ${"🍎 " * n}',
          respuesta: n,
          opciones: _opciones(n, minVal: 0),
          nivel: nivel,
          tema: tema,
        );
      default:
        return Exercise(
          enunciado: 'No válido',
          respuesta: 0,
          opciones: [0, 1, 2, 3],
          nivel: nivel,
          tema: tema,
        );
    }
  }
}
