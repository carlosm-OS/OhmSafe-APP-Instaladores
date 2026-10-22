import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/core/wifi/redes_wifi.dart';
import 'package:ohmsafe_app/core/wifi/wifi_casa_local.dart';
import 'package:ohmsafe_app/features/ordenes/data/models/orden_model.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/service_steps_screen.dart';
import 'package:ohmsafe_app/screens/wifi_casa_screen.dart';

/// Paso «Wi‑Fi de la casa» (Carlos, 2026-10-22): opcional, antes de «Agregar dispositivos»; la
/// contraseña sólo en el teléfono (opción A); al servidor sólo va el nombre de la red.
void main() {
  group('WifiCasaLocal', () {
    test('guarda por intervención, lee y borra', () async {
      final l = WifiCasaLocal(almacen: _Memoria());
      await l.guardar('i76', const WifiCasa(red: 'Casa Carlos', contrasena: 'secreta123'));
      final w = await l.leer('i76');
      expect(w?.red, 'Casa Carlos');
      expect(w?.contrasena, 'secreta123');
      expect(await l.leer('i77'), isNull);
      await l.borrar('i76');
      expect(await l.leer('i76'), isNull);
    });

    test('vence a las 24 h y se borra sola', () async {
      var ahora = DateTime.utc(2026, 10, 22, 9);
      final mem = _Memoria();
      final l = WifiCasaLocal(almacen: mem, ahora: () => ahora);
      await l.guardar('i76', const WifiCasa(red: 'Casa', contrasena: 'x'));
      ahora = ahora.add(const Duration(hours: 25));
      expect(await l.leer('i76'), isNull);
      expect(mem.datos, isEmpty);
    });
  });

  test('la orden trae el estado del paso desde el servidor', () {
    final o = OrdenModel.fromJson({'id': 'i76', 'wifiCasa': {'estado': 'lista', 'red': 'Casa Carlos'}});
    expect(o.wifiCasaEstado, 'lista');
    expect((o.toTicketMap()['wifiCasa'] as Map)['red'], 'Casa Carlos');
    expect(OrdenModel.fromJson({'id': 'i1'}).wifiCasaEstado, 'pendiente');
  });

  group('pantalla', () {
    Future<void> montar(WidgetTester t, _Repo repo, WifiCasaLocal local, {Map<String, dynamic>? wifiCasa}) async {
      t.view.physicalSize = const Size(1206, 3200);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(AppStateProvider(
        notifier: AppState(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: WifiCasaScreen(
            ticket: {'id': 'i76', 'wifiCasa': wifiCasa ?? {'estado': 'pendiente', 'red': ''}},
            repo: repo,
            local: local,
            listador: _SinLista(),
            leerRedActual: () async => 'Casa Carlos',
          ),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('guardar manda sólo el nombre al servidor y deja la contraseña en el teléfono', (t) async {
      final repo = _Repo();
      final local = WifiCasaLocal(almacen: _Memoria());
      await montar(t, repo, local);
      expect(find.text('Wi‑Fi de la casa'), findsWidgets);
      await t.enterText(find.widgetWithText(TextField, 'Contraseña de la Wi‑Fi'), 'secreta123');
      await t.tap(find.text('Guardar Wi‑Fi de la casa'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.llamadas, [('i76', 'Casa Carlos', false)]);
      final w = await t.runAsync(() => local.leer('i76'));
      expect(w?.contrasena, 'secreta123');
    });

    testWidgets('omitir avisa al servidor y no deja nada en el teléfono', (t) async {
      final repo = _Repo();
      final mem = _Memoria();
      final local = WifiCasaLocal(almacen: mem);
      await t.runAsync(() => local.guardar('i76', const WifiCasa(red: 'Vieja', contrasena: 'x')));
      await montar(t, repo, local);
      await t.tap(find.text('Omitir: esta casa no la necesita'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.llamadas, [('i76', null, true)]);
      expect(mem.datos, isEmpty);
    });
  });

  testWidgets('en los pasos, «Agregar dispositivos» y el cierre esperan a que la Wi‑Fi quede lista u omitida', (t) async {
    t.view.physicalSize = const Size(1206, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // La fuente de pruebas es más ancha que la real y desborda la barra inferior (en el teléfono cabe).
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final texto = d.toString();
      if (texto.contains('app_bottom_nav.dart') && texto.contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    Future<void> pasos(String estado) async {
      final ticket = OrdenModel.fromJson({
        'id': 'i76', 'tipo': 'Instalación', 'titulo': 'Instalación Plan Hogar', 'wifiCasa': {'estado': estado, 'red': estado == 'lista' ? 'Casa Carlos' : null},
      }).toTicketMap();
      await t.pumpWidget(AppStateProvider(
        notifier: AppState(),
        child: MaterialApp(theme: AppTheme.light, home: ServiceStepsScreen(key: ValueKey(estado), ticket: ticket, pasoInicial: 4)),
      ));
      await t.pump(const Duration(seconds: 5));
    }

    await pasos('pendiente');
    expect(find.text('Wi‑Fi de la casa'), findsOneWidget);
    expect(find.text('Opcional · para sensores, cámaras y el OhmBox'), findsOneWidget);
    expect(find.text('6'), findsOneWidget, reason: 'el cierre ahora es el paso 6');

    await pasos('lista');
    expect(find.text('Lista: «Casa Carlos» · toca para cambiarla'), findsOneWidget);

    await pasos('omitida');
    expect(find.text('Omitido · tócalo si la casa sí la necesita'), findsOneWidget);
  });
}

class _Memoria implements AlmacenSeguro {
  final datos = <String, String>{};
  @override
  Future<String?> leer(String llave) async => datos[llave];
  @override
  Future<void> escribir(String llave, String valor) async => datos[llave] = valor;
  @override
  Future<void> borrar(String llave) async => datos.remove(llave);
}

class _SinLista implements ListadorRedes {
  @override
  bool get puedeListar => false;
  @override
  Future<ResultadoEscaneo> escanear() async => throw UnimplementedError();
}

class _Repo implements OrdenesRepository {
  final llamadas = <(String, String?, bool)>[];

  @override
  Future<Result<Map<String, dynamic>>> wifiCasaGuardar(String id, {String? red, bool omitir = false}) async {
    llamadas.add((id, red, omitir));
    return Success(omitir ? {'estado': 'omitida', 'red': null} : {'estado': 'lista', 'red': red});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
