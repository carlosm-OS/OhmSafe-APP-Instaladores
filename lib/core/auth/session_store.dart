import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lo que la app guarda del inicio de sesión, en Keychain (iOS) / Keystore
/// (Android). El access token NUNCA se guarda: vive en memoria y dura 15 min.
///
/// Nivel A de biometría: el refresh está protegido por el sistema tras el
/// primer desbloqueo del teléfono y la app pide Face ID antes de usarlo. El
/// nivel B (el SO no entrega el secreto sin biometría) es la siguiente versión.
abstract class SessionStore {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);

  /// Identificador estable del dispositivo: se genera una vez al instalar y
  /// viaja en login y refresh (el refresh sólo vale desde este dispositivo).
  Future<String> deviceId();

  /// Borra la sesión pero conserva `deviceId` y las preferencias de biometría.
  Future<void> limpiarSesion();
}

class ClavesSesion {
  ClavesSesion._();
  static const refreshToken = 'sesion.refresh_token';
  static const deviceId = 'sesion.device_id';
  static const instaladorId = 'sesion.instalador_id';
  static const nombre = 'sesion.nombre';
  static const numeroInstalador = 'sesion.numero_instalador';
  static const rol = 'sesion.rol';
  static const email = 'sesion.email';
  static const biometriaActivada = 'sesion.biometria_activada';
  static const invitacionBiometriaMostrada = 'sesion.invitacion_biometria_mostrada';
  static const ultimoActivoMs = 'sesion.ultimo_activo_ms';

  /// Último correo que entró en este teléfono. NO es de sesión: sobrevive al
  /// cierre o a la revocación para que el login abra directo en la contraseña.
  static const ultimoCorreo = 'dispositivo.ultimo_correo';

  static const deSesion = [refreshToken, instaladorId, nombre, numeroInstalador, rol, email, ultimoActivoMs];
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Accesible tras el primer desbloqueo y sólo en este dispositivo
              // (no viaja en respaldos de iCloud/Google).
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer(String clave) async {
    try {
      return await _storage.read(key: clave);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> escribir(String clave, String valor) async {
    try {
      await _storage.write(key: clave, value: valor);
    } catch (_) {}
  }

  @override
  Future<void> borrar(String clave) async {
    try {
      await _storage.delete(key: clave);
    } catch (_) {}
  }

  @override
  Future<String> deviceId() async {
    final actual = await leer(ClavesSesion.deviceId);
    if (actual != null && actual.length >= 8) return actual;
    final nuevo = generarDeviceId();
    await escribir(ClavesSesion.deviceId, nuevo);
    return nuevo;
  }

  @override
  Future<void> limpiarSesion() async {
    for (final k in ClavesSesion.deSesion) {
      await borrar(k);
    }
  }
}

/// 32 hex aleatorios con generador criptográfico; cumple el patrón que exige el backend.
String generarDeviceId([Random? rng]) {
  final r = rng ?? Random.secure();
  const hex = '0123456789abcdef';
  return List.generate(32, (_) => hex[r.nextInt(16)]).join();
}

/// Almacén en memoria para pruebas y para escritorio (sin Keychain).
class MemorySessionStore implements SessionStore {
  final Map<String, String> _m = {};

  @override
  Future<String?> leer(String clave) async => _m[clave];
  @override
  Future<void> escribir(String clave, String valor) async => _m[clave] = valor;
  @override
  Future<void> borrar(String clave) async => _m.remove(clave);
  @override
  Future<String> deviceId() async => _m.putIfAbsent(ClavesSesion.deviceId, generarDeviceId);
  @override
  Future<void> limpiarSesion() async {
    for (final k in ClavesSesion.deSesion) {
      _m.remove(k);
    }
  }
}
