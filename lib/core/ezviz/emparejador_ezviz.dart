import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/ordenes/domain/repositories/ordenes_repository.dart';
import 'ezviz_puente.dart';

/// En qué va el emparejamiento de una cámara EZVIZ.
enum EtapaEzviz { inactivo, preparando, conectandoWifi, esperandoNube, registrando, listo, error }

/// Conecta una cámara EZVIZ a la Wi‑Fi de la casa y la registra en la cuenta del cliente
/// (2026-10-17). Mismo orden que el asistente de la app del cliente (`camera_add_wizard.dart`):
///
///  1. Sesión EZVIZ de la casa (`GET …/wifi/sesion?proveedor=ezviz`) → `configure` + `setSession`.
///  2. Sondeo en el backend y en el SDK: si ya es de otra cuenta se para; si ya está en internet
///     no hace falta mandarle la Wi‑Fi.
///  3. Aprovisionamiento (modo AP, u onda de sonido si la cámara no sabe AP). El desenlace llega
///     por eventos; si se agota el tiempo se sondea igual por si la cámara llegó sola.
///  4. Sondeo cada 5 s hasta que la nube la ve (máx. 120 s).
///  5. Alta en la casa (`POST …/dispositivos-wifi`) con el NOMBRE de la red. La contraseña sólo
///     pasa por [empezar] hacia el SDK: no se guarda en ningún campo.
class EmparejadorEzviz extends ChangeNotifier {
  EmparejadorEzviz({
    required this.repo,
    required this.ordenId,
    EzvizPuente? puente,
    this.cadaSondeo = const Duration(seconds: 5),
    this.topeWifi = const Duration(seconds: 100),
    this.margenWifi = const Duration(seconds: 5),
    this.topeNube = const Duration(seconds: 120),
  }) : puente = puente ?? EzvizPuente();

  final OrdenesRepository repo;
  final String ordenId;
  final EzvizPuente puente;
  final Duration cadaSondeo;
  final Duration topeWifi;

  /// Cuánto se espera al SDK después de [topeWifi] antes de sondear por cuenta propia.
  final Duration margenWifi;
  final Duration topeNube;

  EtapaEzviz etapa = EtapaEzviz.inactivo;
  String texto = '';
  String? error;
  String? modelo;

  /// Lo que devolvió el backend al registrar la cámara.
  Map<String, dynamic>? registrada;

  // Datos del intento en curso (sin la contraseña).
  String _serie = '';
  String _codigo = '';
  String _red = '';
  String _nombre = '';

  int _intento = 0;
  StreamSubscription<EzvizEvento>? _sub;
  Timer? _timerWifi;
  Timer? _timerSondeo;
  DateTime? _limiteNube;
  bool _sondeando = false;
  bool _cerrado = false;

  /// Hay un aprovisionamiento arrancado en el SDK (hay que pararlo y devolver el teléfono a su red).
  bool _wifiArrancada = false;

  bool get ocupado =>
      etapa == EtapaEzviz.preparando || etapa == EtapaEzviz.conectandoWifi || etapa == EtapaEzviz.esperandoNube || etapa == EtapaEzviz.registrando;

  Future<void> empezar({required String serie, required String codigo, required String red, required String contrasena, required String nombre}) async {
    if (ocupado) return;
    final intento = ++_intento;
    await _detener();
    _serie = serie.trim().toUpperCase();
    _codigo = codigo.trim().toUpperCase();
    _red = red.trim();
    _nombre = nombre.trim();
    error = null;
    _ir(EtapaEzviz.preparando, 'Preparando la cuenta de cámaras de la casa…');

    // 1) Sesión del fabricante con la cuenta de la casa.
    final s = await repo.wifiSesion(ordenId, 'ezviz');
    if (!_vigente(intento)) return;
    if (s.isFailure) return _fallar(s.failureValue.message);
    final sesion = s.successValue;
    final appKey = (sesion['appKey'] ?? '').toString();
    final token = (sesion['accessToken'] ?? '').toString();
    if (appKey.isEmpty || token.isEmpty) return _fallar('El servidor no entregó la cuenta de cámaras de esta casa. Avisa a soporte.');
    try {
      await puente.configurar(
        appKey: appKey,
        areaDomain: (sesion['areaDomain'] ?? '').toString().isNotEmpty ? sesion['areaDomain'].toString() : 'https://iusopen.ezvizlife.com',
        region: (sesion['region'] ?? 'na').toString(),
      );
      await puente.ponerSesion(accessToken: token, expira: DateTime.tryParse((sesion['expiresAt'] ?? '').toString()));
    } on EzvizError catch (e) {
      if (!_vigente(intento)) return;
      return _fallar(_copiaPuente(e));
    }
    if (!_vigente(intento)) return;

    // 2) ¿Ya es de otra cuenta, o ya está en internet?
    _ir(EtapaEzviz.preparando, 'Revisando la cámara…');
    final antes = await _sondearUnaVez();
    if (!_vigente(intento)) return;
    if (antes == EzvizEstado.deOtraCuenta) return _fallar(copiaOtraCuenta);
    if (EzvizEstado.listaParaRegistrar(antes)) return _registrar(intento);

    // 3) Mandarle la Wi‑Fi.
    final nativo = await puente.sondear(_serie);
    if (!_vigente(intento)) return;
    if (nativo.modelo != null) modelo = nativo.modelo;
    _ir(EtapaEzviz.conectandoWifi, nativo.modo == 'wave' ? 'Pasándole tu red a la cámara por sonido…' : 'Conectando el teléfono a la cámara…');
    _sub = puente.eventos.listen((e) {
      if (!_vigente(intento) || !e.esWifi) return;
      if (e.serie != null && e.serie!.toUpperCase() != _serie) return;
      if (e.wifiListo) {
        _esperarNube(intento);
      } else if (e.wifiFallo && e.error == EzvizCodigo.wifiTiempo) {
        // El SDK se rindió sin verla en la nube: se sondea igual, la cámara pudo llegar sola.
        _esperarNube(intento);
      } else if (e.wifiFallo) {
        unawaited(_detener());
        _fallar(copiaErrorWifi(e.codigo));
      } else if (etapa == EtapaEzviz.conectandoWifi) {
        _ir(EtapaEzviz.conectandoWifi, copiaPaso(e.paso));
      }
    });
    _wifiArrancada = true;
    try {
      await puente.configurarWifi(
        serie: _serie,
        codigo: _codigo,
        red: _red,
        contrasena: contrasena,
        modo: nativo.modo,
        prefijoHotspot: nativo.prefijoHotspot,
        tope: topeWifi,
      );
    } on EzvizError catch (e) {
      if (!_vigente(intento)) return;
      await _detener();
      return _fallar(_copiaPuente(e));
    }
    if (!_vigente(intento)) return;
    // Si el SDK se queda callado, al acabar el plazo se sondea igual: la cámara pudo llegar sola.
    _timerWifi = Timer(topeWifi + margenWifi, () => _esperarNube(intento));
  }

  /// Cancela lo que esté en marcha y regresa el teléfono a su red.
  Future<void> cancelar() async {
    _intento++;
    await _detener();
    _ir(EtapaEzviz.inactivo, '');
  }

  void _esperarNube(int intento) {
    if (!_vigente(intento) || etapa == EtapaEzviz.esperandoNube || etapa == EtapaEzviz.registrando) return;
    _timerWifi?.cancel();
    if (_wifiArrancada) {
      _wifiArrancada = false;
      unawaited(puente.pararWifi());
    }
    _limiteNube = DateTime.now().add(topeNube);
    _ir(EtapaEzviz.esperandoNube, 'La cámara se está conectando a internet…');
    _timerSondeo?.cancel();
    _timerSondeo = Timer.periodic(cadaSondeo, (_) => unawaited(_sondeoNube(intento)));
    unawaited(_sondeoNube(intento));
  }

  Future<void> _sondeoNube(int intento) async {
    if (_sondeando || !_vigente(intento) || etapa != EtapaEzviz.esperandoNube) return;
    _sondeando = true;
    try {
      final estado = await _sondearUnaVez();
      if (!_vigente(intento) || etapa != EtapaEzviz.esperandoNube) return;
      if (EzvizEstado.listaParaRegistrar(estado)) {
        _timerSondeo?.cancel();
        await _registrar(intento);
        return;
      }
      if (estado == EzvizEstado.deOtraCuenta) {
        await _detener();
        _fallar(copiaOtraCuenta);
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

  /// Primero el SDK (es el único que distingue «encendida y libre»); si no sabe, el backend.
  Future<String> _sondearUnaVez() async {
    final n = await puente.sondear(_serie);
    if (n.modelo != null) modelo = n.modelo;
    if (n.estado != 'unknown') return n.estado;
    final r = await repo.ezvizSondeo(ordenId, _serie);
    if (r.isFailure) return 'unknown';
    final m = r.successValue['model'];
    if (m is String && m.isNotEmpty) modelo = m;
    return (r.successValue['state'] ?? 'unknown').toString();
  }

  Future<void> _registrar(int intento) async {
    await _detener();
    if (!_vigente(intento)) return;
    _ir(EtapaEzviz.registrando, 'Guardando la cámara en la casa del cliente…');
    final r = await repo.dispositivoWifiAgregar(ordenId, proveedor: 'ezviz', clase: 'camara', externalId: _serie, nombre: _nombre, codigo: _codigo, red: _red);
    if (!_vigente(intento)) return;
    if (r.isFailure) return _fallar(r.failureValue.message);
    registrada = (r.successValue['dispositivo'] as Map?)?.cast<String, dynamic>() ?? r.successValue;
    _ir(EtapaEzviz.listo, 'Cámara conectada a «$_red» y guardada en la casa.');
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

  void _ir(EtapaEzviz e, String t) {
    if (_cerrado) return;
    etapa = e;
    texto = t;
    notifyListeners();
  }

  void _fallar(String mensaje) {
    if (_cerrado) return;
    error = mensaje;
    _ir(EtapaEzviz.error, mensaje);
  }

  String _copiaPuente(EzvizError e) => switch (e.codigo) {
    EzvizCodigo.noEnlazado => 'Esta versión de la app no puede conectar esta cámara. Actualízala.',
    EzvizCodigo.noConfigurado => 'No se pudo empezar a conectar la cámara en este teléfono. Avisa a soporte.',
    EzvizCodigo.sinSesion || EzvizCodigo.tokenCaducado => 'No se aceptó la cuenta de cámaras de la casa. Vuelve a intentarlo; si sigue, avisa a soporte.',
    EzvizCodigo.noSoportado => 'Este teléfono no puede conectar esta cámara.',
    EzvizCodigo.wifiTiempo => copiaWifiTiempo,
    _ => e.codigoProveedor != null ? copiaErrorWifi(e.codigoProveedor) : e.mensaje,
  };

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

// v2 (2026-10-23): sin marcas en texto visible («su app de origen», «la cámara»).
const copiaOtraCuenta =
    'Esta cámara está registrada en otra cuenta. Pide al cliente que la quite de su app de origen o restablécela de fábrica, y vuelve a intentarlo.';
const copiaWifiTiempo = 'La cámara no terminó de conectarse. Mantén RESET 10–15 s hasta que la luz parpadee, espera a que esté lista y vuelve a intentarlo.';
const copiaNubeTiempo = 'La cámara no llegó a internet. Revisa la contraseña de la Wi‑Fi y que la red sea de 2.4 GHz (no 5 GHz), y vuelve a intentarlo.';

/// Pasos del SDK (mismos nombres en iOS y Android) → texto para el instalador.
String copiaPaso(String? paso) => switch (paso) {
  'joining_hotspot' => 'Conectando el teléfono a la cámara… acepta «Conectarse» si el teléfono lo pregunta.',
  'joined_hotspot' || 'sending_config' => 'Pasándole la red de la casa a la cámara…',
  'connecting_to_wifi' || 'connected_to_wifi' => 'La cámara se está conectando a la Wi‑Fi de la casa…',
  'registered' => 'La cámara ya llegó a internet.',
  _ => 'Conectando la cámara…',
};

/// Errores del aprovisionamiento (mismos números que la app del cliente, §11.15 D).
String copiaErrorWifi(int? codigo) => switch (codigo) {
  505 => 'La cámara no está en modo de configuración: mantén RESET 10–15 s hasta que la luz parpadee.',
  120 => 'El código de verificación no es correcto. Revísalo en la etiqueta.',
  111 || 605 => 'El teléfono no está en la red Wi‑Fi de la casa.',
  501 => 'Falta el permiso de ubicación. Actívalo en Ajustes para esta app.',
  15 || 7 => copiaNubeTiempo,
  6 => 'La cámara no recibió los datos de la Wi‑Fi. Acércate a ella y vuelve a intentarlo.',
  506 => 'Se rechazó la conexión a la red de la cámara. Acepta «Conectarse» cuando el teléfono lo pregunte.',
  110 || 502 => 'Ya hay una conexión en marcha. Espera un momento y vuelve a intentarlo.',
  507 => 'No se pudo encender la Wi‑Fi del teléfono.',
  705 => 'Sube el volumen del teléfono al máximo y vuelve a intentarlo.',
  801 || 802 => 'No se pudo registrar la cámara. Revisa el internet del teléfono y vuelve a intentarlo.',
  null => 'La cámara no terminó de conectarse a la red.',
  _ => 'La cámara no terminó de conectarse a la red (código $codigo).',
};
