import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/destino_equipo.dart';

void main() {
  test('sin casas no se pregunta', () {
    final o = OpcionesDestino.fromJson({'casas': [], 'sugerida': null, 'nueva': {'nombre': 'X', 'direccion': ''}});
    expect(o.hayQuePreguntar, false);
    expect(o.seleccionInicial, OpcionesDestino.nueva);
  });
  test('la sugerida va preseleccionada; sin coincidencia, «Casa nueva» aunque haya una sola casa', () {
    final casas = <Map<String, dynamic>>[
      {'id': 'a', 'nombre': 'Casa A', 'direccion': 'Calle 1', 'energizadores': 1},
      {'id': 'b', 'nombre': 'Casa B', 'direccion': 'Calle 2', 'energizadores': 2},
    ];
    final dos = <String, dynamic>{'casas': casas, 'nueva': {'nombre': 'Calle 3', 'direccion': 'Calle 3, CDMX'}};
    expect(OpcionesDestino.fromJson({...dos, 'sugerida': 'b'}).seleccionInicial, 'b');
    expect(OpcionesDestino.fromJson({...dos, 'sugerida': 'zzz'}).seleccionInicial, OpcionesDestino.nueva);
    expect(OpcionesDestino.fromJson({...dos, 'sugerida': null}).seleccionInicial, OpcionesDestino.nueva);
    final una = <String, dynamic>{'casas': [casas[0]], 'sugerida': null, 'nueva': dos['nueva']};
    expect(OpcionesDestino.fromJson(una).seleccionInicial, OpcionesDestino.nueva);
  });
  test('cuerpos destino para el backend', () {
    expect(destinoCasaExistente('a'), {'casaId': 'a'});
    expect(destinoCasaNueva(nombre: ' Casa B ', direccion: ' '), {'nueva': {'nombre': 'Casa B'}});
    expect(destinoCasaNueva(nombre: 'Casa C', direccion: 'Calle 3'), {'nueva': {'nombre': 'Casa C', 'direccion': 'Calle 3'}});
  });
}
