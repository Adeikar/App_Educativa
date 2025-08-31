import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Future<void> guardarUsuario({
    required String uid,
    required String nombre,
    required String correo,
    required String rol,
    String? nivelEducativo,
    String? discapacidad,
    String? relacionFamiliar,
    String? pais,
    String? ciudad,
    String? area,
    String? institucion,
  }) async {
    final Map<String, dynamic> data = {
      'uid': uid,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'estado': 'activo',
      'ultimoAcceso': FieldValue.serverTimestamp(), // fecha de creación/primer acceso
    };

    if (rol == 'estudiante') {
      final codigo = await _generarCodigoUnico();
      data['nivelEducativo'] = (nivelEducativo ?? '').trim();
      data['discapacidad']   = (discapacidad ?? '').trim();
      data['estudiante'] = {'codigoVinculacion': codigo};
    } else if (rol == 'tutor') {
      data['tutor'] = {
        'relacionFamiliar': (relacionFamiliar ?? '').trim(),
      };
    } else if (rol == 'docente') {
      data['docente'] = {
        'pais'       : (pais ?? '').trim(),
        'ciudad'     : (ciudad ?? '').trim(),
        'area'       : (area ?? '').trim(),
        'institucion': (institucion ?? '').trim(),
      };
    }

    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<String> _generarCodigoUnico() async {
    // 6 caracteres alfanuméricos, no repetidos en usuarios.estudiante.codigoVinculacion
    while (true) {
      final code = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
      final snap = await _db
          .collection('usuarios')
          .where('estudiante.codigoVinculacion', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
  }
}
