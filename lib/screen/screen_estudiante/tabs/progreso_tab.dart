import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repaso_screen.dart'; // <-- ajusta la ruta si tu estructura difiere

/// Estructura agregada por tema
class _TemaStats {
  int ejercicios = 0;
  int aciertos = 0;
  int errores = 0;
  int segundos = 0;

  int get intentos => ejercicios; // alias semántico
  double get accuracy => ejercicios == 0 ? 0 : aciertos / ejercicios;
}

class ProgresoTab extends StatefulWidget {
  const ProgresoTab({super.key});

  @override
  State<ProgresoTab> createState() => _ProgresoTabState();
}

class _ProgresoTabState extends State<ProgresoTab> {
  bool _loading = true;
  String _ultimoTema = 'Ninguno';
  int _totalIntentos = 0;
  int _totalSegundos = 0;

  /// Progreso agregado por tema (suma/resta/multiplicacion/conteo)
  final Map<String, _TemaStats> _porTema = {};

  /// Niveles estimados desde la Q-Table (muy_basico, basico, medio, alto)
  Map<String, String> _nivelPorTema = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _porTema.clear();
      _nivelPorTema = {};
      _ultimoTema = 'Ninguno';
      _totalIntentos = 0;
      _totalSegundos = 0;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // --- 1) Leer sesiones del usuario ---
      final sesionesSnap = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('estudianteId', isEqualTo: uid)
          .orderBy('fecha', descending: true)
          .get();

      String ultimo = 'Ninguno';
      int totalIntentos = 0;
      int totalSegundos = 0;

      final Map<String, _TemaStats> porTema = {};

      for (final doc in sesionesSnap.docs) {
        final data = doc.data();

        final ejercicios = (data['ejercicios'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        // tiempo de la sesión
        final dur = (data['duracion'] is num)
            ? (data['duracion'] as num).toInt()
            : 0;
        totalSegundos += dur;

        // si guardaste 'tema' directo en la sesión (tu variante más reciente)
        final temaRaiz = (data['tema'] as String?)?.trim();

        if (ejercicios.isEmpty && temaRaiz != null && temaRaiz.isNotEmpty) {
          // Sesión sin detalle, pero con tema y aciertos/errores totales
          final t = temaRaiz;
          porTema.putIfAbsent(t, () => _TemaStats());
          porTema[t]!.ejercicios +=
              ((data['aciertos'] ?? 0) as num).toInt() +
                  ((data['errores'] ?? 0) as num).toInt();
          porTema[t]!.aciertos += ((data['aciertos'] ?? 0) as num).toInt();
          porTema[t]!.errores += ((data['errores'] ?? 0) as num).toInt();
          porTema[t]!.segundos += dur;

          totalIntentos += porTema[t]!.ejercicios;
          if (ultimo == 'Ninguno') ultimo = t;
          continue;
        }

        // Sesión con detalle por ejercicio
        for (final e in ejercicios) {
          final t = (e['tema'] as String?)?.trim() ?? 'desconocido';
          porTema.putIfAbsent(t, () => _TemaStats());
          porTema[t]!.ejercicios += 1;
          porTema[t]!.segundos += (e['tiempoRespuesta'] is num)
              ? (e['tiempoRespuesta'] as num).toInt()
              : 0;

          final correcto = e['correcto'];
          if (correcto is bool) {
            if (correcto) {
              porTema[t]!.aciertos += 1;
            } else {
              porTema[t]!.errores += 1;
            }
          }
        }

        totalIntentos += ejercicios.length;
        if (ultimo == 'Ninguno' && ejercicios.isNotEmpty) {
          ultimo = ejercicios.last['tema']?.toString() ?? 'Ninguno';
        }
      }

      // --- 2) Leer Q-Table para inferir nivel por tema ---
      final userSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      final qTable =
          (userSnap.data()?['qTable'] as Map<String, dynamic>?) ?? {};
      final Map<String, String> nivelPorTema = {};
      const niveles = ['muy_basico', 'basico', 'medio', 'alto'];

      String _argmaxNivel(Map<String, dynamic> tablaTema) {
        String best = 'muy_basico';
        double bestQ = -1e9;
        for (final n in niveles) {
          final q = (tablaTema[n] is num)
              ? (tablaTema[n] as num).toDouble()
              : 0.0;
          if (q > bestQ) {
            bestQ = q;
            best = n;
          }
        }
        return best;
      }

      for (final entry in qTable.entries) {
        final tema = entry.key.toString();
        final tablaTema = (entry.value as Map<String, dynamic>? ) ?? {};
        nivelPorTema[tema] = _argmaxNivel(tablaTema);
      }

      setState(() {
        _porTema
          ..clear()
          ..addAll(porTema);
        _nivelPorTema = nivelPorTema;
        _ultimoTema = ultimo;
        _totalIntentos = totalIntentos;
        _totalSegundos = totalSegundos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar progreso: $e')),
      );
    }
  }

  String _formatDur(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m == 0) return '${sec}s';
    return '${m}m ${sec}s';
    }

  Color _colorByAccuracy(double acc) {
    if (acc >= 0.8) return Colors.green;
    if (acc >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _nivelLabel(String? n) {
    switch (n) {
      case 'muy_basico':
        return 'Muy básico';
      case 'basico':
        return 'Básico';
      case 'medio':
        return 'Medio';
      case 'alto':
        return 'Alto';
      default:
        return '—';
    }
  }

  Widget _temaCard(String tema, _TemaStats st) {
    final acc = st.accuracy;
    final nivelTxt = _nivelLabel(_nivelPorTema[tema]);

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // encabezado
            Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tema,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Nivel: $nivelTxt',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // datos
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Intentos: ${st.intentos}\nAciertos: ${st.aciertos}\nErrores: ${st.errores}',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Text(
                  _formatDur(st.segundos),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // barra de progreso de aciertos
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: acc,
                color: _colorByAccuracy(acc),
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(acc * 100).toStringAsFixed(0)}% aciertos',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            // botones
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RepasoScreen(tema: tema),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Practicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final temasOrdenados = _porTema.keys.toList()
      ..sort((a, b) => (_porTema[b]!.intentos).compareTo(_porTema[a]!.intentos));

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumen
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text('Resumen general',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Intentos: $_totalIntentos   •   Tiempo: ${_formatDur(_totalSegundos)}',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_added),
              title: const Text('Último tema'),
              subtitle: Text(_ultimoTema),
              trailing: TextButton(
                onPressed: _ultimoTema == 'Ninguno'
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RepasoScreen(tema: _ultimoTema),
                          ),
                        );
                      },
                child: const Text('Continuar'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Por tema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (temasOrdenados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aún no hay intentos registrados')),
            )
          else
            ...temasOrdenados.map((t) => _temaCard(t, _porTema[t]!)),

          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
