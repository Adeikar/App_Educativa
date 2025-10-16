import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {

}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {

  await _requestPermissions();
  await _setupLocalNotifications();

    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    _setupForegroundHandler();
    _setupBackgroundHandler();
    _setupNotificationTapHandler();
  }


  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    } 
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(settings);

    // Crear canal de notificaciones de alta prioridad
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notificaciones importantes',
      description: 'Canal para notificaciones de estudiantes',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Guarda el token FCM en Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'fcmToken': token,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  // primer plano
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notificaciones importantes',
              channelDescription: 'Canal para notificaciones de estudiantes',
              importance: Importance.high,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['tipo'], // Usar 'tipo' en el payload de local_notifications
        );
      }
    });
  }

  void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Maneja cuando el usuario toca la notificación
  void _setupNotificationTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      
      final data = message.data;
      final tipo = data['tipo'];
      final accion = data['accion'];

      if (tipo == 'solicitud_aprobada' && accion == 'abrir_home') {
      } else if (tipo == 'sesion_completada') {
        // Docente/Tutor recibe informe de estudiante
        final estudianteId = data['estudianteId'];
        print('📊 Abrir progreso de estudiante: $estudianteId');

      } else if (tipo == 'solicitud_docente' && accion == 'abrir_solicitudes') {
      }
    });
  }

  // Envía 
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Obtener tokens FCM de los usuarios
      final tokens = await _getTokensForUsers(userIds);
      
      if (tokens.isEmpty) {
        return;
      }

      // Crear documento de notificación para envío
      await FirebaseFirestore.instance.collection('fcm_queue').add({
        'tokens': tokens,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'creadoEn': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
      });
    } catch (__) {}
  }

  // Obtiene tokens FCM de usuarios
  Future<List<String>> _getTokensForUsers(List<String> userIds) async {
    final tokens = <String>[];

    for (final uid in userIds) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token != null) {
        tokens.add(token);
      }
    }

    return tokens;
  }

  Future<void> initializeWebSafe() async {
    if (!kIsWeb) return; // Esto solo corre en Web

    try {
      // 1) Pide permisos en Web (si el browser los soporta)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _fcm.getToken();
      if (token != null) {
        // Guarda token como en móvil
        await _saveTokenToFirestore(token);
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
      }
    } catch (__) {}
  }
}
