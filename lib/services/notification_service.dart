import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> notificarSesionCompletada({
    required String estudianteId,
    required String estudianteNombre,
    required String tema,
    required int aciertos,
    required int errores,
    required int duracion,
  }) async {
    try {
      final vinculaciones = await _db
          .collection('vinculaciones')
          .where('estudianteId', isEqualTo: estudianteId)
          .where('estado', isEqualTo: 'activa')
          .get();

      if (vinculaciones.docs.isEmpty) {
        return;
      }

      final timestamp = FieldValue.serverTimestamp();
      final total = aciertos + errores;
      final porcentaje = total > 0 ? ((aciertos / total) * 100).round() : 0;

      final destinatarios = <String>[];

      for (final vinc in vinculaciones.docs) {
        final docenteId = vinc.data()['docenteId'] as String?;
        final tutorId = vinc.data()['tutorId'] as String?;

        if (docenteId != null) {
          await _crearNotificacion(
            destinatarioId: docenteId,
            estudianteId: estudianteId,
            estudianteNombre: estudianteNombre,
            tema: tema,
            aciertos: aciertos,
            errores: errores,
            total: total,
            porcentaje: porcentaje,
            duracion: duracion,
            timestamp: timestamp,
          );
          destinatarios.add(docenteId);
        }

        if (tutorId != null) {
          await _crearNotificacion(
            destinatarioId: tutorId,
            estudianteId: estudianteId,
            estudianteNombre: estudianteNombre,
            tema: tema,
            aciertos: aciertos,
            errores: errores,
            total: total,
            porcentaje: porcentaje,
            duracion: duracion,
            timestamp: timestamp,
          );
          destinatarios.add(tutorId);
        }
      }
      // Enviar notificación push
      if (destinatarios.isNotEmpty) {
        final fcmService = FCMService();
        await fcmService.sendNotificationToUsers(
          userIds: destinatarios,
          title: '$estudianteNombre completó práctica',
          body: '$tema: $porcentaje% de aciertos ($aciertos/$total)',
          data: {
            'tipo': 'sesion_completada',
            'estudianteId': estudianteId,
            'tema': tema,
          },
        );
      }
    } catch (__) {}
  }

  // Crea documento de notificación en Firestore
  Future<void> _crearNotificacion({
    required String destinatarioId,
    required String estudianteId,
    required String estudianteNombre,
    required String tema,
    required int aciertos,
    required int errores,
    required int total,
    required int porcentaje,
    required int duracion,
    required FieldValue timestamp,
  }) async {
    await _db.collection('notificaciones').add({
      'destinatarioId': destinatarioId,
      'estudianteId': estudianteId,
      'estudianteNombre': estudianteNombre,
      'tipo': 'sesion_completada',
      'tema': tema,
      'aciertos': aciertos,
      'errores': errores,
      'total': total,
      'porcentaje': porcentaje,
      'duracion': duracion,
      'leida': false,
      'fecha': timestamp,
      'creadoEn': timestamp,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> obtenerNotificaciones() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _db
        .collection('notificaciones')
        .where('destinatarioId', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> marcarComoLeida(String notificacionId) async {
    await _db.collection('notificaciones').doc(notificacionId).update({
      'leida': true,
      'leidaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marcarTodasComoLeidas() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = _db.batch();
    final notifs = await _db
        .collection('notificaciones')
        .where('destinatarioId', isEqualTo: uid)
        .where('leida', isEqualTo: false)
        .get();

    for (final doc in notifs.docs) {
      batch.update(doc.reference, {
        'leida': true,
        'leidaEn': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> eliminarNotificacion(String notificacionId) async {
    await _db.collection('notificaciones').doc(notificacionId).delete();
  }
}