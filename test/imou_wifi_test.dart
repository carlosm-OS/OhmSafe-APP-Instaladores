import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/imou/emparejador_imou.dart';
import 'package:ohmsafe_app/core/imou/imou_puente.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';

/// Conectar cámaras Imou a la Wi‑Fi desde la app de instaladores (2026-10-20, build 52).
///
/// Lo que se fija aquí es el CONTRATO con las dos mitades nativas (nombres de métodos y de
/// argumentos, orden de las llamadas) y las dos promesas de seguridad: la contraseña de la Wi‑Fi
/// sólo viaja al SDK, y al backend sólo va el NOMBRE de la red. El SC se respeta tal cual.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmparejadorImou', () {
    late _Puente puente;
    late _Repo repo;
    late EmparejadorImou emp;

    setUp(() {
      puente = _Puente()..instalar();
      repo = _Repo();
      emp = EmparejadorImou(
        repo: repo,
        ordenId: 'i99',
        puente: ImouPuente(canal: _Puente.canal, eventos: _Puente.eventos),
        cadaSondeo: const Duration(milliseconds: 10),
        topeWifi: const Duration(milliseconds: 200),
        margenWifi: const Duration(milliseconds: 50),
        topeNube: const Duration(milliseconds: 300),
      );
    });

    tearDown(() {
      emp.dispose();
      puente.quitar();
    });

    Future<void> empezar({String modo = 'smart'}) =>
        emp.empezar(serie: 'c3ce8capsfa2e62', codigo: 'L2VqC2QF', red: 'Casa Pérez', contrasena: 'secreta123', nombre: 'Cochera', modo: modo);

    test('camino feliz: sesión → sondeo → Wi‑Fi (rápido) → nube → alta con el nombre de la red', () async {
      repo.sondeos = ['unknown', 'unknown', 'online'];
      await empezar();
      expect(emp.etapa, EtapaImou.conectandoWifi);
      expect(puente.metodos.take(2).toList(), ['configure', 'wifiConfigStart']);
      expect(puente.args('configure')['host'], 'openapi-or.easy4ip.com');
      expect(puente.args('configure')['port'], 443);
      expect(puente.args('configure')['accessToken'], 'At_token');

      // La contraseña y el SC van al SDK, en los argumentos que Swift y Kotlin leen; el SC tal cual.
      final w = puente.args('wifiConfigStart');
      expect(w['serial'], 'C3CE8CAPSFA2E62');
      expect(w['verifyCode'], 'L2VqC2QF');
      expect(w['ssid'], 'Casa Pérez');
      expect(w['password'], 'secreta123');
      expect(w['mode'], 'smart');
      expect(w['hotspotPrefix'], 'DAP-');

      puente.emitir({'type': 'wifiConfig', 'serial': 'C3CE8CAPSFA2E62', 'step': 'found_on_lan', 'status': 'done'});
      await _hasta(() => emp.etapa == EtapaImou.listo);

      expect(puente.metodos, contains('wifiConfigStop'));
      expect(repo.altas, hasLength(1));
      final alta = repo.altas.single;
      expect(alta['proveedor'], 'imou');
      expect(alta['clase'], 'camara');
      expect(alta['externalId'], 'C3CE8CAPSFA2E62');
      expect(alta['codigo'], 'L2VqC2QF');
      expect(alta['red'], 'Casa Pérez');
      // Al backend NUNCA va la contraseña.
      expect(alta.values.map((v) => v.toString()), isNot(contains('secreta123')));
      expect(emp.texto, contains('Casa Pérez'));
    });

    test('el modo AP se pasa al SDK', () async {
      repo.sondeos = ['unknown'];
      await empezar(modo: 'ap');
      expect(puente.args('wifiConfigStart')['mode'], 'ap');
    });

    test('si ya está en internet no hace falta mandarle la Wi‑Fi: se registra directo', () async {
      repo.sondeos = ['online'];
      await empezar();
      await _hasta(() => emp.etapa == EtapaImou.listo);
      expect(puente.metodos, isNot(contains('wifiConfigStart')));
      expect(repo.altas, hasLength(1));
    });

    test('un error del aprovisionamiento se traduce y deja reintentar', () async {
      repo.sondeos = ['unknown', 'unknown'];
      await empezar();
      puente.emitir({'type': 'wifiConfig', 'serial': 'C3CE8CAPSFA2E62', 'step': 'failed', 'status': 'error', 'code': -3, 'error': 'IMOU_WIFI_FAILED'});
      await _hasta(() => emp.etapa == EtapaImou.error);
      expect(emp.error, copiaErrorWifi(-3));
      expect(puente.metodos, contains('wifiConfigStop'));
      expect(repo.altas, isEmpty);
      expect(emp.ocupado, isFalse);
    });

    test('si el SDK se rinde (timeout) se sondea igual y, si no llega, avisa', () async {
      repo.sondeos = List.filled(40, 'unknown');
      await empezar();
      puente.emitir({'type': 'wifiConfig', 'serial': 'C3CE8CAPSFA2E62', 'step': 'timeout', 'status': 'error', 'error': 'IMOU_WIFI_TIMEOUT'});
      await _hasta(() => emp.etapa == EtapaImou.esperandoNube);
      await _hasta(() => emp.etapa == EtapaImou.error, const Duration(seconds: 2));
      expect(emp.error, copiaNubeTiempo);
    });

    test('si el SDK se queda callado, al acabar el plazo se sondea igual', () async {
      repo.sondeos = ['unknown', 'unknown', 'online'];
      await empezar();
      await _hasta(() => emp.etapa == EtapaImou.listo, const Duration(seconds: 2));
      expect(repo.altas, hasLength(1));
    });

    test('DV1001 al registrar se explica (cámara de otra cuenta)', () async {
      repo.sondeos = ['online'];
      repo.errorAlta = 'Imou DV1001: device bound by other';
      await empezar();
      await _hasta(() => emp.etapa == EtapaImou.error);
      expect(emp.error, contains('otra cuenta de Imou'));
    });

    test('cancelar para el SDK y vuelve al reposo', () async {
      repo.sondeos = ['unknown', 'unknown'];
      await empezar();
      await emp.cancelar();
      expect(emp.etapa, EtapaImou.inactivo);
      expect(puente.metodos.last, 'wifiConfigStop');
    });

    test('sin sesión del backend no se toca el SDK', () async {
      repo.sinSesion = true;
      await empezar();
      expect(emp.etapa, EtapaImou.error);
      expect(puente.metodos, isEmpty);
    });

    test('sin el puente nativo (iOS sin SDK todavía) el error es claro', () async {
      puente.quitar();
      await empezar();
      expect(emp.etapa, EtapaImou.error);
      expect(emp.error, contains('Actualízala'));
      puente.instalar(); // para que tearDown no falle
    });
  });
}

Future<void> _hasta(bool Function() cond, [Duration tope = const Duration(seconds: 1)]) async {
  final fin = DateTime.now().add(tope);
  while (!cond()) {
    if (DateTime.now().isAfter(fin)) fail('se agotó la espera');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Puente falso: contesta como Swift/Kotlin y permite emitir eventos.
class _Puente {
  static const canal = MethodChannel('ohmsafe/imou');
  static const eventos = EventChannel('ohmsafe/imou/events');
  final metodos = <String>[];
  final _args = <String, Map<Object?, Object?>>{};
  StreamController<Object?> _ctrl = StreamController<Object?>.broadcast();

  Map<Object?, Object?> args(String m) => _args[m] ?? const {};

  void emitir(Map<String, Object?> e) => _ctrl.add(e);

  void instalar() {
    if (_ctrl.isClosed) _ctrl = StreamController<Object?>.broadcast();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(canal, (call) async {
      metodos.add(call.method);
      if (call.arguments is Map) _args[call.method] = (call.arguments as Map).cast<Object?, Object?>();
      switch (call.method) {
        case 'currentSsid':
          return 'Casa Pérez';
        default:
          return true;
      }
    });
    m.setMockStreamHandler(eventos, MockStreamHandler.inline(onListen: (_, sink) => _ctrl.stream.listen(sink.success)));
  }

  void quitar() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(canal, null);
    m.setMockStreamHandler(eventos, null);
    _ctrl.close();
  }
}

class _Repo implements OrdenesRepository {
  final altas = <Map<String, dynamic>>[];
  List<String> sondeos = [];
  int _sondeo = 0;
  bool sinSesion = false;
  String? errorAlta;

  @override
  Future<Result<Map<String, dynamic>>> imouSesion(String id) async {
    if (sinSesion) return const FailureResult(ServerFailure('Imou no está configurado en este servidor'));
    return Success({'provider': 'imou', 'accessToken': 'At_token', 'host': 'openapi-or.easy4ip.com', 'port': 443});
  }

  @override
  Future<Result<Map<String, dynamic>>> imouSondeo(String id, String serie) async {
    final s = _sondeo < sondeos.length ? sondeos[_sondeo++] : (sondeos.isEmpty ? 'unknown' : sondeos.last);
    return Success({'serie': serie, 'state': s, if (s == 'unknown') 'providerCode': 'DV1002'});
  }

  @override
  Future<Result<Map<String, dynamic>>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category}) async {
    if (errorAlta != null) return FailureResult(ServerFailure(errorAlta!));
    altas.add({'proveedor': proveedor, 'clase': clase, 'externalId': externalId, 'nombre': nombre, 'codigo': codigo, 'red': red});
    return Success({'dispositivo': {'id': 'cam1', 'name': nombre}});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
