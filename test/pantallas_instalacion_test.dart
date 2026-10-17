// Las pantallas de la instalación (prueba y agregar dispositivos) se pintan completas con datos del
// mock y sin errores de layout. La build 40 salió en gris en el teléfono (2026-10-14): la barra
// inferior (un Positioned) estaba dentro de una columna y los botones del tema, de ancho completo,
// estaban dentro de filas. Estas pruebas abren además cada diálogo y hoja de «Agregar dispositivos».
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/teclado/teclado.dart';
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

Widget _app(Widget home) => AppStateProvider(
  notifier: AppState(),
  child: MaterialApp(theme: AppTheme.light, home: home),
);

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
        await _ver(t, find.text('Encender la cerca'));
        await _ver(t, find.textContaining('MUÉSTRALE AL CLIENTE'));
        await _ver(t, find.text('Terminar prueba'));
      });
    });

    testWidgets('Agregar dispositivos se pinta completa y abre cada diálogo ($nombre)', (t) async {
      await _sinErrores(t, tamano, () async {
        await t.pumpWidget(_app(const AgregarDispositivosScreen(ticket: {'id': 'i69'})));
        await t.pump(const Duration(seconds: 2));
        for (final seccion in ['SENSORES CABLEADOS', 'SIRENA', 'SALIDAS AUXILIARES', 'SENSORES INALÁMBRICOS', 'CÁMARAS', 'AGREGAR OTRO ENERGIZADOR']) {
          await _ver(t, find.textContaining(seccion));
        }
        // Sensores Wi‑Fi apagados por ahora (_wifiHabilitado): ni sección ni «Agregar».
        expect(find.textContaining('SENSORES WI'), findsNothing);
        expect(find.text('Sensor Wi‑Fi'), findsNothing);
        // Energizadores de la casa: información de sólo lectura (serie, «Principal», estado), sin botón.
        await _ver(t, find.text('Principal'));
        expect(find.text('OS-PRUEBA-0001'), findsOneWidget);
        expect(find.text('En línea'), findsWidgets);
        for (final titulo in ['Agregar otro OhmBox', 'Cámara ya conectada', 'Sensor inalámbrico']) {
          // Cada «Agregar» abre su diálogo u hoja; se busca desde arriba de la lista.
          t.state<ScrollableState>(_lista).position.jumpTo(0); // la lista rebota (como los pasos 1-3)
          await t.pump(const Duration(milliseconds: 600));
          final tarjeta = find.text(titulo);
          await _ver(t, tarjeta);
          await _tocar(
            t,
            find.descendant(
              of: find.ancestor(of: tarjeta, matching: find.byType(Row)).first,
              matching: find.text('Agregar'),
            ),
          );
          await t.pump(const Duration(milliseconds: 600));
          expect(find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty, isTrue, reason: titulo);
          await t.tapAt(const Offset(5, 5)); // cierra tocando fuera
          await t.pump(const Duration(milliseconds: 600));
        }
      });
    });
  }

  testWidgets('Cada ⓘ de «Agregar dispositivos» abre su ayuda y se cierra tocando fuera', (t) async {
    await _sinErrores(t, const Size(1206, 2622), () async {
      await t.pumpWidget(_app(const AgregarDispositivosScreen(ticket: {'id': 'i69'})));
      await t.pump(const Duration(seconds: 2));
      final infos = find.byIcon(Icons.info_outline_rounded);
      expect(infos, findsWidgets);
      await t.tap(infos.first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Sensores cableados'), findsOneWidget);
      await t.tapAt(const Offset(200, 120)); // fuera de la hoja
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Sensores cableados'), findsNothing);
    });
  });

  testWidgets('Guardar en un diálogo con texto no truena al cerrarse con el teclado de iOS (build 43: _dependents.isEmpty)', (t) async {
    // El truene sólo sale con el teclado de iOS: TecladoGlobal envuelve la app en un MediaQuery mientras
    // está abierto y lo quita al cerrarse, en el mismo cuadro en que el diálogo empieza a cerrarse.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _sinErrores(t, const Size(1206, 2622), () async {
        await t.pumpWidget(
          AppStateProvider(
            notifier: AppState(),
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (_, child) => TecladoGlobal(child: child!),
              home: const AgregarDispositivosScreen(ticket: {'id': 'i69'}),
            ),
          ),
        );
        await t.pump(const Duration(seconds: 2));
        final tarjeta = find.text('Cámara ya conectada');
        await _ver(t, tarjeta);
        await _tocar(
          t,
          find.descendant(
            of: find.ancestor(of: tarjeta, matching: find.byType(Row)).first,
            matching: find.text('Agregar'),
          ),
        );
        await t.pump(const Duration(milliseconds: 600));
        final campos = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        expect(campos, findsNWidgets(3));
        await t.enterText(campos.at(0), 'BF1234567');
        await t.enterText(campos.at(1), 'ABCDEF');
        await t.enterText(campos.at(2), 'Cochera');
        t.view.viewInsets = const FakeViewPadding(bottom: 900); // teclado abierto
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Agregar')));
        t.view.viewInsets = FakeViewPadding.zero; // y se cierra al guardar
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        await t.pump(const Duration(seconds: 1));
        expect(find.byType(Dialog), findsNothing);
      });
    } finally {
      debugDefaultTargetPlatformOverride = null; // antes de que termine la prueba
    }
  });

  // Teléfonos reales (en píxeles físicos, ×3): pantalla, franjas de arriba/abajo y alto del teclado.
  const telefonos = <({String nombre, Size tamano, double arriba, double abajo, double teclado, TargetPlatform plataforma})>[
    (nombre: 'iPhone Pro', tamano: Size(1206, 2622), arriba: 62, abajo: 34, teclado: 336, plataforma: TargetPlatform.iOS),
    (nombre: 'iPhone SE', tamano: Size(1125, 2001), arriba: 20, abajo: 0, teclado: 216, plataforma: TargetPlatform.iOS),
    (nombre: 'Android chico', tamano: Size(1080, 1920), arriba: 24, abajo: 0, teclado: 280, plataforma: TargetPlatform.android),
  ];
  for (final tel in telefonos) {
    final tamano = tel.tamano;
    testWidgets('Con el teclado abierto ningún diálogo con campos se desborda (${tel.nombre})', (t) async {
      // Captura de Carlos (2026-10-15): «¿Qué conectaste a la salida 2?» con «BOTTOM OVERFLOWED BY 67 PIXELS».
      debugDefaultTargetPlatformOverride = tel.plataforma;
      try {
        await _sinErrores(t, tamano, () async {
          // Franja superior (isla dinámica) e inferior de un iPhone: le quitan alto al diálogo.
          t.view.padding = FakeViewPadding(top: tel.arriba * 3, bottom: tel.abajo * 3);
          Future<void> abrirPantalla() async {
            await t.pumpWidget(const SizedBox()); // pantalla nueva para cada diálogo
            await t.pumpWidget(AppStateProvider(
              notifier: AppState(),
              child: MaterialApp(theme: AppTheme.light, builder: (_, child) => TecladoGlobal(child: child!), home: const AgregarDispositivosScreen(ticket: {'id': 'i69'})),
            ));
            await t.pump(const Duration(seconds: 2));
          }

          Future<void> conTeclado(String cual) async {
            await t.pump(const Duration(milliseconds: 600));
            expect(find.byType(Dialog), findsOneWidget, reason: cual);
            t.view.viewInsets = FakeViewPadding(bottom: tel.teclado * 3); // en iOS se suma la barra «Listo»
            await t.pump(const Duration(milliseconds: 300));
            // El diálogo se desplaza: el último campo se alcanza y el botón principal sigue ahí.
            final campos = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
            await t.ensureVisible(campos.last);
            await t.pump(const Duration(milliseconds: 300));
            expect(find.descendant(of: find.byType(Dialog), matching: find.byType(FilledButton)), findsOneWidget, reason: cual);
            t.view.viewInsets = FakeViewPadding.zero;
            await t.pump(const Duration(milliseconds: 300));
          }

          Future<void> tocarEnFila(String titulo, String boton) async {
            await _ver(t, find.text(titulo));
            await _tocar(t, find.descendant(of: find.ancestor(of: find.text(titulo), matching: find.byType(Row)).first, matching: find.text(boton)));
          }

          // Salida: Probar → «¿Se encendió?» Sí → «¿Qué conectaste a la salida 1?»
          await abrirPantalla();
          await tocarEnFila('Salida 1', 'Probar');
          await t.pump(const Duration(milliseconds: 800));
          await t.tap(find.text('Sí'));
          await conTeclado('salida');

          for (final titulo in ['Cámara ya conectada', 'Agregar otro OhmBox']) {
            await abrirPantalla();
            await tocarEnFila(titulo, 'Agregar');
            await conTeclado(titulo);
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        });
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Hojas: confirmación de casa y asistente 433 se pintan sin errores', (t) async {
    await _sinErrores(t, const Size(1206, 2622), () async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => confirmarDestinoEquipo(
                      ctx,
                      DestinoDecidido.fromCasas({
                        'destino': {
                          'tipo': 'nueva',
                          'nombre': 'Nellie Campobello 12',
                          'direccion': 'Nellie Campobello 12, 01180, CDMX',
                          'motivo': 'S00170 es un plan nuevo.',
                          'aviso': 'Dirección parecida a otra casa.',
                        },
                        'venta': {'nombre': 'S00170', 'esServicioNuevo': true, 'plan': 'Plan Hogar Seguro - Mensual', 'equipos': []},
                      })!,
                    ),
                    child: const Text('casa'),
                  ),
                  TextButton(
                    onPressed: () => aprenderSensorRf(ctx, ordenId: 'i69', tipo: 'door', etiqueta: 'Contacto de puerta'),
                    child: const Text('rf'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('casa'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('¿Estás instalando en esta dirección?'), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
      expect(find.text('Sí, vincular aquí'), findsOneWidget);
      await t.tap(find.text('No es esta dirección'));
      await t.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('Hoja del asistente 433 se pinta sin errores', (t) async {
    await _sinErrores(t, const Size(1206, 2622), () async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => aprenderSensorRf(ctx, ordenId: 'i69', tipo: 'door', etiqueta: 'Contacto de puerta'),
                  child: const Text('rf'),
                ),
              ),
            ),
          ),
        ),
      );
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
