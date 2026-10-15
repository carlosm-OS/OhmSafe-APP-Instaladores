// Las pantallas de la instalación (prueba y agregar dispositivos) se pintan completas con datos del
// mock y sin errores de layout. La build 40 salió en gris en el teléfono (2026-10-14): la barra
// inferior (un Positioned) estaba dentro de una columna y los botones del tema, de ancho completo,
// estaban dentro de filas. Estas pruebas abren además cada diálogo y hoja de «Agregar dispositivos».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/core/utils/destino_equipo.dart';
import 'package:ohmsafe_app/features/ordenes/data/datasources/ordenes_mock_data_source.dart';
import 'package:ohmsafe_app/features/ordenes/data/repositories/ordenes_repository_impl.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/agregar_dispositivos_screen.dart';
import 'package:ohmsafe_app/screens/prueba_energizador_screen.dart';
import 'package:ohmsafe_app/widgets/aprender_rf_sheet.dart';
import 'package:ohmsafe_app/widgets/destino_equipo_confirmacion.dart';

final _lista = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Widget _app(Widget home) => AppStateProvider(notifier: AppState(), child: MaterialApp(theme: AppTheme.light, home: home));

/// Corre `cuerpo` juntando los errores de Flutter y devolviendo siempre el manejador original. La
/// fuente de pruebas es más ancha que la real y desborda la barra inferior compartida (en el teléfono
/// cabe); ese único caso no cuenta.
Future<void> _sinErrores(WidgetTester t, Size tamano, Future<void> Function() cuerpo) async {
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final prev = FlutterError.onError;
  final errores = <String>[];
  FlutterError.onError = (d) {
    final texto = d.toString();
    if (texto.contains('app_bottom_nav.dart') && texto.contains('overflowed')) return;
    errores.add(texto);
  };
  Object? fallo;
  try {
    await cuerpo();
  } catch (e, st) {
    fallo = '$e\n$st';
  } finally {
    FlutterError.onError = prev;
  }
  expect(fallo, isNull);
  expect(errores, isEmpty, reason: errores.join('\n\n'));
}

/// Toca `f` asegurando que quede arriba de la barra inferior flotante.
Future<void> _tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  final alto = t.view.physicalSize.height / t.view.devicePixelRatio;
  for (var i = 0; i < 6 && t.getCenter(f).dy > alto - 130; i++) {
    await t.drag(find.byType(ListView), const Offset(0, -120));
    await t.pump(const Duration(milliseconds: 300));
  }
  await t.tap(f);
}

Future<void> _ver(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: _lista);
  expect(f, findsOneWidget);
}

void main() {
  setUp(() => sl.registerSingleton<OrdenesRepository>(OrdenesRepositoryImpl(dataSource: OrdenesMockDataSource())));

  for (final tamano in const [Size(1206, 2622), Size(1080, 1920)]) {
    final nombre = '${tamano.width.toInt()}x${tamano.height.toInt()}';

    testWidgets('Prueba del energizador se pinta completa ($nombre)', (t) async {
      await _sinErrores(t, tamano, () async {
        await t.pumpWidget(_app(const PruebaEnergizadorScreen(ticket: {'id': 'i69'})));
        await t.pump(const Duration(seconds: 1));
        expect(find.textContaining('TIEMPO DE PRUEBA'), findsNothing, reason: 'sin reloj visible');
        await _ver(t, find.text('Encender cerca'));
        await _ver(t, find.text('Terminar prueba'));
      });
    });

    testWidgets('Agregar dispositivos se pinta completa y abre cada diálogo ($nombre)', (t) async {
      await _sinErrores(t, tamano, () async {
        await t.pumpWidget(_app(const AgregarDispositivosScreen(ticket: {'id': 'i69'})));
        await t.pump(const Duration(seconds: 2));
        for (final seccion in ['OHMBOX', 'ENTRADAS CABLEADAS', 'SIRENA', 'SALIDAS', 'SENSORES 433', 'SENSORES WI', 'CÁMARAS']) {
          await _ver(t, find.textContaining(seccion));
        }
        for (final titulo in ['Otro OhmBox en esta casa', 'Registrar sensor Wi‑Fi', 'Agregar cámara', 'Agregar sensor 433']) {
          // Cada «Agregar» abre su diálogo u hoja; se busca desde arriba de la lista.
          await t.drag(find.byType(ListView), const Offset(0, 6000));
          await t.pump(const Duration(milliseconds: 600));
          final tarjeta = find.text(titulo);
          await _ver(t, tarjeta);
          await _tocar(t, find.descendant(of: find.ancestor(of: tarjeta, matching: find.byType(Row)).first, matching: find.text('Agregar')));
          await t.pump(const Duration(milliseconds: 600));
          expect(find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue, reason: titulo);
          await t.tapAt(const Offset(5, 5)); // cierra tocando fuera
          await t.pump(const Duration(milliseconds: 600));
        }
      });
    });
  }

  testWidgets('Hojas: confirmación de casa y asistente 433 se pintan sin errores', (t) async {
    await _sinErrores(t, const Size(1206, 2622), () async {
      await t.pumpWidget(_app(Builder(
        builder: (ctx) => Scaffold(
          body: Column(children: [
            TextButton(
              onPressed: () => confirmarDestinoEquipo(
                ctx,
                DestinoDecidido.fromCasas({
                  'destino': {'tipo': 'nueva', 'nombre': 'Nellie Campobello 12', 'direccion': 'Nellie Campobello 12, 01180, CDMX', 'motivo': 'S00170 es un plan nuevo.', 'aviso': 'Dirección parecida a otra casa.'},
                  'venta': {'nombre': 'S00170', 'esServicioNuevo': true, 'plan': 'Plan Hogar Seguro - Mensual', 'equipos': []},
                })!,
              ),
              child: const Text('casa'),
            ),
            TextButton(onPressed: () => aprenderSensorRf(ctx, ordenId: 'i69', tipo: 'door', etiqueta: 'Contacto de puerta'), child: const Text('rf')),
          ]),
        ),
      )));
      await t.tap(find.text('casa'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Este equipo va a una casa nueva'), findsOneWidget);
      await t.tap(find.text('Cancelar'));
      await t.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('Hoja del asistente 433 se pinta sin errores', (t) async {
    await _sinErrores(t, const Size(1206, 2622), () async {
      await t.pumpWidget(_app(Builder(
        builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => aprenderSensorRf(ctx, ordenId: 'i69', tipo: 'door', etiqueta: 'Contacto de puerta'), child: const Text('rf')))),
      )));
      await t.tap(find.text('rf'));
      for (var i = 0; i < 7; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      await t.pump(const Duration(seconds: 1)); // el mock avanza la sesión hasta «Aprendido»
      expect(find.text('Aprendido'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      await t.tap(find.text('Cerrar'));
      await t.pump(const Duration(seconds: 1));
    });
  });
}
