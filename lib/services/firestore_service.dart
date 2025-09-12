// FirestoreService: guarda/actualiza usuarios y genera código estudiante.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final Uuid _uuid;

  FirestoreService({
    FirebaseFirestore? db,
    Uuid? uuid,
  })  : _db = db ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  // Guarda usuario (soporta 'docente' y 'docente_solicitado').
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
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'uid': uid,
      'nombre': nombre.trim(),
      'correo': correo.trim().toLowerCase(),
      'rol': rol.trim(), // puede ser 'docente_solicitado'
      'estado': 'activo',
      'creadoEn': now,
      'actualizadoEn': now,
      'ultimoAcceso': now,
    };

    if (rol == 'estudiante') {
      final codigo = await _generarCodigoUnico();
      data['nivelEducativo'] = (nivelEducativo ?? '').trim();
      data['discapacidad'] = (discapacidad ?? '').trim();
      data['estudiante'] = {'codigoVinculacion': codigo};
    } else if (rol == 'docente' || rol == 'docente_solicitado') {
      data['docente'] = {
        'pais': (pais ?? '').trim(),
        'ciudad': (ciudad ?? '').trim(),
        'area': (area ?? '').trim(),
        'institucion': (institucion ?? '').trim(),
      };
    } else if (rol == 'tutor') {
      data['tutor'] = {'relacionFamiliar': (relacionFamiliar ?? '').trim()};
    }

    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  // Obtiene usuario por uid.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUsuario(String uid) {
    return _db.collection('usuarios').doc(uid).get();
  }

  // Actualiza campos parciales del usuario.
  Future<void> updateUsuario(String uid, Map<String, dynamic> data) {
    data['actualizadoEn'] = FieldValue.serverTimestamp();
    return _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  // Busca estudiante por código de vinculación.
  Future<DocumentSnapshot<Map<String, dynamic>>?> buscarPorCodigoVinculacion(String code) async {
    final snap = await _db
        .collection('usuarios')
        .where('estudiante.codigoVinculacion', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  // Verifica existencia de código.
  Future<bool> existeCodigo(String code) async {
    final snap = await _db
        .collection('usuarios')
        .where('estudiante.codigoVinculacion', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // Genera código único de 6 chars.
  Future<String> _generarCodigoUnico() async {
    const int maxRetries = 10;
    for (int i = 0; i < maxRetries; i++) {
      final code = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
      if (!(await existeCodigo(code))) return code;
    }
    throw Exception('No se pudo generar un código único tras $maxRetries intentos');
  }
}
