// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Crea notificación cuando estudiante termina sesión
  Future<void> notificarSesionCompletada({
    required String estudianteId,
    required String estudianteNombre,
    required String tema,
    required int aciertos,
    required int errores,
    required int duracion,
  }) async {
    try {
      // 1. Buscar docentes/tutores vinculados a este estudiante
      final vinculaciones = await _db
          .collection('vinculaciones')
          .where('estudianteId', isEqualTo: estudianteId)
          .where('estado', isEqualTo: 'activa')
          .get();

      if (vinculaciones.docs.isEmpty) {
        print('ℹ️ No hay docentes/tutores vinculados');
        return;
      }

      // 2. Crear notificación para cada docente/tutor vinculado
      final timestamp = FieldValue.serverTimestamp();
      final total = aciertos + errores;
      final porcentaje = total > 0 ? ((aciertos / total) * 100).round() : 0;

      final destinatarios = <String>[];

      for (final vinc in vinculaciones.docs) {
        final docenteId = vinc.data()['docenteId'] as String?;
        final tutorId = vinc.data()['tutorId'] as String?;

        // Notificar al docente
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

        // Notificar al tutor
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

      // 3. NUEVO: Enviar notificación push (FCM)
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

      print('✅ Notificaciones enviadas correctamente');
    } catch (e) {
      print('⚠️ Error al enviar notificaciones: $e');
    }
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

  // Obtiene notificaciones del docente/tutor actual
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

  // Marca notificación como leída
  Future<void> marcarComoLeida(String notificacionId) async {
    await _db.collection('notificaciones').doc(notificacionId).update({
      'leida': true,
      'leidaEn': FieldValue.serverTimestamp(),
    });
  }

  // Marca todas como leídas
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

  // Elimina notificación
  Future<void> eliminarNotificacion(String notificacionId) async {
    await _db.collection('notificaciones').doc(notificacionId).delete();
  }
}