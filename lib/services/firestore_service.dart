// FirestoreService: guarda/actualiza usuarios y genera código estudiante.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final Uuid _uuid;

  // Inicializa Firestore y Uuid, permitiendo inyección de dependencias.
  FirestoreService({
    FirebaseFirestore? db,
    Uuid? uuid,
  }) : _db = db ?? FirebaseFirestore.instance,
       _uuid = uuid ?? const Uuid();

  // Guarda el documento de usuario en Firestore, aplicando datos específicos según el rol.
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
      // Genera código de vinculación único y añade campos de estudiante.
      final codigo = await _generarCodigoUnico();
      data['nivelEducativo'] = (nivelEducativo ?? '').trim();
      data['discapacidad'] = (discapacidad ?? '').trim();
      data['estudiante'] = {'codigoVinculacion': codigo};
    } else if (rol == 'docente' || rol == 'docente_solicitado') {
      // Añade campos específicos de docente.
      data['docente'] = {
        'pais': (pais ?? '').trim(),
        'ciudad': (ciudad ?? '').trim(),
        'area': (area ?? '').trim(),
        'institucion': (institucion ?? '').trim(),
      };
    } else if (rol == 'tutor') {
      // Añade campo específico de tutor.
      data['tutor'] = {'relacionFamiliar': (relacionFamiliar ?? '').trim()};
    }

    await _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  // Obtiene el documento de usuario por su UID.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUsuario(String uid) {
    return _db.collection('usuarios').doc(uid).get();
  }

  // Actualiza campos parciales del usuario usando merge.
  Future<void> updateUsuario(String uid, Map<String, dynamic> data) {
    data['actualizadoEn'] = FieldValue.serverTimestamp();
    return _db.collection('usuarios').doc(uid).set(data, SetOptions(merge: true));
  }

  // Busca y retorna el estudiante por su código de vinculación.
  Future<DocumentSnapshot<Map<String, dynamic>>?> buscarPorCodigoVinculacion(String code) async {
    final snap = await _db
        .collection('usuarios')
        .where('estudiante.codigoVinculacion', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  // Verifica la existencia de un código de vinculación de estudiante.
  Future<bool> existeCodigo(String code) async {
    final snap = await _db
        .collection('usuarios')
        .where('estudiante.codigoVinculacion', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // Genera un código único alfanumérico de 6 caracteres
  Future<String> _generarCodigoUnico() async {
    const int maxRetries = 10;
    for (int i = 0; i < maxRetries; i++) {
      final code = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
      if (!(await existeCodigo(code))) return code;
    }
    throw Exception('No se pudo generar un código único tras $maxRetries intentos');
  }
}