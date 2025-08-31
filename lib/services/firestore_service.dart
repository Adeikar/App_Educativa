import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Future<void> upsertUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    return doc.data();
  }

  Future<void> createTema(String nombre) =>
      _db.collection('temas').doc(nombre).set({'nombre': nombre});

  Future<List<Map<String, dynamic>>> getTemas() async {
    final snap = await _db.collection('temas').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // Sesiones (resumen)
  Future<void> createSesion(String sesionId, Map<String, dynamic> data) async {
    await _db.collection('sesiones').doc(sesionId).set(data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sesionesDe(String estudianteId) {
    return _db.collection('sesiones')
      .where('estudianteId', isEqualTo: estudianteId)
      .orderBy('fecha', descending: true)
      .snapshots();
  }
}
