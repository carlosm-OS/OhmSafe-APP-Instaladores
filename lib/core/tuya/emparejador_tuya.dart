import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Permisos de Bluetooth (Android 12+: BLUETOOTH_SCAN y BLUETOOTH_CONNECT; en iPhone el sistema pregunta
/// solo la primera vez). Nunca lanza: un «no» hace que se use el modo rápido.
Future<bool> permisoBluetoothDelTelefono() async {
  if (!Platform.isAndroid) return true;
  try {
    final r = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    return r.values.every((s) => s.isGranted || s.isLimited);
  } catch (_) {
    return false;
  }
}

/// `esperandoRedEquipo` (2026-10-22, caso de Nahum en i77): en modo punto de acceso el teléfono tiene
/// que unirse a la red Wi‑Fi que crea el equipo ANTES de arrancar el SDK.
enum EtapaTuya { inactivo, preparando, esperandoRedEquipo, emparejando, registrando, listo, error }

/// Los equipos en modo punto de acceso crean una red abierta con este prefijo (dato técnico; no se
/// muestra como texto propio en la app).
const prefijoRedEquipo = 'smartlife';
bool esRedDeEquipo(String? ssid) => (ssid ?? '').trim().toLowerCase().startsWith(prefijoRedEquipo);

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
    this.busquedaBluetooth = const Duration(seconds: 20),
    this.permisoBluetooth = permisoBluetoothDelTelefono,
  }) : puente = puente ?? TuyaPuente();

  /// Cuánto se busca el equipo por Bluetooth antes de pasar al modo rápido (como la app del cliente).
  final Duration busquedaBluetooth;
  final Future<bool> Function() permisoBluetooth;

  /// Modo con el que de verdad se emparejó ('BLE', 'EZ' o 'AP'): el Bluetooth cae al rápido si no ve el equipo.
  String modoUsado = '';

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

  bool get ocupado =>
      etapa == EtapaTuya.preparando || etapa == EtapaTuya.esperandoRedEquipo || etapa == EtapaTuya.emparejando || etapa == EtapaTuya.registrando;

  /// Cuándo vence el token de la casa (el backend lo da; vive ~5 min). El sondeo dura hasta ahí.
  DateTime? venceToken;

  /// Modo punto de acceso: lo pendiente para arrancar cuando el teléfono ya esté en la red del equipo.
  String _authAP = '';
  String _contrasenaAP = '';
  int _intentoAP = -1;

  /// Red a la que estaba el teléfono la última vez que se revisó (para decirle al instalador).
  String? redDelTelefono;

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
    await _conToken(intento, modo, contrasena);
  }

  /// Token de la casa para [modo] → SDK → Bluetooth o Wi‑Fi (rápido / punto de acceso).
  Future<void> _conToken(int intento, String modo, String contrasena) async {
    modoUsado = modo;
    // Si viene del respaldo (Bluetooth → rápido) se conserva el aviso de por qué cambió.
    _ir(EtapaTuya.preparando, etapa == EtapaTuya.preparando && texto.isNotEmpty ? texto : 'Pidiendo el permiso de la casa…');

    final t = await repo.tuyaToken(ordenId, modo: modo, zonaHoraria: await zonaHoraria());
    if (!_vigente(intento)) return;
    if (t.isFailure) return _fallar(copiaErrorToken(t.failureValue));
    _token = (t.successValue['token'] ?? '').toString();
    final authToken = (t.successValue['authToken'] ?? '').toString();
    final homeId = (t.successValue['homeId'] ?? '').toString();
    venceToken = DateTime.tryParse((t.successValue['expiresAt'] ?? '').toString());
    if (_token.isEmpty || authToken.isEmpty) return _fallar('El servidor no entregó el permiso para conectar el equipo. Avisa a soporte.');

    try {
      await puente.configurar();
    } on TuyaError catch (e) {
      if (!_vigente(intento)) return;
      return _fallar(copiaPuente(e));
    }
    if (!_vigente(intento)) return;
    if (modo == 'BLE') return _porBluetooth(intento, contrasena, authToken, homeId);
    await _porWifi(intento, modo, contrasena, authToken);
  }

  void _alEvento(int intento, TuyaEvento e) {
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
      _ir(EtapaTuya.emparejando, 'Comprobando si el equipo ya se registró…');
    } else if (e.progreso && etapa == EtapaTuya.emparejando) {
      _ir(EtapaTuya.emparejando, copiaPaso(e.paso));
    }
  }

  /// Bluetooth primero (2026-10-22, como Dan en GO): busca el equipo cerca y le pasa la red por ahí.
  /// Si no hay permiso, no aparece un equipo Bluetooth + Wi‑Fi o el SDK no arranca, sigue con el
  /// modo rápido sin que el instalador tenga que hacer nada.
  Future<void> _porBluetooth(int intento, String contrasena, String authToken, String homeId) async {
    if (!await permisoBluetooth()) {
      return _respaldoRapido(intento, contrasena, 'Sin permiso de Bluetooth: probando el modo rápido…');
    }
    if (!_vigente(intento)) return;
    _ir(EtapaTuya.emparejando, 'Buscando el equipo por Bluetooth…');
    final encontrado = Completer<TuyaEvento?>();
    _sub = puente.eventos.listen((e) {
      if (!_vigente(intento)) return;
      if (e.bleEncontrado) {
        if (e.combo && !encontrado.isCompleted) encontrado.complete(e);
      } else if (e.finBusqueda) {
        if (!encontrado.isCompleted) encontrado.complete(null);
      } else {
        _alEvento(intento, e);
      }
    });
    _arrancado = true;
    try {
      await puente.buscarBluetooth(tope: busquedaBluetooth);
    } on TuyaError {
      if (!encontrado.isCompleted) encontrado.complete(null);
    }
    final eq = await encontrado.future.timeout(busquedaBluetooth + const Duration(seconds: 5), onTimeout: () => null);
    if (!_vigente(intento)) return;
    if (eq == null) {
      await _detener();
      return _respaldoRapido(intento, contrasena, 'No vimos el equipo por Bluetooth: probando el modo rápido…');
    }
    await puente.detenerBusqueda();
    _ir(EtapaTuya.emparejando, 'Pasándole la red de la casa por Bluetooth…');
    try {
      await puente.emparejarBluetooth(
        uuid: eq.uuid!,
        productId: eq.productId ?? '',
        red: _red,
        contrasena: contrasena,
        token: authToken,
        homeId: homeId,
        tope: topeEmparejar,
      );
    } on TuyaError {
      if (!_vigente(intento)) return;
      await _detener();
      return _respaldoRapido(intento, contrasena, 'El Bluetooth no arrancó: probando el modo rápido…');
    }
    if (!_vigente(intento)) return;
    _sondeo = Timer.periodic(cadaSondeo, (_) => unawaited(_sondear(intento)));
    _limite = Timer(_plazoSondeo(), () => unawaited(_rendirse(intento)));
  }

  /// El sondeo dura lo que vive el token (en modo punto de acceso el instalador tarda en cambiar de
  /// red; antes se rendía a los 50–85 s, caso de Nahum en i77), nunca menos que el tope del SDK.
  Duration _plazoSondeo() {
    final minimo = topeEmparejar + margen;
    final vence = venceToken;
    if (vence == null) return minimo;
    final queda = vence.difference(DateTime.now());
    return queda > minimo ? queda : minimo;
  }

  Future<void> _respaldoRapido(int intento, String contrasena, String aviso) async {
    if (!_vigente(intento)) return;
    _ir(EtapaTuya.preparando, aviso);
    await _conToken(intento, 'EZ', contrasena);
  }

  Future<void> _porWifi(int intento, String modo, String contrasena, String authToken) async {
    if (modo == 'AP') {
      // El token ya se pidió con internet de la casa; ahora el instalador cambia el teléfono a la red
      // del equipo y vuelve. El SDK arranca en [continuarAP].
      _authAP = authToken;
      _contrasenaAP = contrasena;
      _intentoAP = intento;
      _ir(EtapaTuya.esperandoRedEquipo, 'Conecta el teléfono a la red Wi‑Fi del equipo y vuelve a la app.');
      return;
    }
    await _iniciarWifi(intento, modo, contrasena, authToken);
  }

  /// Modo punto de acceso: revisa que el teléfono ya esté en la red del equipo y arranca el SDK.
  /// Devuelve `false` (y deja [redDelTelefono]) si todavía no está; con [forzar] arranca igual.
  Future<bool> continuarAP({bool forzar = false}) async {
    if (etapa != EtapaTuya.esperandoRedEquipo) return false;
    final intento = _intentoAP;
    final ssid = await puente.redActual();
    if (!_vigente(intento) || etapa != EtapaTuya.esperandoRedEquipo) return false;
    redDelTelefono = ssid;
    if (!forzar && !esRedDeEquipo(ssid)) {
      notifyListeners();
      return false;
    }
    final vence = venceToken;
    if (vence != null && vence.difference(DateTime.now()) < const Duration(seconds: 45)) {
      _fallar('Pasó mucho tiempo y el permiso de la casa venció. Vuelve a intentar: pide un permiso nuevo antes de cambiar de red.');
      return false;
    }
    await _iniciarWifi(intento, 'AP', _contrasenaAP, _authAP);
    return true;
  }

  Future<void> _iniciarWifi(int intento, String modo, String contrasena, String authToken) async {
    _ir(
      EtapaTuya.emparejando,
      modo == 'AP' ? 'Pasándole la red de la casa al equipo… luego el teléfono vuelve solo a tu red.' : 'Pasándole la red de la casa al equipo…',
    );
    _sub = puente.eventos.listen((e) => _alEvento(intento, e));
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
    _limite = Timer(_plazoSondeo(), () => unawaited(_rendirse(intento)));
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
        _fallar(
          'El equipo intentó entrar pero no se pudo registrar${malos.first['error'] != null ? ' (${malos.first['error']})' : ''}. Reinícialo y vuelve a intentar.',
        );
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
    if (devId.isEmpty) return _fallar('El equipo entró pero no se pudo registrar: falta su identificador. Vuelve a intentarlo.');
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

// v2 (2026-10-23): sin «nube» ni «emparejar» en texto visible («se registre», «conectar»).
const copiaTiempo =
    'El equipo no se registró. Revisa que esté listo para conectar (luz parpadeando rápido), que la red sea de 2.4 GHz y la contraseña, y vuelve a intentar.';

String copiaErrorToken(Failure f) {
  if (f is ServerFailure && f.code == 'TUYA_UID_DESCONOCIDO') {
    return 'La casa todavía no tiene su cuenta de equipos Wi‑Fi: el cliente debe entrar una vez a OhmSafe GO en su teléfono y luego vuelves a intentar.';
  }
  // 502 del backend cuando la nube de los equipos rechaza algo (2026-10-22, Back-#162): sin marcas.
  if (f is ServerFailure && f.code == 'TUYA_CLOUD_ERROR') {
    final c = f.details['providerCode'];
    return 'No se obtuvo el permiso para conectar equipos Wi‑Fi${c != null ? ' (código $c)' : ''}. Espera un momento y vuelve a intentar; si sigue, avisa a soporte con ese código.';
  }
  return f.message;
}

String copiaPuente(TuyaError e) => switch (e.codigo) {
  TuyaCodigo.noEnlazado => 'Esta versión de la app no puede conectar equipos Wi‑Fi. Actualízala.',
  TuyaCodigo.sinLlaves => e.mensaje,
  TuyaCodigo.noConfigurado => 'No se pudo empezar a conectar el equipo en este teléfono. Avisa a soporte.',
  TuyaCodigo.argumentos => 'Falta el nombre de la red o el permiso de la casa.',
  TuyaCodigo.tiempo => copiaTiempo,
  _ => e.mensaje,
};

String copiaPaso(String? paso) => switch (paso) {
  'ez_waiting' => 'Pasándole la red de la casa al equipo… (puede tardar 1 minuto)',
  'ble_connecting' => 'Pasándole la red de la casa por Bluetooth…',
  'ap_waiting' => 'Conectado al equipo; pasándole la red de la casa…',
  'found' => 'El equipo ya recibió la red; registrándolo…',
  'registered' || 'initialized' => 'El equipo ya se registró…',
  _ => 'Conectando el equipo…',
};
