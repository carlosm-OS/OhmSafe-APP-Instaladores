// Barra de progreso global (2026-10-15, Carlos: «hay tiempos de espera donde parece que la app se
// trabó»): toda petición al backend cuenta como espera visible, los sondeos de fondo no, y la barra
// sólo aparece si la espera pasa de 250 ms.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/error/exceptions.dart';
import 'package:ohmsafe_app/core/network/actividad.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/widgets/barra_progreso_global.dart';

const _env = EnvConfig(environment: Environment.development, apiBaseUrl: 'http://x', hubspotApiKey: '', useMock: false);

/// Transporte simulado que contesta cuando la prueba lo suelta.
class _Dio extends DioClient {
  _Dio() : super(envConfig: _env);
  final respuestas = <Completer<Map<String, dynamic>>>[];
  bool rechazar = false;

  @override
  Future<Map<String, dynamic>> enviar(String method, String path, {Map<String, dynamic>? body, Map<String, String>? headers}) {
    if (rechazar) {
      rechazar = false;
      throw const UnauthorizedException('vencido');
    }
    final c = Completer<Map<String, dynamic>>();
    respuestas.add(c);
    return c.future;
  }
}

double _opacidad(WidgetTester t) => t.widget<AnimatedOpacity>(find.byKey(const Key('barra-progreso-global'))).opacity;

Widget _app() => MaterialApp(
      theme: AppTheme.light,
      builder: (_, child) => BarraProgresoGlobal(child: child!),
      home: const Scaffold(body: Text('pantalla')),
    );

void main() {
  tearDown(() => expect(Actividad.pendientes.value, 0, reason: 'ninguna espera debe quedar colgada'));

  test('DioClient cuenta cada petición mientras dura, también con el reintento por 401', () async {
    final dio = _Dio()..onUnauthorized = () async => true;
    dio.rechazar = true;
    final f = dio.get('/instalador/ordenes');
    await Future<void>.delayed(Duration.zero);
    expect(Actividad.pendientes.value, 1);
    dio.respuestas.single.complete({'success': true});
    await f;
    expect(Actividad.pendientes.value, 0);
  });

  test('un error también libera la espera', () async {
    final dio = _Dio();
    final f = dio.post('/x', body: {});
    await Future<void>.delayed(Duration.zero);
    dio.respuestas.single.completeError(const NetworkException());
    await expectLater(f, throwsA(isA<NetworkException>()));
  });

  test('enSilencio: los sondeos de fondo no cuentan, aunque la petición salga después de un await', () async {
    final dio = _Dio();
    final f = Actividad.enSilencio(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return dio.get('/estado');
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dio.respuestas, hasLength(1));
    expect(Actividad.pendientes.value, 0);
    dio.respuestas.single.complete({});
    await f;
  });

  testWidgets('la barra aparece si la espera pasa de 250 ms, avisa si se alarga y se va al terminar', (t) async {
    await t.pumpWidget(_app());
    expect(_opacidad(t), 0);

    final c = Completer<void>();
    final f = Actividad.seguir(() => c.future);
    await t.pump(const Duration(milliseconds: 100));
    expect(_opacidad(t), 0, reason: 'aún no: una respuesta rápida no parpadea');
    await t.pump(const Duration(milliseconds: 200));
    expect(_opacidad(t), 1);
    expect(find.text('Sigue cargando… la señal está lenta'), findsNothing);

    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Sigue cargando… la señal está lenta'), findsOneWidget);

    c.complete();
    await f;
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(_opacidad(t), 0);
    expect(find.text('Sigue cargando… la señal está lenta'), findsNothing);
    expect(find.text('pantalla'), findsOneWidget);
  });

  testWidgets('una espera corta nunca enseña la barra', (t) async {
    await t.pumpWidget(_app());
    final c = Completer<void>();
    final f = Actividad.seguir(() => c.future);
    await t.pump(const Duration(milliseconds: 150));
    c.complete();
    await f;
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(_opacidad(t), 0);
    }
  });

  testWidgets('la barra no estorba: los toques pasan a la pantalla', (t) async {
    var toques = 0;
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (_, child) => BarraProgresoGlobal(child: child!),
      home: Scaffold(body: Align(alignment: Alignment.topCenter, child: TextButton(onPressed: () => toques++, child: const Text('tocar')))),
    ));
    final c = Completer<void>();
    final f = Actividad.seguir(() => c.future);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('tocar'));
    expect(toques, 1);
    c.complete();
    await f;
    await t.pump(const Duration(seconds: 1));
  });
}
