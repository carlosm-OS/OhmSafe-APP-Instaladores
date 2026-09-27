import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/features/dinero/domain/dinero.dart';

void main() {
  test('dinero() formatea con miles y dos decimales', () {
    expect(dinero(0), r'$0.00');
    expect(dinero(950), r'$950.00');
    expect(dinero(1500), r'$1,500.00');
    expect(dinero(1234567.891), r'$1,234,567.89');
    expect(dinero(10, 'USD'), r'$10.00 USD');
  });

  test('ResumenPagos.fromJson lee pagos y totales del contrato', () {
    final r = ResumenPagos.fromJson({
      'pagos': [
        {'id': '224', 'referencia': 'Borrador', 'concepto': 'Intervención i12 · S00157', 'ordenId': 'i12', 'fecha': '2026-09-25', 'monto': 0, 'pendiente': 0, 'moneda': 'MXN', 'estado': 'pendiente_validacion'},
        {'id': '1', 'referencia': 'BILL/2026/0001', 'concepto': 'Intervención i10', 'ordenId': null, 'fecha': '2026-09-20', 'monto': 650.5, 'pendiente': 0, 'moneda': 'MXN', 'estado': 'pagado'},
      ],
      'totales': {'pagado': 650.5, 'porPagar': 0, 'pendienteValidacion': 0, 'moneda': 'MXN'},
    });
    expect(r.pagos.length, 2);
    expect(r.pagos.first.ordenId, 'i12');
    expect(r.pagos.last.ordenId, isNull);
    expect(r.pagos.last.monto, 650.5);
    expect(r.pagado, 650.5);
    expect(estadosPago[r.pagos.first.estado], 'En revisión');
  });

  test('Cotizacion y ProductoCatalogo toleran campos faltantes', () {
    final c = Cotizacion.fromJson({'id': 158, 'referencia': 'S00158', 'cliente': 'Ana', 'fecha': '2026-09-25 21:06:52', 'total': 116.93, 'estado': 'enviada'});
    expect(c.id, '158');
    expect(c.moneda, 'MXN');
    expect(c.urlPortal, isNull);
    final p = ProductoCatalogo.fromJson({'id': 31, 'nombre': 'Cambio energizador con batería', 'precio': 1500});
    expect(p.codigo, '');
    expect(p.esServicio, isFalse);
    expect(p.precio, 1500);
  });
}
