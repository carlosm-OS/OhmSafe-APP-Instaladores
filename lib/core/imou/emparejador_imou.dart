import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/ordenes/domain/repositories/ordenes_repository.dart';
import 'imou_puente.dart';

/// En qué va el emparejamiento de una cámara Imou.
enum EtapaImou { inactivo, preparando, conectandoWifi, esperandoNube, registrando, listo, error }

/// Conecta una cámara Imou a la Wi‑Fi de la casa con el SDK de Imou y la registra en la casa
/// (2026-10-20, build 52). Mismo orden que [EmparejadorEzviz]:
///
///  1. Sesión del SDK (`POST …/wifi/imou/sesion` → host + accessToken) → `configure`.
///  2. Sondeo en el backend: si la cámara ya está en línea no hace falta mandarle la Wi‑Fi.
///  3. Aprovisionamiento (`smart` o `ap`). El SDK avisa cuando ve la cámara en la red local; si
///     se agota el plazo se sondea igual, la cámara pudo llegar sola.
///  4. Sondeo cada 5 s hasta que la nube la ve (máx. [topeNube]).
///  5. Alta en la casa (`POST …/dispositivos-wifi`, que hace el `bindDevice` con el SC) con el
///     NOMBRE de la red. La contraseña sólo pasa por [empezar] hacia el SDK.
class EmparejadorImou extends ChangeNotifier {
  EmparejadorImou({
    required this.repo,
    required this.ordenId,
    ImouPuente? puente,
    this.cadaSondeo = const Duration(seconds: 5),
    this.topeWifi = const Duration(seconds: 90),
    this.margenWifi = const Duration(seconds: 5),
    this.topeNube = const Duration(seconds: 150),
  }) : puente = puente ?? ImouPuente();

  final OrdenesRepository repo;
  final String ordenId;
  final ImouPuente puente;
  final Duration cadaSondeo;
  final Duration topeWifi;

  /// Cuánto se espera al SDK después de [topeWifi] antes de sondear por cuenta propia.
  final Duration margenWifi;
  final Duration topeNube;

  EtapaImou etapa = EtapaImou.inactivo;
  String texto = '';
  String? error;

  /// Lo que devolvió el backend al registrar la cámara.
  Map<String, dynamic>? registrada;

  // Datos del intento en curso (sin la contraseña).
  String _serie = '';
  String _codigo = '';
  String _red = '';
  String _nombre = '';
  String _modo = 'smart';

  int _intento = 0;
  StreamSubscription<ImouEvento>? _sub;
  Timer? _timerWifi;
  Timer? _timerSondeo;
  DateTime? _limiteNube;
  bool _sondeando = false;
  bool _cerrado = false;
  bool _wifiArrancada = false;

  bool get ocupado => etapa == EtapaImou.preparando || etapa == EtapaImou.conectandoWifi || etapa == EtapaImou.esperandoNube || etapa == EtapaImou.registrando;

  /// `modo`: `smart` (rápido) o `ap`.
  Future<void> empezar({required String serie, required String codigo, required String red, required String contrasena, required String nombre, String modo = 'smart'}) async {
    if (ocupado) return;
    final intento = ++_intento;
    await _detener();
    _serie = serie.trim().toUpperCase();
    // El SC de Imou distingue mayúsculas y minúsculas: tal cual.
    _codigo = codigo.trim();
    _red = red.trim();
    _nombre = nombre.trim();
    _modo = modo == 'ap' ? 'ap' : 'smart';
    error = null;
    _ir(EtapaImou.preparando, 'Preparando la cuenta de cámaras…');

    // 1) Sesión del SDK con la cuenta institucional.
    final s = await repo.imouSesion(ordenId);
    if (!_vigente(intento)) return;
    if (s.isFailure) return _fallar(s.failureValue.message);
    final sesion = s.successValue;
    final host = (sesion['host'] ?? '').toString();
    final token = (sesion['accessToken'] ?? '').toString();
    if (host.isEmpty || token.isEmpty) return _fallar('El servidor no entregó la cuenta de cámaras Imou. Avisa a soporte.');
    try {
      await puente.configurar(host: host, puerto: (sesion['port'] as num?)?.toInt() ?? 443, accessToken: token);
    } on ImouError catch (e) {
      if (!_vigente(intento)) return;
      return _fallar(copiaPuente(e));
    }
    if (!_vigente(intento)) return;

    // 2) ¿Ya está en internet?
    _ir(EtapaImou.preparando, 'Revisando la cámara…');
    final antes = await _sondearUnaVez();
    if (!_vigente(intento)) return;
    if (antes == ImouEstado.enLinea) return _registrar(intento);

    // 3) Mandarle la Wi‑Fi.
    _ir(EtapaImou.conectandoWifi, _modo == 'ap' ? 'Conectando el teléfono a la cámara…' : 'Pasándole la red de la casa a la cámara…');
    _sub = puente.eventos.listen((e) {
      if (!_vigente(intento) || !e.esWifi) return;
      if (e.serie != null && e.serie!.toUpperCase() != _serie) return;
      if (e.wifiListo) {
        _esperarNube(intento);
      } else if (e.wifiFallo && e.error == ImouCodigo.wifiTiempo) {
        // El SDK no la vio en la red local: se sondea igual, la cámara pudo llegar sola.
        _esperarNube(intento);
      } else if (e.wifiFallo) {
        unawaited(_detener());
        _fallar(e.mensaje?.isNotEmpty == true ? e.mensaje! : copiaErrorWifi(e.codigo));
      } else if (etapa == EtapaImou.conectandoWifi) {
        _ir(EtapaImou.conectandoWifi, copiaPaso(e.paso));
      }
    });
    _wifiArrancada = true;
    try {
      await puente.configurarWifi(serie: _serie, codigo: _codigo, red: _red, contrasena: contrasena, modo: _modo, tope: topeWifi);
    } on ImouError catch (e) {
      if (!_vigente(intento)) return;
      await _detener();
      return _fallar(copiaPuente(e));
    }
    if (!_vigente(intento)) return;
    _timerWifi = Timer(topeWifi + margenWifi, () => _esperarNube(intento));
  }

  /// Cancela lo que esté en marcha.
  Future<void> cancelar() async {
    _intento++;
    await _detener();
    _ir(EtapaImou.inactivo, '');
  }

  void _esperarNube(int intento) {
    if (!_vigente(intento) || etapa == EtapaImou.esperandoNube || etapa == EtapaImou.registrando) return;
    _timerWifi?.cancel();
    if (_wifiArrancada) {
      _wifiArrancada = false;
      unawaited(puente.pararWifi());
    }
    _limiteNube = DateTime.now().add(topeNube);
    _ir(EtapaImou.esperandoNube, 'La cámara se está conectando a internet…');
    _timerSondeo?.cancel();
    _timerSondeo = Timer.periodic(cadaSondeo, (_) => unawaited(_sondeoNube(intento)));
    unawaited(_sondeoNube(intento));
  }

  Future<void> _sondeoNube(int intento) async {
    if (_sondeando || !_vigente(intento) || etapa != EtapaImou.esperandoNube) return;
    _sondeando = true;
    try {
      final estado = await _sondearUnaVez();
      if (!_vigente(intento) || etapa != EtapaImou.esperandoNube) return;
      if (estado == ImouEstado.enLinea) {
        _timerSondeo?.cancel();
        await _registrar(intento);
        return;
      }
      if (_limiteNube != null && DateTime.now().isAfter(_limiteNube!)) {
        await _detener();
        _fallar(copiaNubeTiempo);
      }
    } finally {
      _sondeando = false;
    }
  }

  Future<String> _sondearUnaVez() async {
    final r = await repo.imouSondeo(ordenId, _serie);
    if (r.isFailure) return ImouEstado.desconocida;
    return (r.successValue['state'] ?? ImouEstado.desconocida).toString();
  }

  Future<void> _registrar(int intento) async {
    await _detener();
    if (!_vigente(intento)) return;
    _ir(EtapaImou.registrando, 'Guardando la cámara en la casa del cliente…');
    final r = await repo.dispositivoWifiAgregar(ordenId, proveedor: 'imou', clase: 'camara', externalId: _serie, nombre: _nombre, codigo: _codigo, red: _red);
    if (!_vigente(intento)) return;
    if (r.isFailure) return _fallar(copiaRegistro(r.failureValue.message));
    registrada = (r.successValue['dispositivo'] as Map?)?.cast<String, dynamic>() ?? r.successValue;
    _ir(EtapaImou.listo, 'Cámara conectada a «$_red» y guardada en la casa.');
  }

  Future<void> _detener() async {
    _timerWifi?.cancel();
    _timerWifi = null;
    _timerSondeo?.cancel();
    _timerSondeo = null;
    await _sub?.cancel();
    _sub = null;
    if (_wifiArrancada) {
      _wifiArrancada = false;
      await puente.pararWifi();
    }
  }

  bool _vigente(int intento) => !_cerrado && intento == _intento;

  void _ir(EtapaImou e, String t) {
    if (_cerrado) return;
    etapa = e;
    texto = t;
    notifyListeners();
  }

  void _fallar(String mensaje) {
    if (_cerrado) return;
    error = mensaje;
    _ir(EtapaImou.error, mensaje);
  }

  @override
  void dispose() {
    _cerrado = true;
    _intento++;
    _timerWifi?.cancel();
    _timerSondeo?.cancel();
    _sub?.cancel();
    if (_wifiArrancada) unawaited(puente.pararWifi());
    super.dispose();
  }
}

const copiaNubeTiempo =
    'La cámara no llegó a internet. Revisa la contraseña de la Wi‑Fi y que la red sea de 2.4 GHz (no 5 GHz); si la luz sigue parpadeando, mantén RESET 10 s y vuelve a intentarlo.';

/// Errores del puente → qué hacer.
String copiaPuente(ImouError e) => switch (e.codigo) {
  ImouCodigo.noEnlazado => 'Esta versión de la app no puede conectar cámaras Imou a la Wi‑Fi. Actualízala.',
  ImouCodigo.noConfigurado => 'No se pudo iniciar Imou en este teléfono. Avisa a soporte.',
  ImouCodigo.sinSesion => 'Imou no aceptó la cuenta de OhmSafe. Vuelve a intentarlo; si sigue, avisa a soporte.',
  ImouCodigo.sinPermiso => 'Falta el permiso de ubicación o de redes cercanas. Actívalo en Ajustes para esta app.',
  ImouCodigo.noSoportado => 'Este teléfono no puede usar el programa de Imou en este modo.',
  ImouCodigo.wifiTiempo => copiaNubeTiempo,
  _ => e.mensaje,
};

/// Pasos del SDK (mismos nombres en iOS y Android) → texto para el instalador.
String copiaPaso(String? paso) => switch (paso) {
  'joining_hotspot' => 'Conectando el teléfono a la cámara… acepta «Conectarse» si el teléfono lo pregunta.',
  'joined_hotspot' || 'sending_config' => 'Pasándole la red de la casa a la cámara…',
  'found_on_lan' => 'La cámara ya está en la red de la casa.',
  _ => 'Conectando la cámara…',
};

String copiaErrorWifi(int? codigo) => switch (codigo) {
  -2 => 'No se encontró la cámara. Mantén RESET 10 s hasta que la luz vuelva a parpadear y vuelve a intentarlo.',
  -3 => 'La cámara no encuentra esa red Wi‑Fi. Revisa el nombre y que sea de 2.4 GHz, y acércala al módem.',
  null => 'La cámara no terminó de conectarse a la red.',
  _ => 'La cámara no terminó de conectarse a la red (código $codigo).',
};

/// Los códigos de la nube de Imou al registrar → qué hacer.
String copiaRegistro(String msg) {
  if (msg.contains('DV1002')) {
    return 'Imou todavía no ve esta cámara en internet. Espera un minuto con la luz verde fija y vuelve a intentarlo.';
  }
  if (msg.contains('DV1001')) {
    return 'Esta cámara está ligada a otra cuenta de Imou. Hay que quitarla de esa app (o restablecerla de fábrica) y volver a intentar.';
  }
  if (msg.contains('DV1005') || msg.contains('DV1016') || msg.contains('DV1025') || msg.contains('VENDOR_CODE_INVALID')) {
    return 'El código de seguridad no coincide. Revisa mayúsculas y minúsculas: es el «SAFETY CODE» de la etiqueta, tal cual.';
  }
  return msg;
}
