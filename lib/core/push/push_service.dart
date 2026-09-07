import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/env_config.dart';
import '../di/injection_container.dart';
import '../network/dio_client.dart';

/// Notificaciones push del instalador (FCM, proyecto Firebase ohmsafe-instaladores).
///
/// Flujo: al asignarle una instalación en Odoo, un automation llama al backend,
/// que envía el push a los tokens FCM del instalador (guardados en Odoo). Aquí
/// obtenemos el token del dispositivo, lo registramos tras el login, y al tocar
/// la notificación abrimos la lista de instalaciones.
///
/// Solo aplica en Android/iOS. En macOS/escritorio (harness de dev) es no-op:
/// no hay Firebase configurado y `soportado` es false.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Solo hay config Firebase (google-services.json / plist) para móvil.
  static bool get soportado => Platform.isAndroid || Platform.isIOS;

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  /// Callback que la app fija para navegar al tocar la notificación.
  void Function(String taskId)? onOpenInstalacion;

  /// Permisos + listeners. Llamar una vez al arrancar (tras Firebase.initializeApp).
  Future<void> setupListeners() async {
    if (!soportado) return;
    try {
      await _fm.requestPermission();
      _fm.onTokenRefresh.listen(_registrar);
      FirebaseMessaging.onMessageOpenedApp.listen(_abrir);
      // App abierta desde una notificación (estado terminado).
      final inicial = await _fm.getInitialMessage();
      if (inicial != null) _abrir(inicial);
    } catch (_) {
      // Best-effort: nunca romper el arranque por push.
    }
  }

  /// Registra el token FCM del instalador en el backend. Llamar tras el login
  /// (el endpoint requiere sesión: el token del dispositivo se liga al partner).
  Future<void> registrarToken() async {
    if (!soportado) return;
    try {
      final token = await _fm.getToken();
      if (token != null) await _registrar(token);
    } catch (_) {}
  }

  Future<void> _registrar(String token) async {
    if (sl.get<EnvConfig>().useMock) return; // sin backend en modo mock
    try {
      await sl.get<DioClient>().post('/instalador/push/registrar', body: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Best-effort: si falla el registro, el push simplemente no llega aún.
    }
  }

  void _abrir(RemoteMessage m) {
    if (m.data['tipo'] == 'asignacion_instalacion') {
      onOpenInstalacion?.call((m.data['taskId'] ?? '').toString());
    }
  }
}
