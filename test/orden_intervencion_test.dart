import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/features/ordenes/data/models/orden_model.dart';

void main() {
  test('una intervención de Planificación se lee con sus campos aditivos', () {
    final o = OrdenModel.fromJson({
      'id': 'i6', 'tipo': 'instalacion', 'titulo': 'Instalación', 'estado': 'por_hacer', 'urgente': false,
      'cliente': 'Cliente', 'direccion': 'Av. 1', 'ciudad': 'CDMX', 'cp': '06700', 'telefono': '55', 'metraje': 0,
      'fechaCreacion': '2026-09-25 19:33:08', 'diasAbierto': 0, 'pasoActual': 'iniciar_ruta',
      'origen': 'intervencion', 'ordenVenta': 'S00154',
      'hojaTrabajo': [
        {'nombre': 'insp_sin_obstaculos', 'etiqueta': 'Sin obstáculos', 'tipo': 'boolean', 'valor': true},
        {'nombre': 'ent_observaciones', 'etiqueta': 'Observaciones', 'tipo': 'text', 'valor': null},
      ],
    });
    expect(o.id, 'i6');
    expect(o.esIntervencion, isTrue);
    expect(o.ordenVenta, 'S00154');
    expect(o.hojaTrabajo, hasLength(2));
    expect(o.toTicketMap()['ordenVenta'], 'S00154');
  });

  test('una tarea vieja sigue igual: sin origen ni hoja', () {
    final o = OrdenModel.fromJson({'id': '45', 'tipo': 'instalacion', 'titulo': 'T', 'estado': 'por_hacer', 'urgente': false, 'cliente': '', 'direccion': '', 'ciudad': '', 'cp': '', 'telefono': '', 'metraje': 0, 'fechaCreacion': '', 'diasAbierto': 0});
    expect(o.esIntervencion, isFalse);
    expect(o.hojaTrabajo, isEmpty);
  });
}
