// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tema.dart';

class TemaService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('temas');

  Future<void> crearTema({required String nombre, required String concepto}) async {
    try {
      // usamos doc(nombre) para que sea estable (suma, resta, etc.)
      await _col.doc(nombre).set({
        'nombre': nombre,
        'concepto': concepto,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error crearTema: $e');
      rethrow;
    }
  }

  Future<void> actualizarTema(String idDoc, {required String nombre, required String concepto}) async {
    try {
      await _col.doc(idDoc).update({
        'nombre': nombre,
        'concepto': concepto,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizarTema: $e');
      rethrow;
    }
  }

  Future<void> eliminarTema(String idDoc) async {
    try {
      await _col.doc(idDoc).delete();
    } catch (e) {
      print('Error eliminarTema: $e');
      rethrow;
    }
  }

  Stream<List<Tema>> streamTemas() {
    return _col.orderBy('nombre').snapshots().map(
          (q) => q.docs.map((d) => Tema.fromDoc(d)).toList(),
        );
  }
}
