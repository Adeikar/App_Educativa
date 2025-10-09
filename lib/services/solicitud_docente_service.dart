import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class SolicitudDocenteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Notifica a todos los administradores cuando hay una nueva solicitud
  Future<void> notificarNuevaSolicitud({
    required String solicitudId,
    required String nombreDocente,
    required String correo,
    required String institucion,
  }) async {
    try {
      // 1. Buscar todos los usuarios con rol 'admin' o 'director'
      final admins = await _db
          .collection('usuarios')
          .where('rol', whereIn: ['admin', 'director'])
          .get();

      if (admins.docs.isEmpty) {
        print('⚠️ No hay administradores para notificar');
        return;
      }

      // 2. Crear notificación para cada admin
      final timestamp = FieldValue.serverTimestamp();
      final adminIds = <String>[];

      for (final admin in admins.docs) {
        final adminId = admin.id;
        
        // Crear documento de notificación en Firestore
        await _db.collection('notificaciones').add({
          'destinatarioId': adminId,
          'tipo': 'solicitud_docente',
          'solicitudId': solicitudId,
          'nombreDocente': nombreDocente,
          'correo': correo,
          'institucion': institucion,
          'leida': false,
          'fecha': timestamp,
          'creadoEn': timestamp,
        });

        adminIds.add(adminId);
      }

      // 3. Enviar notificación push (FCM)
      if (adminIds.isNotEmpty) {
        final fcmService = FCMService();
        await fcmService.sendNotificationToUsers(
          userIds: adminIds,
          title: '📋 Nueva solicitud de docente',
          body: '$nombreDocente quiere unirse como docente',
          data: {
            'tipo': 'solicitud_docente',
            'solicitudId': solicitudId,
            'accion': 'abrir_solicitudes',
          },
        );
      }

      print('✅ Notificaciones de solicitud enviadas a ${adminIds.length} administradores');
    } catch (e) {
      print('⚠️ Error al notificar solicitud: $e');
    }
  }

  /// Notifica al docente cuando su solicitud es aprobada
  Future<void> notificarSolicitudAprobada({
    required String docenteId,
    required String nombreDocente,
  }) async {
    try {
      final timestamp = FieldValue.serverTimestamp();

      // Crear notificación de aprobación
      await _db.collection('notificaciones').add({
        'destinatarioId': docenteId,
        'tipo': 'solicitud_aprobada',
        'nombreDocente': nombreDocente,
        'leida': false,
        'fecha': timestamp,
        'creadoEn': timestamp,
      });

      // Enviar push
      final fcmService = FCMService();
      await fcmService.sendNotificationToUsers(
        userIds: [docenteId],
        title: '✅ Solicitud aprobada',
        body: '¡Felicitaciones! Ahora eres docente en la plataforma',
        data: {
          'tipo': 'solicitud_aprobada',
          'accion': 'abrir_home',
        },
      );

      print('✅ Notificación de aprobación enviada');
    } catch (e) {
      print('⚠️ Error al notificar aprobación: $e');
    }
  }

  /// Notifica al docente cuando su solicitud es rechazada
  Future<void> notificarSolicitudRechazada({
    required String docenteId,
    required String nombreDocente,
    String? motivo,
  }) async {
    try {
      final timestamp = FieldValue.serverTimestamp();

      await _db.collection('notificaciones').add({
        'destinatarioId': docenteId,
        'tipo': 'solicitud_rechazada',
        'nombreDocente': nombreDocente,
        'motivo': motivo,
        'leida': false,
        'fecha': timestamp,
        'creadoEn': timestamp,
      });

      final fcmService = FCMService();
      await fcmService.sendNotificationToUsers(
        userIds: [docenteId],
        title: '❌ Solicitud rechazada',
        body: motivo ?? 'Tu solicitud no pudo ser procesada',
        data: {
          'tipo': 'solicitud_rechazada',
          'accion': 'cerrar',
        },
      );

      print('✅ Notificación de rechazo enviada');
    } catch (e) {
      print('⚠️ Error al notificar rechazo: $e');
    }
  }
}