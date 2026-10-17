import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puente con el SDK de EZVIZ (EZOpenSDK) para conectar cámaras a la Wi‑Fi de la casa
/// desde el teléfono del instalador (2026-10-17, fase 2 de docs/instalador-wifi.md del backend).
///
/// Es la versión recortada del puente de la app del cliente (`ohmsafe/ezviz`, CONTRACTS §11.15 C):
/// sólo sesión, sondeo y aprovisionamiento de Wi‑Fi; nada de vídeo, audio ni PTZ. Los nombres de
/// métodos, eventos y códigos `EZVIZ_*` son los mismos para que un arreglo en una app se pueda
/// llevar a la otra.
///
/// La contraseña de la Wi‑Fi y el código de la etiqueta viajan al SDK y **no se guardan ni se
/// registran** en ningún lado (ni aquí ni en Swift/Kotlin).
class EzvizPuente {
  EzvizPuente({MethodChannel? canal, EventChannel? eventos})
    : _canal = canal ?? const MethodChannel('ohmsafe/ezviz'),
      _eventos = eventos ?? const EventChannel('ohmsafe/ezviz/events');

  final MethodChannel _canal;
  final EventChannel _eventos;
  Stream<EzvizEvento>? _stream;

  /// Eventos `wifiConfig` y `deviceOnline` del SDK.
  Stream<EzvizEvento> get eventos => _stream ??= _eventos
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) => EzvizEvento.desdeMapa((e as Map).cast<Object?, Object?>()))
      .asBroadcastStream();

  /// `initLib` con la AppKey que manda el backend en la sesión de la casa.
  Future<void> configurar({required String appKey, required String areaDomain, String region = 'na'}) =>
      _llamar<bool>('configure', {'appKey': appKey, 'areaDomain': areaDomain, 'region': region});

  /// Token de la sub‑cuenta de la casa. El equipo queda en la cuenta del cliente, no en la del instalador.
  Future<void> ponerSesion({required String accessToken, DateTime? expira}) =>
      _llamar<bool>('setSession', {'accessToken': accessToken, 'expiresAt': expira?.millisecondsSinceEpoch});

  Future<void> cerrarSesion() async {
    try {
      await _llamar<bool>('logout');
    } catch (_) {
      // Cerrar no puede tumbar la pantalla.
    }
  }

  /// `probeDeviceInfo`: en qué estado está la cámara y cómo se le puede mandar la Wi‑Fi.
  /// Nunca lanza: si el SDK no contesta se sigue con [EzvizSondeoNativo.desconocido] (modo AP).
  Future<EzvizSondeoNativo> sondear(String serie) async {
    try {
      final r = await _llamar<Map<Object?, Object?>>('probe', {'serial': serie});
      return EzvizSondeoNativo.desdeMapa(r);
    } catch (e) {
      debugPrint('[EZVIZ] no se pudo sondear con el SDK: ${e.runtimeType}');
      return EzvizSondeoNativo.desconocido;
    }
  }

  /// Arranca el aprovisionamiento. El desenlace llega por [eventos] (`wifiConfig` done/error).
  Future<void> configurarWifi({
    required String serie,
    required String codigo,
    required String red,
    required String contrasena,
    String modo = 'ap',
    String prefijoHotspot = 'EZVIZ',
    Duration tope = const Duration(seconds: 100),
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

  /// Nombre de la red Wi‑Fi a la que está conectado el teléfono (necesita permiso de ubicación).
  /// `null` si no se puede leer: el instalador lo escribe.
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
      throw const EzvizError(EzvizCodigo.noEnlazado, 'Esta versión de la app no trae el emparejamiento de cámaras EZVIZ.');
    } on PlatformException catch (e) {
      final d = e.details;
      final codigoProveedor = d is Map ? (d['providerCode'] as num?)?.toInt() : null;
      throw EzvizError(e.code, e.message ?? 'El SDK de EZVIZ no respondió.', codigoProveedor: codigoProveedor);
    }
  }
}

/// Códigos del puente (los mismos de Swift, Kotlin y la app del cliente).
abstract final class EzvizCodigo {
  static const noEnlazado = 'EZVIZ_NOT_LINKED';
  static const noConfigurado = 'EZVIZ_NOT_CONFIGURED';
  static const sinSesion = 'EZVIZ_NO_SESSION';
  static const tokenCaducado = 'EZVIZ_TOKEN_EXPIRED';
  static const wifiTiempo = 'EZVIZ_WIFI_TIMEOUT';
  static const wifiFallo = 'EZVIZ_WIFI_FAILED';
  static const noSoportado = 'EZVIZ_UNSUPPORTED';
}

class EzvizError implements Exception {
  const EzvizError(this.codigo, this.mensaje, {this.codigoProveedor});
  final String codigo;
  final String mensaje;
  final int? codigoProveedor;

  @override
  String toString() => 'EzvizError($codigo${codigoProveedor != null ? ' · $codigoProveedor' : ''})';
}

/// Un evento de `ohmsafe/ezviz/events`.
@immutable
class EzvizEvento {
  const EzvizEvento({required this.tipo, this.serie, this.paso, this.estado, this.codigo, this.error, this.mensaje, this.enLinea});

  factory EzvizEvento.desdeMapa(Map<Object?, Object?> m) => EzvizEvento(
    tipo: (m['type'] ?? '').toString(),
    serie: m['serial']?.toString(),
    paso: m['step']?.toString(),
    estado: m['status']?.toString(),
    codigo: (m['code'] as num?)?.toInt(),
    error: m['error']?.toString(),
    mensaje: m['message']?.toString(),
    enLinea: m['online'] as bool?,
  );

  final String tipo;
  final String? serie;
  final String? paso;
  final String? estado;
  final int? codigo;
  final String? error;
  final String? mensaje;
  final bool? enLinea;

  bool get esWifi => tipo == 'wifiConfig';
  bool get wifiListo => esWifi && estado == 'done';
  bool get wifiFallo => esWifi && estado == 'error';
}

/// Lo que dice `probeDeviceInfo` del SDK.
@immutable
class EzvizSondeoNativo {
  const EzvizSondeoNativo({required this.estado, this.codigo = 0, this.modelo, this.soportaAp = 0, this.soportaOnda = 0, this.hotspot = 0});

  factory EzvizSondeoNativo.desdeMapa(Map<Object?, Object?> m) => EzvizSondeoNativo(
    estado: (m['state'] ?? 'unknown').toString(),
    codigo: (m['code'] as num?)?.toInt() ?? 0,
    modelo: (m['model'] as String?)?.trim().isEmpty ?? true ? null : (m['model'] as String).trim(),
    soportaAp: (m['supportAP'] as num?)?.toInt() ?? 0,
    soportaOnda: (m['supportSoundWave'] as num?)?.toInt() ?? 0,
    hotspot: (m['deviceHotSpot'] as num?)?.toInt() ?? 0,
  );

  static const desconocido = EzvizSondeoNativo(estado: 'unknown');

  /// `online_unbound` · `bound_here` · `bound_elsewhere` · `offline` · `not_found` · `unknown`.
  final String estado;
  final int codigo;
  final String? modelo;

  /// 2 = sabe modo AP (el normal).
  final int soportaAp;

  /// 1 = sabe onda de sonido.
  final int soportaOnda;

  /// 0 EZVIZ_ · 1 SoftAP_ · 2 CAMGO_: prefijo del punto de acceso de la cámara.
  final int hotspot;

  /// AP por omisión; onda de sonido sólo si la cámara no sabe AP y sí el sonido (igual que la app
  /// del cliente: en iOS la onda es poco fiable).
  String get modo => soportaAp != 2 && soportaOnda == 1 ? 'wave' : 'ap';

  String get prefijoHotspot => switch (hotspot) {
    1 => 'SoftAP',
    2 => 'CAMGO',
    _ => 'EZVIZ',
  };
}

/// Estados que da el backend (`POST …/wifi/ezviz/sondeo`) y el SDK, con el mismo vocabulario.
abstract final class EzvizEstado {
  static const libreEnLinea = 'online_unbound';
  static const nuestra = 'bound_here';
  static const deOtraCuenta = 'bound_elsewhere';
  static const fueraDeLinea = 'offline';
  static const noEncontrada = 'not_found';

  /// Ya se puede registrar en la casa.
  static bool listaParaRegistrar(String estado) => estado == libreEnLinea || estado == nuestra;
}
