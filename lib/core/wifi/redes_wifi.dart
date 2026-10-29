/// Redes Wi‑Fi para el campo «Nombre de la red» al emparejar (2026-10-20, pedido de Carlos: «un
/// buscador de redes para que la encuentre y seleccione»).
///
/// El límite duro está en el iPhone: Apple **no** deja listar redes (la API existe pero pide un
/// permiso que casi nunca concede). Por eso aquí no se promete una lista: Android escanea de
/// verdad (`wifi_scan`, con el permiso de ubicación) y iOS sólo da la red conectada. Versión
/// recortada de `wifi_networks.dart` de la app del cliente (GO), sin redes recordadas ni contraseñas.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// Banda deducida de la frecuencia del escaneo (Android) o del nombre de la red.
enum BandaWifi {
  ghz24('2.4 GHz'),
  ghz5('5 GHz'),
  ghz6('6 GHz'),

  /// Sin frecuencia: una red tecleada no dice en qué banda vive.
  desconocida('');

  const BandaWifi(this.etiqueta);
  final String etiqueta;

  /// Los sensores y cámaras sólo entran por 2.4 GHz. Si no se sabe, no se bloquea: mejor dejar
  /// intentar que impedir por una suposición.
  bool get sirve => this == BandaWifi.ghz24 || this == BandaWifi.desconocida;
}

/// 2400–2500 MHz = 2.4 GHz · 5000–5900 = 5 GHz · 5925+ = 6 GHz.
BandaWifi bandaPorFrecuencia(int? mhz) {
  if (mhz == null) return BandaWifi.desconocida;
  if (mhz >= 2400 && mhz <= 2500) return BandaWifi.ghz24;
  if (mhz >= 5000 && mhz <= 5900) return BandaWifi.ghz5;
  if (mhz >= 5925) return BandaWifi.ghz6;
  return BandaWifi.desconocida;
}

/// Pista por el NOMBRE (lo único que hay en iOS o al teclear): los módems suelen llamar a la red de
/// 5 GHz «…5G», «…-5GHz», «…_5» y a la de 2.4 «…2.4G», «…24G». Sólo para avisar, nunca para impedir.
BandaWifi bandaPorNombre(String ssid) {
  final s = ssid.trim().toLowerCase();
  if (s.isEmpty) return BandaWifi.desconocida;
  if (RegExp(r'(2[.,]?4\s?g|24g|2[.,]4\s?ghz)').hasMatch(s)) return BandaWifi.ghz24;
  if (RegExp(r'(^|[^0-9a-z])(5\s?g(hz)?|5g)($|[^0-9a-z])|[-_ ]5$').hasMatch(s)) return BandaWifi.ghz5;
  if (RegExp(r'(^|[^0-9a-z])6\s?g(hz)?($|[^0-9a-z])').hasMatch(s)) return BandaWifi.ghz6;
  return BandaWifi.desconocida;
}

/// Una red que el selector puede pintar y (si es de 2.4 GHz) ofrecer.
@immutable
class RedWifi {
  const RedWifi({required this.ssid, this.banda = BandaWifi.desconocida, this.nivel});

  factory RedWifi.deEscaneo({required String ssid, required int frecuenciaMhz, int? nivel}) =>
      RedWifi(ssid: ssid.trim(), banda: bandaPorFrecuencia(frecuenciaMhz), nivel: nivel);

  final String ssid;
  final BandaWifi banda;

  /// RSSI en dBm (negativo; cuanto más cerca de 0, mejor señal).
  final int? nivel;

  bool get sirve => banda.sirve;

  /// Cuatro barras a partir del RSSI, como cualquier indicador de señal.
  int get barras {
    final rssi = nivel;
    if (rssi == null) return 0;
    if (rssi >= -55) return 4;
    if (rssi >= -67) return 3;
    if (rssi >= -78) return 2;
    return 1;
  }

  @override
  bool operator ==(Object other) => other is RedWifi && other.ssid == ssid && other.banda == banda && other.nivel == nivel;

  @override
  int get hashCode => Object.hash(ssid, banda, nivel);

  @override
  String toString() => 'RedWifi($ssid, ${banda.name}, $nivel)';
}

/// Ordena y deduplica lo que salió del escaneo: 2.4 GHz primero y por señal; la misma SSID en dos
/// bandas se queda con la de 2.4 (es con la que se queda el equipo). Las ocultas (SSID vacío) no van.
List<RedWifi> ordenarRedes(Iterable<RedWifi> redes) {
  final mejor = <String, RedWifi>{};
  for (final r in redes) {
    final ssid = r.ssid.trim();
    if (ssid.isEmpty) continue;
    final actual = mejor[ssid];
    if (actual == null || _mejor(r, actual)) {
      mejor[ssid] = r.ssid == ssid ? r : RedWifi(ssid: ssid, banda: r.banda, nivel: r.nivel);
    }
  }
  final lista = mejor.values.toList();
  lista.sort((a, b) {
    if (a.sirve != b.sirve) return a.sirve ? -1 : 1;
    final porNivel = (b.nivel ?? -999).compareTo(a.nivel ?? -999);
    if (porNivel != 0) return porNivel;
    return a.ssid.toLowerCase().compareTo(b.ssid.toLowerCase());
  });
  return lista;
}

bool _mejor(RedWifi candidata, RedWifi actual) {
  if (candidata.sirve != actual.sirve) return candidata.sirve;
  return (candidata.nivel ?? -999) > (actual.nivel ?? -999);
}

/// Cómo acabó el escaneo.
enum EstadoEscaneo {
  ok,

  /// iPhone (o un Android que no lo soporta): no hay lista que enseñar.
  noSoportado,

  /// Falta el permiso de ubicación.
  sinPermiso,

  /// El teléfono tiene la ubicación apagada.
  ubicacionApagada,

  /// Android limita a cuatro escaneos cada dos minutos.
  frenado,

  fallo,
}

@immutable
class ResultadoEscaneo {
  const ResultadoEscaneo(this.estado, [this.redes = const <RedWifi>[]]);
  final EstadoEscaneo estado;
  final List<RedWifi> redes;
}

/// Puerta única a la plataforma. Las pruebas inyectan una implementación falsa.
abstract class ListadorRedes {
  /// ¿Puede esta plataforma enumerar las redes de alrededor? Android sí, el iPhone no.
  bool get puedeListar;

  Future<ResultadoEscaneo> escanear();
}

/// La de verdad: `wifi_scan` en Android; en iOS contesta [EstadoEscaneo.noSoportado] sin tocar nada.
class ListadorRedesPlataforma implements ListadorRedes {
  ListadorRedesPlataforma({bool? esAndroid}) : _esAndroid = esAndroid ?? (!kIsWeb && Platform.isAndroid);

  final bool _esAndroid;

  @override
  bool get puedeListar => _esAndroid;

  @override
  Future<ResultadoEscaneo> escanear() async {
    if (!puedeListar) return const ResultadoEscaneo(EstadoEscaneo.noSoportado);
    try {
      final puede = await WiFiScan.instance.canStartScan();
      final bloqueo = _bloqueoInicio(puede);
      if (bloqueo != null) return ResultadoEscaneo(bloqueo);

      // Android frena a cuatro escaneos cada dos minutos. Si frena, los resultados en caché siguen
      // sirviendo: se leen igual y sólo se avisa del freno cuando encima vienen vacíos.
      final arranco = await WiFiScan.instance.startScan();
      final puedeLeer = await WiFiScan.instance.canGetScannedResults();
      final bloqueoLeer = _bloqueoLectura(puedeLeer);
      if (bloqueoLeer != null) return ResultadoEscaneo(bloqueoLeer);

      final puntos = await WiFiScan.instance.getScannedResults();
      final redes = ordenarRedes(puntos.map((ap) => RedWifi.deEscaneo(ssid: ap.ssid, frecuenciaMhz: ap.frequency, nivel: ap.level)));
      if (redes.isEmpty && !arranco) return const ResultadoEscaneo(EstadoEscaneo.frenado);
      return ResultadoEscaneo(EstadoEscaneo.ok, redes);
    } on PlatformException catch (e) {
      debugPrint('[WIFI] el escaneo falló (${e.code})');
      return const ResultadoEscaneo(EstadoEscaneo.fallo);
    } catch (e) {
      debugPrint('[WIFI] el escaneo falló (${e.runtimeType})');
      return const ResultadoEscaneo(EstadoEscaneo.fallo);
    }
  }

  static EstadoEscaneo? _bloqueoInicio(CanStartScan c) => switch (c) {
    CanStartScan.yes => null,
    CanStartScan.notSupported => EstadoEscaneo.noSoportado,
    CanStartScan.noLocationPermissionRequired || CanStartScan.noLocationPermissionDenied || CanStartScan.noLocationPermissionUpgradeAccuracy => EstadoEscaneo.sinPermiso,
    CanStartScan.noLocationServiceDisabled => EstadoEscaneo.ubicacionApagada,
    CanStartScan.failed => EstadoEscaneo.fallo,
  };

  static EstadoEscaneo? _bloqueoLectura(CanGetScannedResults c) => switch (c) {
    CanGetScannedResults.yes => null,
    CanGetScannedResults.notSupported => EstadoEscaneo.noSoportado,
    CanGetScannedResults.noLocationPermissionRequired || CanGetScannedResults.noLocationPermissionDenied || CanGetScannedResults.noLocationPermissionUpgradeAccuracy => EstadoEscaneo.sinPermiso,
    CanGetScannedResults.noLocationServiceDisabled => EstadoEscaneo.ubicacionApagada,
  };
}

/// Texto para el instalador cuando el escaneo no dio lista.
String copiaEscaneo(EstadoEscaneo e) => switch (e) {
  EstadoEscaneo.ok => '',
  EstadoEscaneo.noSoportado => 'Este teléfono no puede listar las redes. Escribe el nombre tal cual aparece en el módem.',
  EstadoEscaneo.sinPermiso => 'Falta el permiso de ubicación: Android lo pide para ver las redes. Actívalo en Ajustes para esta app.',
  EstadoEscaneo.ubicacionApagada => 'Enciende la ubicación del teléfono: Android la pide para ver las redes.',
  EstadoEscaneo.frenado => 'Android limita las búsquedas: espera un minuto y vuelve a intentar, o escribe el nombre.',
  EstadoEscaneo.fallo => 'No se pudieron leer las redes. Escribe el nombre tal cual aparece en el módem.',
};
