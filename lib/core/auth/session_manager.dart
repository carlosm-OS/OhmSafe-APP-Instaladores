import 'dart:async';

import '../../features/auth/domain/entities/sesion.dart';
import '../error/exceptions.dart';
import '../network/dio_client.dart';
import 'session_store.dart';

/// Se lanza cuando no hay forma de recuperar la sesión: toca volver al login.
class SesionExpiradaException implements Exception {
  const SesionExpiradaException();
}

/// Sesión persistente del instalador (docs/sesiones-instalador.md del backend):
/// guarda el refresh en el almacén seguro, lo rota contra
/// `/instalador/auth/refresh` con un solo refresco en vuelo, y decide cuándo
/// toca el bloqueo biométrico.
class SessionManager {
  SessionManager({
    required DioClient dio,
    required SessionStore store,
    Duration umbralBloqueo = const Duration(minutes: 15),
    DateTime Function()? ahora,
  })  : _dio = dio,
        _store = store,
        umbralBloqueo = umbralBloqueo,
        _ahora = ahora ?? DateTime.now;

  final DioClient _dio;
  final SessionStore _store;
  final DateTime Function() _ahora;

  /// Tiempo en segundo plano tras el cual se vuelve a pedir Face ID.
  final Duration umbralBloqueo;

  Future<Sesion?>? _refrescoEnVuelo;

  /// Sesión reconstruida al arrancar o al refrescar (sin tokens en memoria
  /// más allá del access dentro de DioClient).
  Sesion? _actual;
  Sesion? get actual => _actual;

  Future<String> deviceId() => _store.deviceId();

  Future<bool> tieneSesionGuardada() async {
    final r = await _store.leer(ClavesSesion.refreshToken);
    return r != null && r.isNotEmpty;
  }

  /// Tras un login con contraseña: guarda el refresh y los datos del instalador.
  Future<void> guardarLogin(Sesion s, {required String email}) async {
    _actual = s;
    if (s.accessToken.isNotEmpty) _dio.setAuthToken(s.accessToken);
    if (s.refreshToken.isEmpty) return;
    await _store.escribir(ClavesSesion.refreshToken, s.refreshToken);
    await _store.escribir(ClavesSesion.instaladorId, s.instaladorId);
    await _store.escribir(ClavesSesion.nombre, s.nombre);
    await _store.escribir(ClavesSesion.numeroInstalador, s.numeroInstalador);
    await _store.escribir(ClavesSesion.rol, s.rol);
    await _store.escribir(ClavesSesion.email, email);
    await _store.escribir(ClavesSesion.ultimoCorreo, email);
    await marcarActivo();
  }

  /// Rota el refresh y deja un access nuevo en el cliente HTTP. Single-flight:
  /// dos 401 a la vez producen UN refresco. Lanza [SesionExpiradaException]
  /// cuando el servidor rechaza el refresh (revocado, vencido, otro dispositivo)
  /// y limpia el almacén; un fallo de red NO limpia nada.
  Future<Sesion?> refrescar() {
    return _refrescoEnVuelo ??= _refrescarUnaVez().whenComplete(() => _refrescoEnVuelo = null);
  }

  Future<Sesion?> _refrescarUnaVez() async {
    final refresh = await _store.leer(ClavesSesion.refreshToken);
    if (refresh == null || refresh.isEmpty) throw const SesionExpiradaException();
    final Map<String, dynamic> resp;
    try {
      resp = await _dio.post('/instalador/auth/refresh', body: {
        'refreshToken': refresh,
        'deviceId': await _store.deviceId(),
      }, sinReintento: true);
    } on UnauthorizedException {
      await _store.limpiarSesion();
      _dio.clearAuthToken();
      _actual = null;
      throw const SesionExpiradaException();
    }
    final data = (resp['data'] ?? resp) as Map<String, dynamic>;
    final access = (data['accessToken'] ?? '').toString();
    final nuevoRefresh = (data['refreshToken'] ?? '').toString();
    if (access.isEmpty || nuevoRefresh.isEmpty) throw const SesionExpiradaException();
    _dio.setAuthToken(access);
    await _store.escribir(ClavesSesion.refreshToken, nuevoRefresh);
    _actual = Sesion(
      accessToken: access,
      refreshToken: nuevoRefresh,
      instaladorId: await _store.leer(ClavesSesion.instaladorId) ?? '',
      nombre: await _store.leer(ClavesSesion.nombre) ?? '',
      numeroInstalador: await _store.leer(ClavesSesion.numeroInstalador) ?? '',
      rol: await _store.leer(ClavesSesion.rol) ?? 'instalador',
    );
    await marcarActivo();
    return _actual;
  }

  /// Cierra la sesión: avisa al servidor (mejor esfuerzo) y limpia el almacén.
  Future<void> cerrar() async {
    final refresh = await _store.leer(ClavesSesion.refreshToken);
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _dio.post('/instalador/auth/logout', body: {'refreshToken': refresh}, sinReintento: true);
      } catch (_) {}
    }
    await _store.limpiarSesion();
    _dio.clearAuthToken();
    _actual = null;
  }

  // --- biometría (nivel A) ---------------------------------------------------

  Future<bool> biometriaActivada() async => (await _store.leer(ClavesSesion.biometriaActivada)) == '1';

  Future<void> setBiometriaActivada(bool v) => _store.escribir(ClavesSesion.biometriaActivada, v ? '1' : '0');

  Future<bool> invitacionMostrada() async => (await _store.leer(ClavesSesion.invitacionBiometriaMostrada)) == '1';

  Future<void> marcarInvitacionMostrada() => _store.escribir(ClavesSesion.invitacionBiometriaMostrada, '1');

  Future<void> marcarActivo() => _store.escribir(ClavesSesion.ultimoActivoMs, _ahora().millisecondsSinceEpoch.toString());

  /// true si pasó más del umbral desde la última actividad (o no hay marca).
  Future<bool> necesitaBloqueo() async {
    final raw = await _store.leer(ClavesSesion.ultimoActivoMs);
    final ms = int.tryParse(raw ?? '');
    if (ms == null) return true;
    final desde = DateTime.fromMillisecondsSinceEpoch(ms);
    return _ahora().difference(desde) >= umbralBloqueo;
  }

  Future<String?> emailGuardado() => _store.leer(ClavesSesion.email);

  /// Correo del último ingreso en este teléfono (aunque la sesión ya no exista).
  Future<String?> ultimoCorreo() => _store.leer(ClavesSesion.ultimoCorreo);
}
