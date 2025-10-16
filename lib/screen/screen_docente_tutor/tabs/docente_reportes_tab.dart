// Reportes por estudiante con PDF PROFESIONAL
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// -------------------- CLASES AUXILIARES (Dejar aquí para compilar) --------------------
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
// -------------------- FIN CLASES AUXILIARES --------------------

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
  final _buscarCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  String? _estudianteId;
  String? _estudianteNombre;

  bool _loading = false;

  final GlobalKey<SfCircularChartState> _pieChartKey = GlobalKey();
  final GlobalKey<SfCartesianChartState> _barChartKey = GlobalKey();

  int _intentos = 0;
  int _aciertos = 0;
  int _errores = 0;
  int _segundos = 0;

  Map<String, Map<String, int>> _temaData = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialStudentId != null) {
      _estudianteId = widget.initialStudentId;
      _estudianteNombre = widget.initialStudentName ?? 'Estudiante';
      _buscarCtrl.text = _estudianteNombre!;
      _cargar();
    }
    _buscarCtrl.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(covariant DocenteReportesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedId = widget.initialStudentId != oldWidget.initialStudentId;
    final changedName =
        widget.initialStudentName != oldWidget.initialStudentName;

    if (changedId || changedName) {
      if (widget.initialStudentId == null) {
        setState(() {
          _estudianteId = null;
          _estudianteNombre = null;
          _buscarCtrl.clear();
          _query = '';
          _resetAcumulados();
        });
      } else {
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
    } catch (e) {
      debugPrint('Error en la búsqueda: $e');
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
    if (widget.onClearSelection != null) {
      widget.onClearSelection!();
    }
  }

  void _resetAcumulados() {
    _intentos = 0;
    _aciertos = 0;
    _errores = 0;
    _segundos = 0;
    _temaData = {};
  }

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

  String _fmt(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    if (m == 0) return '${ss}s';
    return '${m}m ${ss}s';
  }

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

  Future<Uint8List?> _captureChart(GlobalKey chartKey) async {
    try {
      final dynamic chartState = chartKey.currentState;
      if (chartState != null) {
        final ui.Image image = await chartState.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Error al capturar el gráfico: $e');
      return null;
    }
    return null;
  }

  Future<void> _downloadPdf() async {
    if (_estudianteNombre == null) return;

    final pieChartBytes = await _captureChart(_pieChartKey);
    final barChartBytes = await _captureChart(_barChartKey);

    final bytes = await _buildPdfBytes(
      _estudianteNombre!,
      DateTime.now(),
      pieChartBytes: pieChartBytes,
      barChartBytes: barChartBytes,
    );
    await Printing.sharePdf(
        bytes: bytes, filename: 'reporte_${_estudianteNombre!}.pdf');
  }

  Future<Uint8List> _buildPdfBytes(String nombre, DateTime fecha, {
    Uint8List? pieChartBytes,
    Uint8List? barChartBytes,
  }) async {
    final doc = pw.Document();
    final acc = _intentos == 0 ? 0.0 : _aciertos / _intentos;
    final recs =
        _buildRecomendaciones().map((r) => r.replaceAll('**', '')).toList();

    const primary = PdfColor.fromInt(0xFF1976D2);
    const success = PdfColor.fromInt(0xFF388E3C);
    const error = PdfColor.fromInt(0xFFD32F2F);
    const warning = PdfColor.fromInt(0xFFF57C00);
    const gray = PdfColor.fromInt(0xFF616161);
    const lightGray = PdfColor.fromInt(0xFFF5F5F5);

    pw.Widget _buildStatColumn(String label, String value, PdfColor color) {
      return pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: const PdfColor.fromInt(0xFF616161),
            ),
          ),
        ],
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // 1. HEADER (TÍTULO Y RESUMEN DE PRECISIÓN)
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: primary,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE DE PROGRESO ACADÉMICO',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Estudiante: $nombre',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                    ),
                    pw.Text(
                      'Fecha: ${fecha.toLocal().toString().substring(0, 16)}',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '${(acc * 100).toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: acc >= 0.7 ? success : warning,
                        ),
                      ),
                      pw.Text(
                        'Precisión',
                        style: pw.TextStyle(fontSize: 9, color: gray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // 2. RESUMEN ESTADÍSTICO
          pw.Text(
            'RESUMEN ESTADÍSTICO',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: lightGray, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Intentos', '$_intentos', primary),
                _buildStatColumn('Aciertos', '$_aciertos', success),
                _buildStatColumn('Errores', '$_errores', error),
                _buildStatColumn('Tiempo', _fmt(_segundos), warning),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // 3. ANÁLISIS GRÁFICO (Aseguramos que estén aquí, en la primera página)
          if (pieChartBytes != null || barChartBytes != null) ...[
            pw.Text(
              'ANÁLISIS GRÁFICO',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          if (pieChartBytes != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: lightGray, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Distribución Global (Aciertos/Errores)',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Image(pw.MemoryImage(pieChartBytes), height: 180),
                  ),
                ],
              ),
            ),

          if (barChartBytes != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: lightGray, width: 1),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Desempeño por Tema',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Image(pw.MemoryImage(barChartBytes), height: 180),
                  ),
                ],
              ),
            ),
            
          // Usar PageBreak si el contenido posterior debe ir forzosamente en otra página, 
          // pero como los gráficos son más pequeños ahora, dejaremos que el flujo normal continúe
          // para optimizar el espacio, o podrías agregar un pw.NewPage() si lo requieres.

          pw.SizedBox(height: 20),

          // 4. DETALLE POR TEMA (Tabla)
          if (_temaData.isNotEmpty) ...[
            pw.Text(
              'DETALLE POR TEMA',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
              border: pw.TableBorder.all(color: lightGray),
              headers: ['Tema', 'Intentos', 'Aciertos', 'Errores', 'Precisión'],
              data: _temaData.entries.map((e) {
                final it = e.value['intentos'] ?? 0;
                final ac = e.value['aciertos'] ?? 0;
                final er = e.value['errores'] ?? 0;
                final pct = it == 0 ? 0.0 : ac / it;
                return [
                  e.key,
                  '$it',
                  '$ac',
                  '$er',
                  '${(pct * 100).toStringAsFixed(1)}%',
                ];
              }).toList(),
            ),
          ],

          pw.SizedBox(height: 20),

          // 5. RECOMENDACIONES PEDAGÓGICAS
          pw.Text(
            'RECOMENDACIONES PEDAGÓGICAS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: lightGray,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: recs.isEmpty
                  ? [
                      pw.Text('Sin recomendaciones específicas en este momento.',
                          style: const pw.TextStyle(fontSize: 10))
                    ]
                  : recs
                      .map((r) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const pw.EdgeInsets.only(top: 3, right: 8),
                                  decoration: const pw.BoxDecoration(
                                    color: primary,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(r,
                                      style: const pw.TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
            ),
          ),

          // *** SE ELIMINÓ la "NOTA METODOLÓGICA" y el texto de abajo, como solicitaste. ***
          
          pw.SizedBox(height: 15),
          pw.Divider(color: lightGray),
          pw.SizedBox(height: 5),
          pw.Text(
            'Reporte generado automáticamente', // Texto simple de cierre
            style: pw.TextStyle(fontSize: 8, color: gray),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildStatColumn(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: const PdfColor.fromInt(0xFF616161),
          ),
        ),
      ],
    );
  }

  Future<void> _preview() async {
    if (_estudianteNombre == null) return;

    final pieChartBytes = await _captureChart(_pieChartKey);
    final barChartBytes = await _captureChart(_barChartKey);

    final bytes = await _buildPdfBytes(
      _estudianteNombre!,
      DateTime.now(),
      pieChartBytes: pieChartBytes,
      barChartBytes: barChartBytes,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final acc = _intentos == 0 ? 0.0 : _aciertos / _intentos;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _buscarCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar estudiante por nombre',
            hintText: 'Escribe para buscar…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _estudianteId != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _estudianteId = null;
                        _estudianteNombre = null;
                        _buscarCtrl.clear();
                        _query = '';
                        _resetAcumulados();
                      });
                      if (widget.onClearSelection != null) {
                        widget.onClearSelection!();
                      }
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 8),

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
                if (_query.length > 2) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin coincidencias'),
                  );
                }
                return const SizedBox.shrink();
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
          const Center(
              child: Text('Selecciona un estudiante para ver sus reportes'))
        else if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
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

          if (_intentos > 0)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Precisión global',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 220,
                      child: SfCircularChart(
                        key: _pieChartKey,
                        legend: const Legend(
                            isVisible: true, position: LegendPosition.bottom),
                        series: <DoughnutSeries<_Pie, String>>[
                          DoughnutSeries<_Pie, String>(
                            dataSource: [
                              _Pie('Aciertos', _aciertos),
                              _Pie('Errores', _errores),
                            ],
                            xValueMapper: (_Pie p, _) => p.label,
                            yValueMapper: (_Pie p, _) => p.value,
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
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
                    const Text('Desempeño por tema',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 260,
                      child: SfCartesianChart(
                        key: _barChartKey,
                        primaryXAxis: const CategoryAxis(),
                        legend: const Legend(isVisible: true),
                        series: <CartesianSeries<dynamic, dynamic>>[
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Intentos',
                            dataSource: _toSeries('intentos'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
                          ),
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Aciertos',
                            dataSource: _toSeries('aciertos'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
                          ),
                          ColumnSeries<_TemaSerie, String>(
                            name: 'Errores',
                            dataSource: _toSeries('errores'),
                            xValueMapper: (_TemaSerie s, _) => s.tema,
                            yValueMapper: (_TemaSerie s, _) => s.valor,
                            dataLabelSettings:
                                const DataLabelSettings(isVisible: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

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
                            Expanded(
                                child: Text(r.replaceAll(
                                    '**', ''))), // Quitar formato
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

  List<_TemaSerie> _toSeries(String campo) {
    final list = <_TemaSerie>[];
    _temaData.forEach((tema, m) {
      list.add(_TemaSerie(tema, (m[campo] ?? 0).toDouble()));
    });
    return list;
  }
}