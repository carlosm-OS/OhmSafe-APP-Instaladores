import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/features/ordenes/domain/entities/orden.dart';

Orden _o(String id, String estado) => Orden(
      id: id, tipo: 'instalacion', titulo: 't', estado: estado, urgente: false, cliente: 'c',
      direccion: '', ciudad: '', cp: '', telefono: '', metraje: '', fechaCreacion: '', diasAbierto: '0',
    );

/// Regresión: tras cerrar la instalación el Inicio seguía con el badge en 1
/// porque contaba también las completadas.
void main() {
  test('el badge cuenta sólo lo pendiente', () {
    expect(contarPendientes([_o('i1', 'por_hacer'), _o('i2', 'en_curso'), _o('i3', 'completo'), _o('i4', 'cancelado')]), 2);
    expect(contarPendientes([_o('i24', 'completo')]), 0);
  });
}
