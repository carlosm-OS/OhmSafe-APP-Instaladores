import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/destino_equipo.dart';

void main() {
  group('VentaResumen', () {
    test('servicio nuevo con plan y equipo', () {
      final v = VentaResumen.fromJson({
        'nombre': 'S00255',
        'esServicioNuevo': true,
        'plan': 'Plan Hogar Seguro - Mensual',
        'equipos': [
          {'nombre': 'Ohmbox/Energizador', 'cantidad': 1}
        ],
      });
      expect(v, isNotNull);
      expect(v!.esServicioNuevo, isTrue);
      expect(v.resumen, 'Servicio nuevo: Plan Hogar Seguro - Mensual · 1 Ohmbox/Energizador');
    });

    test('equipo adicional sin plan', () {
      final v = VentaResumen.fromJson({'nombre': 'S00260', 'esServicioNuevo': false, 'plan': null, 'equipos': [
        {'nombre': 'Ohmbox/Energizador', 'cantidad': 2}
      ]});
      expect(v!.resumen, 'Equipo adicional · 2 Ohmbox/Energizador');
    });

    test('backend anterior sin venta → null y las opciones siguen funcionando', () {
      expect(VentaResumen.fromJson(null), isNull);
      final o = OpcionesDestino.fromJson({'casas': [], 'nueva': {'nombre': 'Casa', 'direccion': 'Calle 1'}});
      expect(o.venta, isNull);
      expect(o.hayQuePreguntar, isFalse);
    });

    test('la venta viaja dentro de las opciones', () {
      final o = OpcionesDestino.fromJson({
        'casas': [
          {'id': 'a', 'nombre': 'Casa A', 'equipos': 1}
        ],
        'nueva': {'nombre': 'Casa', 'direccion': 'Calle 1'},
        'venta': {'nombre': 'S00255', 'esServicioNuevo': true, 'plan': 'Plan', 'equipos': []},
      });
      expect(o.venta?.nombre, 'S00255');
      expect(o.venta?.resumen, 'Servicio nuevo: Plan');
    });
  });
}
