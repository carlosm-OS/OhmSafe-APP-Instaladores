import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puente con el SDK de Imou (LCOpenSDK) para conectar cámaras Imou a la Wi‑Fi de la casa desde
/// el teléfono del instalador (2026-10-20, build 52; regla de Carlos: nunca Imou Life).
///
/// Gemelo de [EzvizPuente]: mismos nombres de métodos, eventos y familia de códigos `IMOU_*` en
/// Dart, Kotlin y Swift. Sólo sesión y aprovisionamiento de Wi‑Fi; nada de vídeo.
///
/// Dos modos del SDK:
///  - `smart` (rápido, SmartConfig): el teléfono, conectado a la Wi‑Fi de la casa, le manda la red
///    a la cámara por paquetes multicast; a la vez busca la cámara en la red local y, cuando la ve,
///    da por entregada la red. En iOS pide el entitlement *Multicast Networking* de Apple.
///  - `ap`: el teléfono se une al punto de acceso de la cámara (`DAP-…`) y le pasa la red por ahí.
///
/// La contraseña de la Wi‑Fi y el código SC viajan al SDK y **no se guardan ni se registran**.
class ImouPuente {
  ImouPuente({MethodChannel? canal, EventChannel? eventos})
    : _canal = canal ?? const MethodChannel('ohmsafe/imou'),
      _eventos = eventos ?? const EventChannel('ohmsafe/imou/events');

  final MethodChannel _canal;
  final EventChannel _eventos;
  Stream<ImouEvento>? _stream;

  /// Eventos `wifiConfig` del SDK.
  Stream<ImouEvento> get eventos => _stream ??= _eventos
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) => ImouEvento.desdeMapa((e as Map).cast<Object?, Object?>()))
      .asBroadcastStream();

  /// `initOpenApi` con el host de la cuenta institucional y su accessToken (los manda el backend).
  Future<void> configurar({required String host, int puerto = 443, required String accessToken}) =>
      _llamar<bool>('configure', {'host': host, 'port': puerto, 'accessToken': accessToken});

  /// Arranca el aprovisionamiento. El desenlace llega por [eventos] (`wifiConfig` done/error).
  Future<void> configurarWifi({
    required String serie,
    required String codigo,
    required String red,
    required String contrasena,
    String modo = 'smart',
    String prefijoHotspot = 'DAP-',
    Duration tope = const Duration(seconds: 90),
  }) => _llamar<bool>('wifiConfigStart', {
    'mode': modo,
    'serial': serie,
    'verifyCode': codigo,
    'ssid': red,
    'password': contrasena,
    'hotspotPrefix': prefijoHotspot,
    'timeoutS': tope.inSeconds,
  });

  /// Idempotente: se puede llamar sin haber empezado.
  Future<void> pararWifi() async {
    try {
      await _llamar<bool>('wifiConfigStop');
    } catch (_) {}
  }

  /// Nombre de la red Wi‑Fi del teléfono (necesita permiso de ubicación). `null` si no se puede leer.
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
      throw const ImouError(ImouCodigo.noEnlazado, 'Esta versión de la app no trae el emparejamiento de cámaras Imou.');
    } on PlatformException catch (e) {
      final d = e.details;
      final codigoProveedor = d is Map ? (d['providerCode'] as num?)?.toInt() : null;
      debugPrint('[IMOU] ${e.code} en $metodo');
      throw ImouError(e.code, e.message ?? 'El SDK de Imou no respondió.', codigoProveedor: codigoProveedor);
    }
  }
}

/// Códigos del puente (los mismos en Kotlin y Swift).
abstract final class ImouCodigo {
  static const noEnlazado = 'IMOU_NOT_LINKED';
  static const noConfigurado = 'IMOU_NOT_CONFIGURED';
  static const sinSesion = 'IMOU_NO_SESSION';
  static const sinPermiso = 'IMOU_PERMISSION';
  static const wifiTiempo = 'IMOU_WIFI_TIMEOUT';
  static const wifiFallo = 'IMOU_WIFI_FAILED';
  static const noSoportado = 'IMOU_UNSUPPORTED';
  static const tiempo = 'IMOU_TIMEOUT';
}

class ImouError implements Exception {
  const ImouError(this.codigo, this.mensaje, {this.codigoProveedor});
  final String codigo;
  final String mensaje;
  final int? codigoProveedor;

  @override
  String toString() => 'ImouError($codigo${codigoProveedor != null ? ' · $codigoProveedor' : ''})';
}

/// Un evento de `ohmsafe/imou/events`.
@immutable
class ImouEvento {
  const ImouEvento({required this.tipo, this.serie, this.paso, this.estado, this.codigo, this.error, this.mensaje});

  factory ImouEvento.desdeMapa(Map<Object?, Object?> m) => ImouEvento(
    tipo: (m['type'] ?? '').toString(),
    serie: m['serial']?.toString(),
    paso: m['step']?.toString(),
    estado: m['status']?.toString(),
    codigo: (m['code'] as num?)?.toInt(),
    error: m['error']?.toString(),
    mensaje: m['message']?.toString(),
  );

  final String tipo;
  final String? serie;

  /// `start` · `joining_hotspot` · `joined_hotspot` · `sending_config` · `found_on_lan` · `timeout` · `failed`.
  final String? paso;

  /// `progress` · `done` · `error`.
  final String? estado;
  final int? codigo;
  final String? error;
  final String? mensaje;

  bool get esWifi => tipo == 'wifiConfig';
  bool get wifiListo => esWifi && estado == 'done';
  bool get wifiFallo => esWifi && estado == 'error';
}

/// Estados del sondeo del backend (`POST …/wifi/imou/sondeo`).
abstract final class ImouEstado {
  static const enLinea = 'online';
  static const fueraDeLinea = 'offline';

  /// La nube aún no conoce la cámara (DV1002): nunca se ha conectado.
  static const desconocida = 'unknown';
}
