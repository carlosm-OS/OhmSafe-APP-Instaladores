import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Face ID / Touch ID / huella. No habla con el servidor: sólo decide si la
/// app puede usar el refresh guardado. Sin biometría enrolada siempre hay
/// contraseña.
class BiometriaService {
  BiometriaService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// El dispositivo soporta y tiene biometría enrolada.
  Future<bool> disponible() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final tipos = await _auth.getAvailableBiometrics();
      return tipos.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Nombre legible de lo que hay: "Face ID", "Touch ID", "huella" o "biometría".
  Future<String> nombre() async {
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) return 'Face ID';
      if (tipos.contains(BiometricType.fingerprint)) return 'Touch ID';
      if (tipos.contains(BiometricType.strong) || tipos.contains(BiometricType.weak)) return 'huella';
    } catch (_) {}
    return 'biometría';
  }

  /// true si el usuario se autenticó. Cualquier error (no enrolado, bloqueado
  /// por el sistema, cancelado) devuelve false: quien llama ofrece contraseña.
  Future<bool> autenticar(String razon, {bool soloBiometria = false}) async {
    try {
      return await _auth.authenticate(localizedReason: razon, biometricOnly: soloBiometria);
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
