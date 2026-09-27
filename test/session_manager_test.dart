import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/auth/session_manager.dart';
import 'package:ohmsafe_app/core/auth/session_store.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/error/exceptions.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';
import 'package:ohmsafe_app/features/auth/domain/entities/sesion.dart';

const _env = EnvConfig(environment: Environment.development, apiBaseUrl: 'http://x', hubspotApiKey: '', useMock: false);

/// Cliente HTTP falso: registra llamadas y responde lo programado.
class _DioFalso extends DioClient {
  _DioFalso() : super(envConfig: _env);
  final llamadas = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> Function(String path, Map<String, dynamic>? body)? respuesta;
  String? token;
  int refrescos = 0;

  @override
  void setAuthToken(String t) => token = t;
  @override
  void clearAuthToken() => token = null;

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers, bool sinReintento = false}) async {
    llamadas.add({'path': path, 'body': body});
    if (path.endsWith('/refresh')) refrescos++;
    return respuesta!(path, body);
  }
}

Sesion _sesion() => const Sesion(accessToken: 'acc1', refreshToken: 'ref1', instaladorId: '12', nombre: 'Juan', numeroInstalador: '14336', rol: 'instalador');

void main() {
  late _DioFalso dio;
  late MemorySessionStore store;
  late DateTime reloj;
  late SessionManager m;

  setUp(() {
    dio = _DioFalso();
    store = MemorySessionStore();
    reloj = DateTime(2026, 9, 27, 12);
    m = SessionManager(dio: dio, store: store, ahora: () => reloj);
  });

  test('deviceId es estable y cumple el patrón del backend', () async {
    final a = await m.deviceId();
    final b = await m.deviceId();
    expect(a, b);
    expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(a), isTrue);
    expect(generarDeviceId(), isNot(generarDeviceId()));
  });

  test('guardarLogin deja el refresh y los datos en el almacén, y el access en el cliente', () async {
    await m.guardarLogin(_sesion(), email: 'j@x.com');
    expect(await store.leer(ClavesSesion.refreshToken), 'ref1');
    expect(await store.leer(ClavesSesion.nombre), 'Juan');
    expect(dio.token, 'acc1');
    expect(await m.tieneSesionGuardada(), isTrue);
  });

  test('refrescar rota el refresh, reconstruye la sesión y es single-flight', () async {
    await m.guardarLogin(_sesion(), email: 'j@x.com');
    dio.respuesta = (path, body) async {
      expect(body!['refreshToken'], 'ref1');
      expect(body['deviceId'], await store.deviceId());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return {'success': true, 'data': {'accessToken': 'acc2', 'refreshToken': 'ref2', 'expiresIn': 900}};
    };
    final r = await Future.wait([m.refrescar(), m.refrescar(), m.refrescar()]);
    expect(dio.refrescos, 1, reason: 'tres 401 a la vez producen UN refresco');
    expect(r.every((s) => s?.accessToken == 'acc2'), isTrue);
    expect(await store.leer(ClavesSesion.refreshToken), 'ref2');
    expect(dio.token, 'acc2');
    expect(m.actual?.nombre, 'Juan');
  });

  test('401 en el refresh = sesión muerta: limpia y lanza; un fallo de red NO limpia', () async {
    await m.guardarLogin(_sesion(), email: 'j@x.com');
    dio.respuesta = (_, __) async => throw const UnauthorizedException('Sesión revocada');
    await expectLater(m.refrescar(), throwsA(isA<SesionExpiradaException>()));
    expect(await m.tieneSesionGuardada(), isFalse);
    expect(dio.token, isNull);
    expect(await store.leer(ClavesSesion.biometriaActivada), isNull); // las preferencias no se tocan aquí

    await m.guardarLogin(_sesion(), email: 'j@x.com');
    dio.respuesta = (_, __) async => throw const NetworkException();
    await expectLater(m.refrescar(), throwsA(isA<NetworkException>()));
    expect(await m.tieneSesionGuardada(), isTrue);
  });

  test('cerrar avisa al servidor con el refresh y limpia aunque el servidor falle', () async {
    await m.guardarLogin(_sesion(), email: 'j@x.com');
    dio.respuesta = (_, __) async => throw const NetworkException();
    await m.cerrar();
    expect(dio.llamadas.last['path'], '/instalador/auth/logout');
    expect(await m.tieneSesionGuardada(), isFalse);
    expect(dio.token, isNull);
    expect(await store.deviceId(), isNotEmpty, reason: 'el deviceId sobrevive al cierre');
  });

  test('necesitaBloqueo: 15 minutos en segundo plano', () async {
    expect(await m.necesitaBloqueo(), isTrue, reason: 'sin marca se bloquea');
    await m.marcarActivo();
    reloj = reloj.add(const Duration(minutes: 14));
    expect(await m.necesitaBloqueo(), isFalse);
    reloj = reloj.add(const Duration(minutes: 1));
    expect(await m.necesitaBloqueo(), isTrue);
  });

  test('biometría: preferencias e invitación una sola vez', () async {
    expect(await m.biometriaActivada(), isFalse);
    expect(await m.invitacionMostrada(), isFalse);
    await m.setBiometriaActivada(true);
    await m.marcarInvitacionMostrada();
    expect(await m.biometriaActivada(), isTrue);
    expect(await m.invitacionMostrada(), isTrue);
    await store.limpiarSesion();
    expect(await m.biometriaActivada(), isTrue, reason: 'cerrar sesión no apaga la preferencia');
  });

  test('el último correo sobrevive al cierre de sesión (el login abre en la contraseña)', () async {
    dio.respuesta = (_, __) async => {'data': {}};
    await m.guardarLogin(_sesion(), email: 'cuadrilla1@ohmsafe.com');
    await m.cerrar();
    expect(await m.emailGuardado(), isNull);
    expect(await m.ultimoCorreo(), 'cuadrilla1@ohmsafe.com');
  });
}
