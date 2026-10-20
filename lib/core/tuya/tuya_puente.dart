import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puente con el Smart Life App SDK de Tuya para emparejar sensores y cámaras Tuya a la Wi‑Fi de la
/// casa desde el teléfono del instalador (2026-10-17, fase 2 de docs/instalador-wifi.md).
///
/// Versión recortada del puente de la app del cliente (`ohmsafe/tuya`): sólo `configure` y el
/// emparejamiento por **token de nube**. La app del instalador NUNCA inicia sesión en Tuya: cada app
/// tiene su propio schema de usuarios y la cuenta de la casa vive en el de GO. El backend pide el
/// token (`POST …/wifi/tuya/token`) y el SDK sólo lo transmite al equipo (EZ o AP).
///
/// Las llaves de la app (`TUYA_*_APP_KEY/SECRET`) llegan por `--dart-define-from-file`, nunca van en
/// git. La contraseña de la Wi‑Fi viaja al SDK y no se guarda ni se registra.
class TuyaPuente {
  TuyaPuente({MethodChannel? canal, EventChannel? eventos, String? appKey, String? appSecret})
    : _canal = canal ?? const MethodChannel('ohmsafe/tuya'),
      _eventos = eventos ?? const EventChannel('ohmsafe/tuya/events'),
      _appKey = appKey ?? appKeyDeLaBuild,
      _appSecret = appSecret ?? appSecretDeLaBuild;

  final MethodChannel _canal;
  final EventChannel _eventos;
  final String _appKey;
  final String _appSecret;
  Stream<TuyaEvento>? _stream;

  static const _iosKey = String.fromEnvironment('TUYA_IOS_APP_KEY');
  static const _iosSecret = String.fromEnvironment('TUYA_IOS_APP_SECRET');
  static const _androidKey = String.fromEnvironment('TUYA_ANDROID_APP_KEY');
  static const _androidSecret = String.fromEnvironment('TUYA_ANDROID_APP_SECRET');

  /// En la consola de Tuya cada plataforma tiene su propia llave.
  static String get appKeyDeLaBuild => Platform.isIOS ? _iosKey : _androidKey;
  static String get appSecretDeLaBuild => Platform.isIOS ? _iosSecret : _androidSecret;

  /// `false` en una build sin llaves: la pantalla lo dice en vez de fallar a medias.
  static bool get buildConLlaves => appKeyDeLaBuild.isNotEmpty && appSecretDeLaBuild.isNotEmpty;
  bool get tieneLlaves => _appKey.isNotEmpty && _appSecret.isNotEmpty;

  Stream<TuyaEvento> get eventos => _stream ??= _eventos
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) => TuyaEvento.desdeMapa((e as Map).cast<Object?, Object?>()))
      .asBroadcastStream();

  /// `ThingSmartSDK.start` / `ThingHomeSdk.init`. Una vez por proceso.
  Future<void> configurar() {
    if (!tieneLlaves) {
      throw const TuyaError(TuyaCodigo.sinLlaves, 'Esta versión de la app no trae las llaves de emparejamiento. Avisa a soporte.');
    }
    return _llamar<bool>('configure', {'appKey': _appKey, 'appSecret': _appSecret});
  }

  /// Arranca el emparejamiento con el token de la casa. El desenlace llega por [eventos]
  /// (`pairProgress` → `pairDone` / `pairError`) y, de respaldo, por el sondeo del backend.
  Future<void> emparejar({required String modo, required String red, required String contrasena, required String token, Duration tope = const Duration(seconds: 120)}) =>
      _llamar<bool>('pairStart', {'mode': modo, 'ssid': red, 'password': contrasena, 'token': token, 'timeoutS': tope.inSeconds});

  /// Idempotente.
  Future<void> cancelar() async {
    try {
      await _llamar<bool>('pairCancel');
    } catch (_) {}
  }

  /// Nombre de la red Wi‑Fi actual del teléfono (necesita ubicación). `null` si no se puede leer.
  Future<String?> redActual() async {
    try {
      final r = await _llamar<String?>('currentSsid');
      final t = (r ?? '').trim();
      return t.isEmpty || t == '<unknown ssid>' ? null : t;
    } catch (_) {
      return null;
    }
  }

  Future<T> _llamar<T>(String metodo, [Map<String, Object?>? args]) async {
    try {
      final r = await _canal.invokeMethod<T>(metodo, args);
      return r as T;
    } on MissingPluginException {
      throw const TuyaError(TuyaCodigo.noEnlazado, 'Esta versión de la app no trae el emparejamiento de equipos Wi‑Fi.');
    } on PlatformException catch (e) {
      throw TuyaError(e.code, e.message ?? 'El emparejamiento no respondió.');
    }
  }
}

abstract final class TuyaCodigo {
  static const noEnlazado = 'TUYA_NOT_LINKED';
  static const sinLlaves = 'TUYA_NO_KEYS';
  static const noConfigurado = 'TUYA_NOT_CONFIGURED';
  static const argumentos = 'TUYA_PAIR_BAD_ARGS';
  static const fallo = 'TUYA_PAIR_FAILED';
  static const tiempo = 'TUYA_PAIR_TIMEOUT';
}

class TuyaError implements Exception {
  const TuyaError(this.codigo, this.mensaje);
  final String codigo;
  final String mensaje;

  @override
  String toString() => 'TuyaError($codigo)';
}

/// `pairProgress {step}` · `pairDone {devId, name, productId, category}` · `pairError {code, message}`.
@immutable
class TuyaEvento {
  const TuyaEvento({required this.tipo, this.paso, this.devId, this.nombre, this.productId, this.categoria, this.codigo, this.mensaje});

  factory TuyaEvento.desdeMapa(Map<Object?, Object?> m) => TuyaEvento(
    tipo: (m['type'] ?? '').toString(),
    paso: m['step']?.toString(),
    devId: m['devId']?.toString(),
    nombre: m['name']?.toString(),
    productId: m['productId']?.toString(),
    categoria: m['category']?.toString(),
    codigo: m['code']?.toString(),
    mensaje: m['message']?.toString(),
  );

  final String tipo;
  final String? paso;
  final String? devId;
  final String? nombre;
  final String? productId;
  final String? categoria;
  final String? codigo;
  final String? mensaje;

  bool get listo => tipo == 'pairDone' && (devId ?? '').isNotEmpty;
  bool get fallo => tipo == 'pairError';
  bool get progreso => tipo == 'pairProgress';
}
