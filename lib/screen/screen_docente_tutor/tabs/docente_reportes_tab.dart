// Reportes por estudiante con búsqueda en vivo + charts + vista previa + PDF
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Charts UI
import 'package:syncfusion_flutter_charts/charts.dart';

// PDF
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class DocenteReportesTab extends StatefulWidget {
  final String? initialStudentId;
  final String? initialStudentName;
  final VoidCallback? onClearSelection;

  const DocenteReportesTab({
    super.key,
    this.initialStudentId,
    this.initialStudentName,
    this.onClearSelection,
  });

  @override
  State<DocenteReportesTab> createState() => _DocenteReportesTabState();
}

class _DocenteReportesTabState extends State<DocenteReportesTab> {
  // --- BÚSQUEDA EN VIVO ---
  final _buscarCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  // --- SELECCIÓN ---
  String? _estudianteId;
  String? _estudianteNombre;

  // --- CARGA ---
  bool _loading = false;

  // --- ACUMULADOS ---
  int _intentos = 0;
  int _aciertos = 0;
  int _errores = 0;
  int _segundos = 0;

  // --- POR TEMA ---
  // {tema: {intentos, aciertos, errores}}
  Map<String, Map<String, int>> _temaData = {};

  @override
  void initState() {
    super.initState();
    // Si viene una selección inicial (desde Inicio), aplicarla
    if (widget.initialStudentId != null) {
      _estudianteId = widget.initialStudentId;
      _estudianteNombre = widget.initialStudentName ?? 'Estudiante';
      _buscarCtrl.text = _estudianteNombre!;
      _cargar();
    }
    _buscarCtrl.addListener(_onQueryChanged);
  }

  // 👇 CLAVE: si cambian las props (por ejemplo, seleccionas otro alumno desde Inicio),
  // recargamos automáticamente.
  @override
  void didUpdateWidget(covariant DocenteReportesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedId = widget.initialStudentId != oldWidget.initialStudentId;
    final changedName = widget.initialStudentName != oldWidget.initialStudentName;

    if (changedId || changedName) {
      if (widget.initialStudentId == null) {
        // Limpieza si te piden limpiar selección
        setState(() {
          _estudianteId = null;
          _estudianteNombre = null;
          _buscarCtrl.clear();
          _query = '';
          _resetAcumulados();
        });
      } else {
        // Nueva selección → refrescar
        setState(() {
          _estudianteId = widget.initialStudentId;
          _estudianteNombre = widget.initialStudentName ?? 'Estudiante';
          _buscarCtrl.text = _estudianteNombre!;
          _query = _estudianteNombre!;
        });
        _cargar();
      }
    }
  }

  @override
  void dispose() {
    _buscarCtrl.removeListener(_onQueryChanged);
    _buscarCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- Search ----------
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      setState(() => _query = _buscarCtrl.text.trim());
    });
  }

  Future<List<_StudentHit>> _searchStudents(String q) async {
    final query = q.trim();
    if (query.isEmpty) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'estudiante')
          .orderBy('nombre')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(10)
          .get();
      return snap.docs
          .map((d) => _StudentHit(
                id: d.id,
                nombre: (d.data()['nombre'] ?? 'Estudiante').toString(),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _seleccionarEstudiante(_StudentHit s) async {
    setState(() {
      _estudianteId = s.id;
      _estudianteNombre = s.nombre;
      _buscarCtrl.text = s.nombre;
      _query = s.nombre;
    });
    await _cargar();
    FocusScope.of(context).unfocus();
  }

  void _resetAcumulados() {
    _intentos = 0;
    _aciertos = 0;
    _errores = 0;
    _segundos = 0;
    _temaData = {};
  }

  // ---------- Carga datos ----------
  Future<void> _cargar() async {
    if (_estudianteId == null) return;
    setState(() {
      _loading = true;
      _resetAcumulados();
    });

    try {
      final q = await FirebaseFirestore.instance
          .collection('sesiones')
          .where('estudianteId', isEqualTo: _estudianteId)
          .get();

      for (final doc in q.docs) {
        final data = doc.data();
        final ejercicios =
            (data['ejercicios'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final dur =
            (data['duracion'] is num) ? (data['duracion'] as num).toInt() : 0;
        _segundos += dur;

        if (ejercicios.isEmpty) {
          // Sesión tipo “resumen por tema”
          final tema = (data['tema'] as String?)?.trim();
          if (tema != null && tema.isNotEmpty) {
            final ac = (data['aciertos'] ?? 0) as num;
            final er = (data['errores'] ?? 0) as num;
            final it = ac.toInt() + er.toInt();
            _intentos += it;
            _aciertos += ac.toInt();
            _errores += er.toInt();

            final t = _temaData.putIfAbsent(
                tema, () => {'intentos': 0, 'aciertos': 0, 'errores': 0});
            t['intentos'] = t['intentos']! + it;
            t['aciertos'] = t['aciertos']! + ac.toInt();
            t['errores'] = t['errores']! + er.toInt();
          }
          continue;
        }

        // Sesión con detalle
        for (final e in ejercicios) {
          final tema = (e['tema'] as String?)?.trim() ?? 'desconocido';
          final correcto = e['correcto'] == true;
          _intentos += 1;
          if (correcto) {
            _aciertos++;
          } else {
            _errores++;
          }

          final t = _temaData.putIfAbsent(
              tema, () => {'intentos': 0, 'aciertos': 0, 'errores': 0});
          t['intentos'] = t['intentos']! + 1;
          if (correcto) {
            t['aciertos'] = t['aciertos']! + 1;
          } else {
            t['errores'] = t['errores']! + 1;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reportes: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Utils ----------
  String _fmt(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    if (m == 0) return '${ss}s';
    return '${m}m ${ss}s';
  }

  // Recomendaciones simples
  List<String> _buildRecomendaciones() {
    final recs = <String>[];
    if (_temaData.isEmpty) {
      recs.add('No hay suficientes datos para recomendaciones.');
      return recs;
    }

    final porTema = _temaData.entries.map((e) {
      final it = e.value['intentos'] ?? 0;
      final ac = e.value['aciertos'] ?? 0;
      final acc = it == 0 ? 0.0 : ac / it;
      return _TemaAcc(tema: e.key, intentos: it, aciertos: ac, precision: acc);
    }).toList();

    porTema.sort((a, b) => a.precision.compareTo(b.precision));
    final peor = porTema.first;
    final mejor = porTema.last;

    if (peor.precision < 0.6) {
      recs.add(
          'Refuerzo recomendado en **${peor.tema}** (precisión ${(peor.precision * 100).toStringAsFixed(0)}%).');
    } else {
      recs.add('Desempeño estable en todos los temas, continuar práctica regular.');
    }

    if (mejor.precision >= 0.8) {
      recs.add(
          'Buen rendimiento en **${mejor.tema}**; se puede subir gradualmente la dificultad.');
    }

    if (_intentos >= 20 && _errores / max(1, _intentos) > 0.4) {
      recs.add(
          'Alto índice de errores globales; considerar pausas y ejercicios guiados.');
    }

    return recs;
  }

  // ---------- PDF ----------
  Future<void> _downloadPdf() async {
    if (_estudianteNombre == null) return;
    final bytes = await _buildPdfBytes(_estudianteNombre!, DateTime.now());
    await Printing.sharePdf(bytes: bytes, filename: 'reporte_${_estudianteNombre!}.pdf');
  }

  Future<Uint8List> _buildPdfBytes(String nombre, DateTime fecha) async {
    final doc = pw.Document();
    final acc = _intentos == 0 ? 0.0 : _aciertos / _intentos;
    final recs = _buildRecomendaciones();

    pw.Widget _kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text(k), pw.Text(v)],
          ),
        );

    pw.Widget _bar(int value, int max, {int height = 8}) {
      final m = max <= 0 ? 1 : max;
      final w = 300.0 * (value / m);
      return pw.Container(
        width: 300,
        height: height.toDouble(),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.9, 0.9, 0.9),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Container(
          width: w,
          height: height.toDouble(),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.2, 0.6, 0.9),
            borderRadius: pw.BorderRadius.circular(4),
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text('Reporte de Progreso',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Estudiante: $nombre'),
          pw.Text('Fecha: ${fecha.toLocal()}'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: .5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Intentos', '$_intentos'),
                _kv('Aciertos', '$_aciertos'),
                _kv('Errores', '$_errores'),
                _kv('Tiempo', _fmt(_segundos)),
                _kv('Precisión', '${(acc * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Desempeño por tema', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (_temaData.isEmpty)
            pw.Text('Sin datos por tema')
          else
            ..._temaData.entries.map((e) {
              final it = e.value['intentos'] ?? 0;
              final acT = e.value['aciertos'] ?? 0;
              final erT = e.value['errores'] ?? 0;
              final maxv = [it, acT, erT].reduce(max);
              final pct = it == 0 ? 0.0 : acT / it;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: .5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Intentos: $it'),
                    _bar(it, maxv),
                    pw.SizedBox(height: 4),
                    pw.Text('Aciertos: $acT'),
                    _bar(acT, maxv),
                    pw.SizedBox(height: 4),
                    pw.Text('Errores: $erT'),
                    _bar(erT, maxv),
                    pw.SizedBox(height: 4),
                    pw.Text('Precisión: ${(pct * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }),
          pw.SizedBox(height: 12),
          pw.Text('Recomendaciones del sistema',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (recs.isEmpty)
            pw.Text('Sin recomendaciones por el momento.')
          else
            pw.Bullet(
              text: recs.map((r) => r.replaceAll('**', '')).join('\n'),
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Notas: la dificultad se adapta con un esquema tipo Q-Learning: aciertos → sube nivel, errores → baja nivel, buscando mantener un reto adecuado.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- Vista previa ----------
  Future<void> _preview() async {
    if (_estudianteNombre == null) return;
    final bytes = await _buildPdfBytes(_estudianteNombre!, DateTime.now());
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final acc = _intentos == 0 ? 0.0 : _aciertos / _intentos;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Búsqueda en vivo dentro del TextField
        TextField(
          controller: _buscarCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar estudiante por nombre',
            hintText: 'Escribe para buscar…',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 8),

        // Sugerencias
        if (_query.isNotEmpty &&
            (_estudianteId == null || _buscarCtrl.text != _estudianteNombre))
          FutureBuilder<List<_StudentHit>>(
            future: _searchStudents(_query),
            builder: (context, snapshot) {
              final results = snapshot.data ?? const <_StudentHit>[];
              if (results.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin coincidencias'),
                );
              }
              return Card(
                elevation: 2,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = results[i];
                    return ListTile(
                      leading: const Icon(Icons.school),
                      title: Text(s.nombre),
                      onTap: () => _seleccionarEstudiante(s),
                    );
                  },
                ),
              );
            },
          ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _estudianteId == null || _loading ? null : _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _estudianteId == null || _loading ? null : _preview,
                icon: const Icon(Icons.assessment),
                label: const Text('Vista previa'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        if (_estudianteId == null)
          const Center(child: Text('Selecciona un estudiante para ver sus reportes'))
        else if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Resumen general
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: Text(_estudianteNombre ?? 'Estudiante'),
              subtitle: Text(
                'Intentos: $_intentos • Aciertos: $_aciertos • Errores: $_errores • Tiempo: ${_fmt(_segundos)} • Precisión: ${(acc * 100).toStringAsFixed(0)}%',
              ),
              trailing: FilledButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ====== GRÁFICOS ======
          if (_intentos > 0)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Precisión global', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 220,
                      child: SfCircularChart(
                        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                        series: <DoughnutSeries<_Pie, String>>[
                          DoughnutSeries<_Pie, String>(
                            dataSource: [
                              _Pie('Aciertos', _aciertos),
                              _Pie('Errores', _errores),
                            ],
                            xValueMapper: (_Pie p, _) => p.label,
                            yValueMapper: (_Pie p, _) => p.value,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                            innerRadius: '55%',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          if (_temaData.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Desempeño por tema', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 260,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        legend: const Legend(isVisible: true),
                        series: <CartesianSeries<dynamic, dynamic>>[
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Intentos',
                            dataSource: _toSeries('intentos'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                          ),
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Aciertos',
                            dataSource: _toSeries('aciertos'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                          ),
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Errores',
                            dataSource: _toSeries('errores'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings: const DataLabelSettings(isVisible: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Recomendaciones
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recomendaciones del sistema',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ..._buildRecomendaciones().map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(r)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  // --- helpers de gráficos UI ---
  List<_TemaSerie> _toSeries(String campo) {
    final list = <_TemaSerie>[];
    _temaData.forEach((tema, m) {
      list.add(_TemaSerie(tema, (m[campo] ?? 0).toDouble()));
    });
    return list;
  }
}

class _StudentHit {
  final String id;
  final String nombre;
  _StudentHit({required this.id, required this.nombre});
}

class _TemaSerie {
  final String tema;
  final double valor;
  _TemaSerie(this.tema, this.valor);
}

class _Pie {
  final String label;
  final int value;
  _Pie(this.label, this.value);
}

class _TemaAcc {
  final String tema;
  final int intentos;
  final int aciertos;
  final double precision;
  _TemaAcc({
    required this.tema,
    required this.intentos,
    required this.aciertos,
    required this.precision,
  });
}
