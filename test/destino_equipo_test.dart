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
      expect(v!.resumen, 'Servicio nuevo: Plan Hogar Seguro - Mensual · 1 Ohmbox/Energizador');
    });

    test('equipo adicional sin plan', () {
      final v = VentaResumen.fromJson({'nombre': 'S00260', 'esServicioNuevo': false, 'plan': null, 'equipos': [
        {'nombre': 'Ohmbox/Energizador', 'cantidad': 2}
      ]});
      expect(v!.resumen, 'Equipo adicional · 2 Ohmbox/Energizador');
    });
  });

  // Una vivienda = una suscripción (2026-10-14): la venta decide la casa y la app sólo confirma.
  group('DestinoDecidido', () {
    test('backend anterior sin destino → null (se vincula sin confirmar)', () {
      expect(DestinoDecidido.fromCasas({'casas': [], 'nueva': {'nombre': 'Casa'}}), isNull);
    });

    test('plan nuevo → casa nueva con la dirección de la compra', () {
      final d = DestinoDecidido.fromCasas({
        'destino': {'tipo': 'nueva', 'nombre': 'Nellie 12', 'direccion': 'Nellie 12, CDMX', 'motivo': 'plan nuevo', 'aviso': null},
        'venta': {'nombre': 'S00170', 'esServicioNuevo': true, 'plan': 'Plan', 'equipos': []},
      })!;
      expect(d.esNueva, isTrue);
      expect(d.bloquea, isFalse);
      expect(d.casaNombre, 'Nellie 12');
      expect(d.direccion, 'Nellie 12, CDMX');
      expect(d.aviso, isNull);
      expect(d.venta?.nombre, 'S00170');
    });

    test('equipo adicional → casa existente del contrato', () {
      final d = DestinoDecidido.fromCasas({
        'destino': {'tipo': 'existente', 'casa': {'id': 'c1', 'nombre': 'Casa Lomas', 'direccion': 'Lomas 1'}, 'motivo': 'contrato', 'aviso': null},
      })!;
      expect(d.esExistente, isTrue);
      expect(d.casaNombre, 'Casa Lomas');
    });

    test('indeterminada bloquea y trae el aviso vacío como null', () {
      final d = DestinoDecidido.fromCasas({'destino': {'tipo': 'indeterminada', 'motivo': 'avisa a operaciones', 'aviso': ''}})!;
      expect(d.bloquea, isTrue);
      expect(d.aviso, isNull);
    });
  });
}
