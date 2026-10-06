import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/observaciones_cierre.dart';

void main() {
  test('sin texto no manda etiquetas vacías', () {
    expect(observacionesCierre(paso1: '', paso2: '  '), '');
  });
  test('sólo los pasos con texto, recortados', () {
    expect(observacionesCierre(paso1: ' barda alta ', paso2: ''), 'Paso 1: barda alta');
    expect(observacionesCierre(paso1: '', paso2: 'cliente ausente'), 'Paso 2: cliente ausente');
    expect(observacionesCierre(paso1: 'a', paso2: 'b'), 'Paso 1: a | Paso 2: b');
  });
}
