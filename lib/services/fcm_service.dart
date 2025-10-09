// lib/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Manejador de notificaciones en segundo plano (DEBE estar fuera de la clase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Notificación recibida en segundo plano: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Inicializa FCM y notificaciones locales
  Future<void> initialize() async {
    // 1. Solicitar permisos
    await _requestPermissions();

    // 2. Configurar notificaciones locales
    await _setupLocalNotifications();

    // 3. Obtener token FCM
    final token = await _fcm.getToken();
    if (token != null) {
      print('📱 FCM Token: $token');
      await _saveTokenToFirestore(token);
    }

    // 4. Escuchar cambios de token
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 5. Configurar manejadores de notificaciones
    _setupForegroundHandler();
    _setupBackgroundHandler();
    _setupNotificationTapHandler();
  }

  // Solicita permisos de notificaciones
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permisos de notificación concedidos');
    } else {
      print('⚠️ Permisos de notificación denegados');
    }
  }

  // Configura notificaciones locales (Android)
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

    print('💾 Token FCM guardado en Firestore');
  }

  // Maneja notificaciones cuando la app está en primer plano
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Notificación recibida (app abierta): ${message.notification?.title}');

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        // NOTA: Aquí el payload es simple, lo ideal sería pasar el 'tipo' para que el onSelect
        // de local_notifications lo maneje correctamente también.
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

  // Configura manejador de segundo plano
  void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Maneja cuando el usuario toca la notificación
  void _setupNotificationTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Usuario tocó la notificación: ${message.notification?.title}');
      
      final data = message.data;
      final tipo = data['tipo'];
      final accion = data['accion'];

      // --- Lógica de Manejo de Tap CORREGIDA ---
      if (tipo == 'solicitud_aprobada' && accion == 'abrir_home') {
        // Docente aprobado: Navegar a la pantalla principal de Docente/Tutor
        // Esto es lo que faltaba para diferenciar la notificación de aprobación
        // TODO: Implementar la navegación real a la pantalla DocenteTutorScreen (ej: '/docente_tutor')
        print('✅ Navegar a HOME DOCENTE/TUTOR (Solicitud Aprobada)');

      } else if (tipo == 'sesion_completada') {
        // Docente/Tutor recibe informe de estudiante
        final estudianteId = data['estudianteId'];
        // TODO: Navegar a pantalla de progreso del estudiante
        print('📊 Abrir progreso de estudiante: $estudianteId');

      } else if (tipo == 'solicitud_docente' && accion == 'abrir_solicitudes') {
        // Administrador: Recibe nueva solicitud pendiente
        // TODO: Navegar a la pestaña de solicitudes
        print('📋 Abrir pestaña de solicitudes (Admin)');
      }
      // Fin de la lógica corregida
    });
  }

  // Envía notificación push a usuarios específicos
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
        print('⚠️ No se encontraron tokens FCM');
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

      print('✅ Notificación agregada a cola de envío');
    } catch (e) {
      print('⚠️ Error enviando notificación: $e');
    }
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

  // ⬇️ AGREGA este método dentro de la clase FCMService (no quites nada de lo tuyo)
  /// Inicialización segura para Web: no registra BG handler ni notifs locales.
  /// No tumba la app si el Service Worker no está.
  Future<void> initializeWebSafe() async {
    if (!kIsWeb) return; // Esto solo corre en Web

    try {
      // 1) Pide permisos en Web (si el browser los soporta)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      // print('Web notif perm: ${settings.authorizationStatus}');

      // 2) Intenta obtener token (requiere SW en web/firebase-messaging-sw.js)
      final token = await _fcm.getToken();
      if (token != null) {
        // Guarda token como en móvil (si hay usuario)
        await _saveTokenToFirestore(token);
        // 3) Escucha refresh de token (opcional, pero útil)
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
      }
    } catch (e) {

    }
  }
}
