import '../services/tema_service.dart';

/// Llámalo una sola vez (p. ej. desde un botón oculto o en un script manual).
Future<void> seedTemasBasicos() async {
  final service = TemaService();

  final seeds = <Map<String, String>>[
    {
      'nombre': 'suma',
      'concepto': 'Operación básica que combina cantidades. Ej: 2 + 3 = 5',
    },
    {
      'nombre': 'resta',
      'concepto': 'Quita una cantidad de otra. Ej: 5 - 2 = 3',
    },
    {
      'nombre': 'multiplicacion',
      'concepto': 'Sumas repetidas. Ej: 3 × 4 = 12',
    },
    {
      'nombre': 'conteo',
      'concepto': 'Enumerar elementos para conocer la cantidad total.',
    },
  ];

  for (final t in seeds) {
    await service.crearTema(
      nombre: t['nombre']!,
      concepto: t['concepto']!,
    );
  }
}
