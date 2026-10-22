import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/tuya/emparejador_tuya.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/core/tuya/tuya_puente.dart';
import 'package:ohmsafe_app/core/utils/serie_qr.dart';
import 'package:ohmsafe_app/core/wifi/redes_wifi.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/conectar_tuya_wifi_screen.dart';

/// Emparejar equipos Tuya desde la app de instaladores con el token de nube de la casa (2026-10-17).
///
/// Lo que se fija: el orden (token del backend → configure → pairStart con ESE token), que la
/// contraseña sólo va al SDK, que el backend es quien confirma que el equipo entró (aunque el SDK
/// no avise), y que al registrar va el nombre de la red y nunca la contraseña.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Puente puente;
  late _Repo repo;
  late EmparejadorTuya emp;

  setUp(() {
    puente = _Puente()..instalar();
    repo = _Repo();
    emp = EmparejadorTuya(
      repo: repo,
      ordenId: 'i99',
      puente: TuyaPuente(canal: _Puente.canal, eventos: _Puente.eventos, appKey: 'llave-prueba', appSecret: 'secreto-prueba'),
      zonaHoraria: () async => 'America/Monterrey',
      cadaSondeo: const Duration(milliseconds: 10),
      topeEmparejar: const Duration(milliseconds: 200),
      margen: const Duration(milliseconds: 50),
      busquedaBluetooth: const Duration(milliseconds: 80),
      permisoBluetooth: () async => true,
    );
  });

  tearDown(() {
    emp.dispose();
    puente.quitar();
  });

  Future<void> empezar({String modo = 'EZ'}) =>
      emp.empezar(clase: 'sensor', tipo: 'door', nombre: 'Puerta principal', red: 'Casa Pérez', contrasena: 'secreta123', modo: modo);

  test('token del backend → configure → pairStart con ese token; el SDK avisa y se registra', () async {
    await empezar();
    expect(emp.etapa, EtapaTuya.emparejando);
    expect(repo.tokens, [('EZ', 'America/Monterrey')]);
    expect(puente.metodos, ['configure', 'pairStart']);
    expect(puente.args('configure'), {'appKey': 'llave-prueba', 'appSecret': 'secreto-prueba'});
    final p = puente.args('pairStart');
    expect(p['token'], 'AZtok123sec');
    expect(p['ssid'], 'Casa Pérez');
    expect(p['password'], 'secreta123');
    expect(p['mode'], 'EZ');

    puente.emitir({'type': 'pairDone', 'devId': 'eb001', 'name': 'Door Sensor', 'productId': 'p1', 'category': 'mcs'});
    await _hasta(() => emp.etapa == EtapaTuya.listo);

    expect(puente.metodos, contains('pairCancel'));
    final alta = repo.altas.single;
    expect(alta['proveedor'], 'tuya');
    expect(alta['clase'], 'sensor');
    expect(alta['externalId'], 'eb001');
    expect(alta['tipo'], 'door');
    expect(alta['productId'], 'p1');
    expect(alta['category'], 'mcs');
    expect(alta['red'], 'Casa Pérez');
    expect(alta.values.map((v) => v.toString()), isNot(contains('secreta123')));
  });

  test('si el SDK no avisa, el sondeo del backend confirma que el equipo entró', () async {
    repo.resultado = {'successDevices': [], 'errorDevices': []};
    await empezar(modo: 'AP');
    repo.resultado = {
      'successDevices': [
        {'id': 'eb002', 'category': 'pir'},
      ],
      'errorDevices': [],
    };
    await _hasta(() => emp.etapa == EtapaTuya.listo);
    expect(repo.sondeos, contains('tok123'));
    expect(repo.altas.single['externalId'], 'eb002');
    expect(repo.altas.single['category'], 'pir');
  });

  test('si nadie ve el equipo se rinde con el texto de 2.4 GHz y deja reintentar', () async {
    await empezar();
    await _hasta(() => emp.etapa == EtapaTuya.error, const Duration(seconds: 2));
    expect(emp.error, copiaTiempo);
    expect(emp.ocupado, isFalse);
    expect(repo.altas, isEmpty);
  });

  test('la casa sin cuenta Tuya (409) se explica: el cliente debe entrar a GO', () async {
    repo.sinUid = true;
    await empezar();
    expect(emp.etapa, EtapaTuya.error);
    expect(emp.error, contains('OhmSafe GO'));
    expect(puente.metodos, isEmpty);
  });

  test('un pairError del SDK no tumba: se sigue esperando al backend', () async {
    await empezar();
    puente.emitir({'type': 'pairError', 'code': 'TUYA_PAIR_FAILED', 'message': 'sin sesión'});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(emp.etapa, EtapaTuya.emparejando);
    repo.resultado = {
      'successDevices': [
        {'id': 'eb003'},
      ],
      'errorDevices': [],
    };
    await _hasta(() => emp.etapa == EtapaTuya.listo);
  });

  test('la serie de la etiqueta viaja al registrar y la tarjeta tiene lo que dijo la nube', () async {
    await emp.empezar(clase: 'camara', nombre: 'Cochera', red: 'Casa Pérez', contrasena: 'x', serie: ' AB12CD ');
    puente.emitir({'type': 'pairDone', 'devId': 'vd77', 'name': 'Smart Camera', 'productId': 'p9', 'category': 'sp'});
    await _hasta(() => emp.etapa == EtapaTuya.listo);
    expect(repo.altas.single['serie'], 'AB12CD');
    expect(emp.devId, 'vd77');
    expect(emp.serie, 'AB12CD');
    expect(emp.nombreDeFabrica, 'Smart Camera');
    expect(emp.nombre, 'Cochera');
  });

  test('sin serie no se manda nada', () async {
    await empezar();
    puente.emitir({'type': 'pairDone', 'devId': 'eb009'});
    await _hasta(() => emp.etapa == EtapaTuya.listo);
    expect(repo.altas.single['serie'], isNull);
  });

  test('serieDeEtiqueta: serie sola, enlace con ?sn=, enlace con la serie al final', () {
    expect(serieDeEtiqueta(' ab 12 cd '), 'AB12CD');
    expect(serieDeEtiqueta('https://fabricante.example/q?sn=xy99&x=1'), 'XY99');
    expect(serieDeEtiqueta('https://fabricante.example/d/K7Q2'), 'K7Q2');
    expect(serieDeEtiqueta('   '), '');
  });

  testWidgets('al conectar, la pantalla muestra «Equipo conectado» con serie e ID', (t) async {
    t.view.physicalSize = const Size(1206, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      AppStateProvider(
        notifier: AppState(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: ConectarTuyaWifiScreen(ordenId: 'i99', clase: 'camara', emparejador: emp, listador: _SinLista()),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Número de serie (opcional)'), findsOneWidget);
    await t.runAsync(() async {
      await emp.empezar(clase: 'camara', nombre: 'Cochera', red: 'Casa Pérez', contrasena: 'x', serie: 'AB12CD');
      puente.emitir({'type': 'pairDone', 'devId': 'vd77', 'name': 'Smart Camera'});
      await _hasta(() => emp.etapa == EtapaTuya.listo);
    });
    await t.pump();
    expect(find.text('Equipo conectado'), findsOneWidget);
    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.text('vd77'), findsOneWidget);
    expect(find.text('Smart Camera'), findsOneWidget);
    expect(find.text('No es este equipo'), findsOneWidget);
  });

  test('Bluetooth: encuentra un equipo combo y le pasa la red con el token de la casa', () async {
    // Con Bluetooth, `empezar` espera a que aparezca el equipo: no se espera aquí.
    unawaited(emp.empezar(clase: 'sensor', tipo: 'door', nombre: 'Puerta', red: 'Casa Pérez', contrasena: 'secreta123', modo: 'BLE'));
    await _hasta(() => puente.metodos.contains('bleScanStart'));
    expect(repo.tokens.first.$1, 'BLE');
    await Future<void>.delayed(const Duration(milliseconds: 20)); // el canal de eventos ya escucha
    puente.emitir({'type': 'bleFound', 'uuid': 'u-solo-ble', 'productId': 'p0', 'combo': false});
    puente.emitir({'type': 'bleFound', 'uuid': 'u-combo', 'productId': 'p1', 'combo': true});
    await _hasta(() => puente.metodos.contains('pairStartBle'));
    final a = puente.args('pairStartBle');
    expect(a['uuid'], 'u-combo');
    expect(a['token'], 'AZtok123sec');
    expect(a['ssid'], 'Casa Pérez');
    expect(a['homeId'], '1');
    expect(emp.modoUsado, 'BLE');
    puente.emitir({'type': 'pairDone', 'devId': 'eb777', 'name': 'Door', 'productId': 'p1', 'category': 'mcs'});
    await _hasta(() => emp.etapa == EtapaTuya.listo);
    expect(repo.altas.single['externalId'], 'eb777');
  });

  test('Bluetooth: si no ve un equipo combo, sigue solo en modo rápido con un token nuevo', () async {
    // Con Bluetooth, `empezar` espera a que aparezca el equipo: no se espera aquí.
    unawaited(emp.empezar(clase: 'sensor', tipo: 'door', nombre: 'Puerta', red: 'Casa Pérez', contrasena: 'secreta123', modo: 'BLE'));
    await _hasta(() => puente.metodos.contains('bleScanStart'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    puente.emitir({'type': 'bleScanEnd'});
    await _hasta(() => puente.metodos.contains('pairStart'));
    expect(repo.tokens.map((t) => t.$1), ['BLE', 'EZ']);
    expect(puente.args('pairStart')['mode'], 'EZ');
    expect(emp.modoUsado, 'EZ');
    expect(puente.metodos, isNot(contains('pairStartBle')));
  });

  test('Bluetooth sin permiso: va directo al modo rápido', () async {
    final sinPermiso = EmparejadorTuya(
      repo: repo,
      ordenId: 'i99',
      puente: TuyaPuente(canal: _Puente.canal, eventos: _Puente.eventos, appKey: 'k', appSecret: 's'),
      zonaHoraria: () async => null,
      cadaSondeo: const Duration(milliseconds: 10),
      topeEmparejar: const Duration(milliseconds: 200),
      margen: const Duration(milliseconds: 50),
      permisoBluetooth: () async => false,
    );
    addTearDown(sinPermiso.dispose);
    await sinPermiso.empezar(clase: 'camara', nombre: 'Cochera', red: 'Casa', contrasena: 'x', modo: 'BLE');
    await _hasta(() => puente.metodos.contains('pairStart'));
    expect(puente.metodos, isNot(contains('bleScanStart')));
    expect(sinPermiso.modoUsado, 'EZ');
  });

  test('cancelar para el SDK y vuelve al reposo', () async {
    await empezar();
    await emp.cancelar();
    expect(emp.etapa, EtapaTuya.inactivo);
    expect(puente.metodos.last, 'pairCancel');
  });
}

Future<void> _hasta(bool Function() cond, [Duration tope = const Duration(seconds: 1)]) async {
  final fin = DateTime.now().add(tope);
  while (!cond()) {
    if (DateTime.now().isAfter(fin)) fail('se agotó la espera');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Puente {
  static const canal = MethodChannel('ohmsafe/tuya');
  static const eventos = EventChannel('ohmsafe/tuya/events');
  final metodos = <String>[];
  final _args = <String, Map<Object?, Object?>>{};
  final _ctrl = StreamController<Object?>.broadcast();

  Map<Object?, Object?> args(String m) => _args[m] ?? const {};
  void emitir(Map<String, Object?> e) => _ctrl.add(e);

  void instalar() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(canal, (call) async {
      metodos.add(call.method);
      if (call.arguments is Map) _args[call.method] = (call.arguments as Map).cast<Object?, Object?>();
      return call.method == 'currentSsid' ? 'Casa Pérez' : true;
    });
    m.setMockStreamHandler(
      eventos,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          _ctrl.stream.listen(sink.success);
        },
      ),
    );
  }

  void quitar() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(canal, null);
    m.setMockStreamHandler(eventos, null);
    _ctrl.close();
  }
}

class _Repo implements OrdenesRepository {
  final tokens = <(String, String?)>[];
  final sondeos = <String>[];
  final altas = <Map<String, dynamic>>[];
  Map<String, dynamic> resultado = {'successDevices': [], 'errorDevices': []};
  bool sinUid = false;

  @override
  Future<Result<Map<String, dynamic>>> tuyaToken(String id, {required String modo, String? zonaHoraria}) async {
    tokens.add((modo, zonaHoraria));
    if (sinUid) return const FailureResult(ServerFailure('La casa todavía no tiene cuenta Tuya', 'TUYA_UID_DESCONOCIDO'));
    return Success({'provider': 'tuya', 'authToken': 'AZtok123sec', 'region': 'AZ', 'token': 'tok123', 'secret': 'sec', 'homeId': '1'});
  }

  @override
  Future<Result<Map<String, dynamic>>> tuyaTokenResultado(String id, String token) async {
    sondeos.add(token);
    return Success(resultado);
  }

  @override
  Future<Result<Map<String, dynamic>>> dispositivoWifiAgregar(
    String id, {
    required String proveedor,
    required String clase,
    required String externalId,
    required String nombre,
    String? codigo,
    String? red,
    String? tipo,
    String? productId,
    String? category,
    String? serie,
  }) async {
    altas.add({
      'proveedor': proveedor,
      'clase': clase,
      'externalId': externalId,
      'nombre': nombre,
      'codigo': codigo,
      'red': red,
      'tipo': tipo,
      'productId': productId,
      'category': category,
      'serie': serie,
    });
    return Success({
      'dispositivo': {'id': 's1', 'name': nombre},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SinLista implements ListadorRedes {
  @override
  bool get puedeListar => false;
  @override
  Future<ResultadoEscaneo> escanear() async => throw UnimplementedError();
}
