import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/wifi/redes_wifi.dart';
import 'package:ohmsafe_app/widgets/campo_red_wifi.dart';

/// Selector de redes Wi‑Fi al emparejar (2026-10-20, Carlos: «un buscador de redes para que la
/// encuentre y seleccione»). Android lista; iOS sólo relee la conectada; 5 GHz avisa, no bloquea.
void main() {
  group('bandas', () {
    test('por frecuencia', () {
      expect(bandaPorFrecuencia(2437), BandaWifi.ghz24);
      expect(bandaPorFrecuencia(5180), BandaWifi.ghz5);
      expect(bandaPorFrecuencia(5955), BandaWifi.ghz6);
      expect(bandaPorFrecuencia(null), BandaWifi.desconocida);
    });

    test('por nombre: sólo pista, y 2.4 gana cuando el nombre lo dice', () {
      expect(bandaPorNombre('INFINITUM1234_5G'), BandaWifi.ghz5);
      expect(bandaPorNombre('Casa Perez-5GHz'), BandaWifi.ghz5);
      expect(bandaPorNombre('TotalPlay-2.4G'), BandaWifi.ghz24);
      expect(bandaPorNombre('Casa Perez'), BandaWifi.desconocida);
      expect(bandaPorNombre('Depto 5'), BandaWifi.ghz5);
      expect(bandaPorNombre('Red 15G'), BandaWifi.desconocida);
      expect(bandaPorNombre('').sirve, isTrue);
    });
  });

  test('ordenarRedes: 2.4 primero y por señal; misma SSID en dos bandas se queda con la de 2.4; ocultas fuera', () {
    final r = ordenarRedes([
      const RedWifi(ssid: 'Casa', banda: BandaWifi.ghz5, nivel: -40),
      const RedWifi(ssid: 'Casa', banda: BandaWifi.ghz24, nivel: -70),
      const RedWifi(ssid: 'Vecino', banda: BandaWifi.ghz24, nivel: -60),
      const RedWifi(ssid: '', banda: BandaWifi.ghz24, nivel: -30),
      const RedWifi(ssid: 'Solo5', banda: BandaWifi.ghz5, nivel: -50),
    ]);
    expect(r.map((x) => x.ssid).toList(), ['Vecino', 'Casa', 'Solo5']);
    expect(r[1].banda, BandaWifi.ghz24);
    expect(r.last.sirve, isFalse);
  });

  group('CampoRedWifi', () {
    Future<void> montar(WidgetTester t, {required TextEditingController c, required ListadorRedes listador, bool esIos = false, String? actual = 'Casa Perez'}) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CampoRedWifi(controller: c, leerRedActual: () async => actual, listador: listador, esIos: esIos)),
        ),
      );
      await t.pump();
      await t.pump();
    }

    testWidgets('Android: se prellena con la red del teléfono y la lista deja elegir una de 2.4 GHz', (t) async {
      final c = TextEditingController();
      final listador = _Listador([
        const RedWifi(ssid: 'Casa Perez', banda: BandaWifi.ghz24, nivel: -50),
        const RedWifi(ssid: 'Casa Perez_5G', banda: BandaWifi.ghz5, nivel: -45),
        const RedWifi(ssid: 'Vecino', banda: BandaWifi.ghz24, nivel: -70),
      ]);
      await montar(t, c: c, listador: listador);
      expect(c.text, 'Casa Perez');
      await t.tap(find.byIcon(Icons.wifi_find_rounded));
      await t.pumpAndSettle();
      expect(find.text('Redes Wi‑Fi cercanas'), findsOneWidget);
      expect(find.text('Conectado ahora · 2.4 GHz'), findsOneWidget);
      expect(find.text('5 GHz: el equipo no la ve'), findsOneWidget);
      await t.tap(find.text('Vecino'));
      await t.pumpAndSettle();
      expect(c.text, 'Vecino');
      expect(find.text('Redes Wi‑Fi cercanas'), findsNothing);
      c.dispose();
    });

    testWidgets('Android: una red de 5 GHz no se puede tocar', (t) async {
      final c = TextEditingController();
      final listador = _Listador([const RedWifi(ssid: 'Solo5G', banda: BandaWifi.ghz5, nivel: -45)]);
      await montar(t, c: c, listador: listador, actual: null);
      await t.tap(find.byIcon(Icons.wifi_find_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Solo5G'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(c.text, '');
      expect(find.text('Redes Wi‑Fi cercanas'), findsOneWidget);
      c.dispose();
    });

    testWidgets('sin permiso de ubicación la hoja lo explica', (t) async {
      final c = TextEditingController();
      await montar(t, c: c, listador: _Listador(const [], estado: EstadoEscaneo.sinPermiso));
      await t.tap(find.byIcon(Icons.wifi_find_rounded));
      await t.pumpAndSettle();
      expect(find.textContaining('permiso de ubicación'), findsOneWidget);
      c.dispose();
    });

    testWidgets('iOS: no hay lista; el icono relee la red y el texto manda a Ajustes', (t) async {
      final c = TextEditingController();
      await montar(t, c: c, listador: _Listador(const [], puede: false), esIos: true);
      expect(find.byIcon(Icons.wifi_find_rounded), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.textContaining('Ajustes › Wi‑Fi'), findsOneWidget);
      c.dispose();
    });

    testWidgets('un nombre que huele a 5 GHz avisa pero no impide', (t) async {
      final c = TextEditingController();
      await montar(t, c: c, listador: _Listador(const []), actual: null);
      await t.enterText(find.byType(TextField), 'INFINITUM_5G');
      await t.pump();
      expect(find.textContaining('parece de 5 GHz'), findsOneWidget);
      expect(c.text, 'INFINITUM_5G');
      c.dispose();
    });
  });
}

class _Listador implements ListadorRedes {
  _Listador(this.redes, {this.estado = EstadoEscaneo.ok, this.puede = true});
  final List<RedWifi> redes;
  final EstadoEscaneo estado;
  final bool puede;

  @override
  bool get puedeListar => puede;

  @override
  Future<ResultadoEscaneo> escanear() async => ResultadoEscaneo(estado, ordenarRedes(redes));
}
