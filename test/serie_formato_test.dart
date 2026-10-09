import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/serie_formato.dart';

void main() {
  group('formatearSerie', () {
    test('pone los guiones mientras se escribe de corrido', () {
      expect(formatearSerie('OS'), 'OS-');
      expect(formatearSerie('OSOBV01'), 'OS-OBV01-');
      expect(formatearSerie('OSOBV010026'), 'OS-OBV01-0026');
      expect(formatearSerie('osprueba0001'), 'OS-PRUEBA-0001');
      expect(formatearSerie('OS-OBV01-0026'), 'OS-OBV01-0026');
      expect(formatearSerie('os obv01 26'), 'OS-OBV01-26');
    });

    test('series viejas y texto raro se respetan', () {
      expect(formatearSerie('ohm-abcd-1234'), 'OHM-ABCD-1234');
      expect(formatearSerie('9999'), '9999');
      expect(formatearSerie('O'), 'O');
    });

    test('al borrar no se vuelve a poner el guion final', () {
      final f = SerieInputFormatter();
      final r = f.formatEditUpdate(const TextEditingValue(text: 'OS-OBV01-'), const TextEditingValue(text: 'OS-OBV01'));
      expect(r.text, 'OS-OBV01');
      final r2 = f.formatEditUpdate(const TextEditingValue(text: 'OS-OBV0'), const TextEditingValue(text: 'OS-OBV01'));
      expect(r2.text, 'OS-OBV01-');
      expect(r2.selection.baseOffset, r2.text.length);
    });
  });

  group('normalizarSerie', () {
    test('sólo el número → serie completa con 4 dígitos', () {
      expect(normalizarSerie('26'), 'OS-OBV01-0026');
      expect(normalizarSerie('0026'), 'OS-OBV01-0026');
    });
    test('consecutivo corto se rellena a 4 dígitos', () {
      expect(normalizarSerie('OS-OBV01-26'), 'OS-OBV01-0026');
      expect(normalizarSerie('osprueba1'), 'OS-PRUEBA-0001');
    });
    test('completas y viejas quedan igual', () {
      expect(normalizarSerie('OS-OBV01-0026'), 'OS-OBV01-0026');
      expect(normalizarSerie('OHM-ABCD-1234'), 'OHM-ABCD-1234');
    });
  });
}
