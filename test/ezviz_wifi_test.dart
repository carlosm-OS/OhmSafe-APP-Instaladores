import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/ezviz/emparejador_ezviz.dart';
import 'package:ohmsafe_app/core/ezviz/ezviz_puente.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/utils/etiqueta_ezviz.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';

/// Conectar cámaras EZVIZ a la Wi‑Fi desde la app de instaladores (2026-10-17).
///
/// Lo que se fija aquí es el CONTRATO con las dos mitades nativas (nombres de métodos y de
/// argumentos, orden de las llamadas) y las dos promesas de seguridad: la contraseña de la Wi‑Fi
/// sólo viaja al SDK, y al backend sólo va el NOMBRE de la red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EtiquetaEzviz.leer', () {
    test('la etiqueta real: url, serie, código y modelo en líneas', () {
      final e = EtiquetaEzviz.leer('www.ezvizlife.com\nD12345678\nABCDEF\nCS-C3-21PPFR\n')!;
      expect(e.serie, 'D12345678');
      expect(e.codigo, 'ABCDEF');
      expect(e.modelo, 'CS-C3-21PPFR');
      expect(e.toString(), isNot(contains('ABCDEF')));
    });

    test('pares con nombre y enlace con query', () {
      expect(EtiquetaEzviz.leer('SN:D12345678;CODE:ABCDEF')!.codigo, 'ABCDEF');
      final u = EtiquetaEzviz.leer('https://x.ezviz.com/qr?sn=d12345678&code=abcdef')!;
      expect(u.serie, 'D12345678');
      expect(u.codigo, 'ABCDEF');
    });

    test('sólo la serie: devuelve la serie y el código queda vacío para escribirlo', () {
      final e = EtiquetaEzviz.leer('D12345678')!;
      expect(e.serie, 'D12345678');
      expect(e.codigo, '');
    });

    test('un marcador o un QR de otra cosa no se confunde con una serie', () {
      expect(EtiquetaEzviz.leer('EZVIZLIFE'), isNull);
      expect(EtiquetaEzviz.leer('https://ohmsafe.com'), isNull);
      expect(EtiquetaEzviz.leer('OS-OBV01-0026'), isNull);
    });
  });

  group('EmparejadorEzviz', () {
    late _Puente puente;
    late _Repo repo;
    late EmparejadorEzviz emp;

    setUp(() {
      puente = _Puente()..instalar();
      repo = _Repo();
      emp = EmparejadorEzviz(
        repo: repo,
        ordenId: 'i99',
        puente: EzvizPuente(canal: _Puente.canal, eventos: _Puente.eventos),
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

    Future<void> empezar() => emp.empezar(serie: 'd12345678', codigo: 'abcdef', red: 'Casa Pérez', contrasena: 'secreta123', nombre: 'Cochera');

    test('camino feliz: sesión → sondeo → Wi‑Fi → nube → alta con el nombre de la red', () async {
      puente.sondeos = ['not_found', 'not_found', 'online_unbound'];
      await empezar();
      expect(emp.etapa, EtapaEzviz.conectandoWifi);
      expect(puente.metodos.take(4).toList(), ['configure', 'setSession', 'probe', 'probe']);
      expect(puente.args('configure')['appKey'], 'llave');
      expect(puente.args('setSession')['accessToken'], 'ra.token');

      // La contraseña y el código van al SDK, en los argumentos que Swift y Kotlin leen.
      final w = puente.args('wifiConfigStart');
      expect(w['serial'], 'D12345678');
      expect(w['verifyCode'], 'ABCDEF');
      expect(w['ssid'], 'Casa Pérez');
      expect(w['password'], 'secreta123');
      expect(w['mode'], 'ap');
      expect(w['hotspotPrefix'], 'EZVIZ');

      puente.emitir({'type': 'wifiConfig', 'serial': 'D12345678', 'step': 'registered', 'status': 'done'});
      await _hasta(() => emp.etapa == EtapaEzviz.listo);

      expect(puente.metodos, contains('wifiConfigStop'));
      expect(repo.altas, hasLength(1));
      final alta = repo.altas.single;
      expect(alta['proveedor'], 'ezviz');
      expect(alta['clase'], 'camara');
      expect(alta['externalId'], 'D12345678');
      expect(alta['codigo'], 'ABCDEF');
      expect(alta['red'], 'Casa Pérez');
      // Al backend NUNCA va la contraseña.
      expect(alta.values.map((v) => v.toString()), isNot(contains('secreta123')));
      expect(emp.texto, contains('Casa Pérez'));
    });

    test('si la cámara ya es de otra cuenta se para antes de tocar la Wi‑Fi', () async {
      puente.sondeos = ['bound_elsewhere'];
      await empezar();
      expect(emp.etapa, EtapaEzviz.error);
      expect(emp.error, copiaOtraCuenta);
      expect(puente.metodos, isNot(contains('wifiConfigStart')));
      expect(repo.altas, isEmpty);
    });

    test('si ya está en internet no hace falta mandarle la Wi‑Fi: se registra directo', () async {
      puente.sondeos = ['online_unbound'];
      await empezar();
      await _hasta(() => emp.etapa == EtapaEzviz.listo);
      expect(puente.metodos, isNot(contains('wifiConfigStart')));
      expect(repo.altas, hasLength(1));
    });

    test('si el SDK no sabe el estado, decide el backend', () async {
      puente.sondeos = ['unknown'];
      repo.sondeoBackend = 'bound_here';
      await empezar();
      await _hasta(() => emp.etapa == EtapaEzviz.listo);
      expect(repo.sondeos, hasLength(1));
      expect(repo.altas, hasLength(1));
    });

    test('un error del aprovisionamiento se traduce y deja reintentar', () async {
      puente.sondeos = ['not_found', 'not_found'];
      await empezar();
      puente.emitir({'type': 'wifiConfig', 'serial': 'D12345678', 'step': 'failed', 'status': 'error', 'code': 120, 'error': 'EZVIZ_WIFI_FAILED'});
      await _hasta(() => emp.etapa == EtapaEzviz.error);
      expect(emp.error, copiaErrorWifi(120));
      expect(puente.metodos, contains('wifiConfigStop'));
      expect(repo.altas, isEmpty);
      expect(emp.ocupado, isFalse);
    });

    test('si se agota el plazo de la Wi‑Fi se sondea igual y, si no llega, avisa', () async {
      puente.sondeos = ['not_found', 'not_found', 'not_found', 'not_found', 'not_found', 'not_found', 'not_found', 'not_found', 'not_found', 'not_found'];
      await empezar();
      await _hasta(() => emp.etapa == EtapaEzviz.esperandoNube, const Duration(seconds: 2));
      await _hasta(() => emp.etapa == EtapaEzviz.error, const Duration(seconds: 2));
      expect(emp.error, copiaNubeTiempo);
    });

    test('cancelar para el SDK y vuelve al reposo', () async {
      puente.sondeos = ['not_found', 'not_found'];
      await empezar();
      await emp.cancelar();
      expect(emp.etapa, EtapaEzviz.inactivo);
      expect(puente.metodos.last, 'wifiConfigStop');
    });

    test('sin sesión del backend no se toca el SDK', () async {
      repo.sinSesion = true;
      await empezar();
      expect(emp.etapa, EtapaEzviz.error);
      expect(puente.metodos, isEmpty);
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
  static const canal = MethodChannel('ohmsafe/ezviz');
  static const eventos = EventChannel('ohmsafe/ezviz/events');
  final metodos = <String>[];
  final _args = <String, Map<Object?, Object?>>{};
  List<String> sondeos = [];
  int _sondeo = 0;
  final _ctrl = StreamController<Object?>.broadcast();

  Map<Object?, Object?> args(String m) => _args[m] ?? const {};

  void emitir(Map<String, Object?> e) => _ctrl.add(e);

  void instalar() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(canal, (call) async {
      metodos.add(call.method);
      if (call.arguments is Map) _args[call.method] = (call.arguments as Map).cast<Object?, Object?>();
      switch (call.method) {
        case 'probe':
          final s = _sondeo < sondeos.length ? sondeos[_sondeo++] : (sondeos.isEmpty ? 'unknown' : sondeos.last);
          return {'state': s, 'code': 0, 'supportAP': 2, 'supportSoundWave': 0, 'deviceHotSpot': 0, 'model': 'CS-C3'};
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
  final sondeos = <String>[];
  String sondeoBackend = 'not_found';
  bool sinSesion = false;

  @override
  Future<Result<Map<String, dynamic>>> wifiSesion(String id, String proveedor) async {
    if (sinSesion) return const FailureResult(ServerFailure('Las cámaras no están disponibles en este ambiente'));
    return Success({'provider': proveedor, 'appKey': 'llave', 'areaDomain': 'https://iusopen.ezvizlife.com', 'region': 'na', 'accessToken': 'ra.token', 'expiresAt': '2026-10-24T00:00:00Z'});
  }

  @override
  Future<Result<Map<String, dynamic>>> ezvizSondeo(String id, String serie) async {
    sondeos.add(serie);
    return Success({'state': sondeoBackend});
  }

  @override
  Future<Result<Map<String, dynamic>>> dispositivoWifiAgregar(String id, {required String proveedor, required String clase, required String externalId, required String nombre, String? codigo, String? red, String? tipo, String? productId, String? category, String? serie}) async {
    altas.add({'proveedor': proveedor, 'clase': clase, 'externalId': externalId, 'nombre': nombre, 'codigo': codigo, 'red': red});
    return Success({'dispositivo': {'id': 'cam1', 'name': nombre}});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
