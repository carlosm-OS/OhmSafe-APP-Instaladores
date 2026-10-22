import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../error/failures.dart';
import 'tuya_puente.dart';

/// Zona horaria IANA del teléfono (Tuya la pide para el token). `null` si el plugin no está (pruebas):
/// el backend usa la de México.
Future<String?> zonaHorariaDelTelefono() async {
  try {
    final z = await FlutterTimezone.getLocalTimezone();
    return z.identifier.isEmpty ? null : z.identifier;
  } catch (_) {
    return null;
  }
}

enum EtapaTuya { inactivo, preparando, emparejando, registrando, listo, error }

/// Empareja un sensor o una cámara Tuya a la Wi‑Fi de la casa y lo registra en la cuenta del cliente
/// (2026-10-17), con el **token de nube** de la casa (docs/instalador-wifi.md):
///
///  1. `POST …/wifi/tuya/token {modo}` → `authToken` (región+token+secreto), válido 10 min.
///  2. `configure` del SDK (llaves de la app) y `pairStart` con el token: el SDK le manda al equipo
///     la red y el token (EZ: el equipo escucha en la red; AP: el teléfono se une al punto de acceso
///     `SmartLife-XXXX` del equipo). El equipo se registra en la nube **en la cuenta de la casa**.
///  3. Dos caminos para saber que entró: el evento `pairDone` del SDK y, de respaldo, el sondeo del
///     backend `GET …/wifi/tuya/token/:token` cada 5 s (el SDK sin sesión puede no avisar).
///  4. Alta en la casa (`POST …/dispositivos-wifi`) con el NOMBRE de la red; la contraseña sólo pasa
///     por [empezar] hacia el SDK.
class EmparejadorTuya extends ChangeNotifier {
  EmparejadorTuya({
    required this.repo,
    required this.ordenId,
    TuyaPuente? puente,
    this.zonaHoraria = zonaHorariaDelTelefono,
    this.cadaSondeo = const Duration(seconds: 5),
    this.topeEmparejar = const Duration(seconds: 120),
    this.margen = const Duration(seconds: 15),
  }) : puente = puente ?? TuyaPuente();

  final Future<String?> Function() zonaHoraria;

  final OrdenesRepository repo;
  final String ordenId;
  final TuyaPuente puente;
  final Duration cadaSondeo;
  final Duration topeEmparejar;

  /// Cuánto más se sondea al backend después del tope del SDK antes de rendirse.
  final Duration margen;

  EtapaTuya etapa = EtapaTuya.inactivo;
  String texto = '';
  String? error;
  Map<String, dynamic>? registrado;

  String _clase = 'sensor';
  String? _tipo;
  String _nombre = '';
  String _red = '';
  String _token = '';
  String? _devId;
  String? _productId;
  String? _categoria;
  String? _serie;
  String? _nombreNube;

  /// Lo que la nube dijo del equipo que entró (2026-10-22): para la tarjeta «Equipo conectado».
  String? get devId => _devId;
  String? get categoria => _categoria;
  String? get serie => _serie;

  /// Nombre que trae el equipo de fábrica (p. ej. el modelo); vacío si la nube no lo dio.
  String get nombreDeFabrica => _nombreNube ?? '';
  String get red => _red;
  String get nombre => _nombre;

  int _intento = 0;
  StreamSubscription<TuyaEvento>? _sub;
  Timer? _sondeo;
  Timer? _limite;
  bool _sondeando = false;
  bool _arrancado = false;
  bool _cerrado = false;

  bool get ocupado => etapa == EtapaTuya.preparando || etapa == EtapaTuya.emparejando || etapa == EtapaTuya.registrando;

  Future<void> empezar({
    required String clase,
    String? tipo,
    required String nombre,
    required String red,
    required String contrasena,
    String modo = 'EZ',
    String? serie,
  }) async {
    if (ocupado) return;
    final intento = ++_intento;
    await _detener();
    _clase = clase;
    _tipo = tipo;
    _nombre = nombre.trim();
    _red = red.trim();
    _devId = null;
    _productId = null;
    _categoria = null;
    _nombreNube = null;
    final s = (serie ?? '').trim();
    _serie = s.isEmpty ? null : s;
    error = null;
    registrado = null;
    _ir(EtapaTuya.preparando, 'Pidiendo el permiso de la casa…');

    final t = await repo.tuyaToken(ordenId, modo: modo, zonaHoraria: await zonaHoraria());
    if (!_vigente(intento)) return;
    if (t.isFailure) return _fallar(copiaErrorToken(t.failureValue));
    _token = (t.successValue['token'] ?? '').toString();
    final authToken = (t.successValue['authToken'] ?? '').toString();
    if (_token.isEmpty || authToken.isEmpty) return _fallar('El servidor no entregó el permiso de emparejamiento. Avisa a soporte.');

    try {
      await puente.configurar();
    } on TuyaError catch (e) {
      if (!_vigente(intento)) return;
      return _fallar(copiaPuente(e));
    }
    if (!_vigente(intento)) return;

    _ir(EtapaTuya.emparejando, modo == 'AP' ? 'Si el teléfono lo pide, conéctate a la red Wi‑Fi nueva que crea el equipo (no tiene contraseña)…' : 'Pasándole la red de la casa al equipo…');
    _sub = puente.eventos.listen((e) {
      if (!_vigente(intento)) return;
      if (e.listo) {
        _devId = e.devId;
        _productId = e.productId;
        _categoria = e.categoria;
        if ((e.nombre ?? '').isNotEmpty) _nombreNube = e.nombre;
        if ((e.nombre ?? '').isNotEmpty && _nombre.isEmpty) _nombre = e.nombre!;
        unawaited(_registrar(intento));
      } else if (e.fallo) {
        // El SDK sin sesión puede quejarse aunque el equipo sí haya entrado: el backend decide.
        _ir(EtapaTuya.emparejando, 'Comprobando con la nube si el equipo entró…');
      } else if (e.progreso && etapa == EtapaTuya.emparejando) {
        _ir(EtapaTuya.emparejando, copiaPaso(e.paso));
      }
    });
    _arrancado = true;
    try {
      await puente.emparejar(modo: modo, red: _red, contrasena: contrasena, token: authToken, tope: topeEmparejar);
    } on TuyaError catch (e) {
      if (!_vigente(intento)) return;
      await _detener();
      return _fallar(copiaPuente(e));
    }
    if (!_vigente(intento)) return;
    _sondeo = Timer.periodic(cadaSondeo, (_) => unawaited(_sondear(intento)));
    _limite = Timer(topeEmparejar + margen, () => unawaited(_rendirse(intento)));
  }

  Future<void> cancelar() async {
    _intento++;
    await _detener();
    _ir(EtapaTuya.inactivo, '');
  }

  Future<void> _sondear(int intento) async {
    if (_sondeando || !_vigente(intento) || etapa != EtapaTuya.emparejando) return;
    _sondeando = true;
    try {
      final r = await repo.tuyaTokenResultado(ordenId, _token);
      if (!_vigente(intento) || etapa != EtapaTuya.emparejando) return;
      if (r.isFailure) return;
      final ok = ((r.successValue['successDevices'] as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (ok.isNotEmpty) {
        final d = ok.first;
        _devId = (d['id'] ?? '').toString();
        _productId = d['productId']?.toString();
        _categoria = d['category']?.toString();
        final n = (d['name'] ?? '').toString();
        if (n.isNotEmpty) _nombreNube = n;
        await _registrar(intento);
        return;
      }
      final malos = ((r.successValue['errorDevices'] as List?) ?? const []).whereType<Map>().toList();
      if (malos.isNotEmpty) {
        await _detener();
        _fallar('El equipo intentó entrar pero la nube lo rechazó${malos.first['error'] != null ? ' (${malos.first['error']})' : ''}. Reinícialo y vuelve a intentar.');
      }
    } finally {
      _sondeando = false;
    }
  }

  Future<void> _rendirse(int intento) async {
    if (!_vigente(intento) || etapa != EtapaTuya.emparejando) return;
    await _detener();
    _fallar(copiaTiempo);
  }

  Future<void> _registrar(int intento) async {
    if (!_vigente(intento) || etapa == EtapaTuya.registrando || etapa == EtapaTuya.listo) return;
    final devId = _devId ?? '';
    await _detener();
    if (!_vigente(intento)) return;
    if (devId.isEmpty) return _fallar('El equipo entró pero la nube no dio su identificador. Vuelve a intentarlo.');
    _ir(EtapaTuya.registrando, 'Guardando el equipo en la casa del cliente…');
    final r = await repo.dispositivoWifiAgregar(
      ordenId,
      proveedor: 'tuya',
      clase: _clase,
      externalId: devId,
      nombre: _nombre,
      red: _red,
      tipo: _tipo,
      productId: _productId,
      category: _categoria,
      serie: _serie,
    );
    if (!_vigente(intento)) return;
    if (r.isFailure) return _fallar(r.failureValue.message);
    registrado = (r.successValue['dispositivo'] as Map?)?.cast<String, dynamic>() ?? r.successValue;
    _ir(EtapaTuya.listo, '«$_nombre» conectado a «$_red» y guardado en la casa.');
  }

  Future<void> _detener() async {
    _sondeo?.cancel();
    _sondeo = null;
    _limite?.cancel();
    _limite = null;
    await _sub?.cancel();
    _sub = null;
    if (_arrancado) {
      _arrancado = false;
      await puente.cancelar();
    }
  }

  bool _vigente(int i) => !_cerrado && i == _intento;

  void _ir(EtapaTuya e, String t) {
    if (_cerrado) return;
    etapa = e;
    texto = t;
    notifyListeners();
  }

  void _fallar(String m) {
    if (_cerrado) return;
    error = m;
    _ir(EtapaTuya.error, m);
  }

  @override
  void dispose() {
    _cerrado = true;
    _intento++;
    _sondeo?.cancel();
    _limite?.cancel();
    _sub?.cancel();
    if (_arrancado) unawaited(puente.cancelar());
    super.dispose();
  }
}

const copiaTiempo =
    'El equipo no llegó a la nube. Revisa que esté en modo de emparejamiento (luz parpadeando rápido), que la red sea de 2.4 GHz y la contraseña, y vuelve a intentar.';

String copiaErrorToken(Failure f) => f is ServerFailure && f.code == 'TUYA_UID_DESCONOCIDO'
    ? 'La casa todavía no tiene su cuenta de equipos Wi‑Fi: el cliente debe entrar una vez a OhmSafe GO en su teléfono y luego vuelves a intentar.'
    : f.message;

String copiaPuente(TuyaError e) => switch (e.codigo) {
  TuyaCodigo.noEnlazado => 'Esta versión de la app no puede emparejar equipos Wi‑Fi. Actualízala.',
  TuyaCodigo.sinLlaves => e.mensaje,
  TuyaCodigo.noConfigurado => 'No se pudo iniciar el emparejamiento en este teléfono. Avisa a soporte.',
  TuyaCodigo.argumentos => 'Falta el nombre de la red o el permiso de la casa.',
  TuyaCodigo.tiempo => copiaTiempo,
  _ => e.mensaje,
};

String copiaPaso(String? paso) => switch (paso) {
  'ez_waiting' => 'Pasándole la red de la casa al equipo… (puede tardar 1 minuto)',
  'ap_waiting' => 'Conectado al equipo; pasándole la red de la casa…',
  'found' => 'El equipo ya recibió la red; registrándolo en la nube…',
  'registered' || 'initialized' => 'El equipo ya está en la nube…',
  _ => 'Emparejando el equipo…',
};
