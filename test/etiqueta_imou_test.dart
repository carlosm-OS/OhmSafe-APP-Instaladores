import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/etiqueta_imou.dart';

/// Etiqueta/QR de una cámara Imou (2026-10-19): serie de 15 caracteres y código SC que distingue
/// mayúsculas y minúsculas. Nunca se altera el código.
void main() {
  test('pares con nombre, en cualquier orden y separador', () {
    final a = EtiquetaImou.leer('SN:C3CE8CAPSFA2E62,SC:L2VqC2QF')!;
    expect(a.serie, 'C3CE8CAPSFA2E62');
    expect(a.codigo, 'L2VqC2QF');
    final b = EtiquetaImou.leer('safety code=L2VqC2QF\nserial=c3ce8capsfa2e62')!;
    expect(b.serie, 'C3CE8CAPSFA2E62');
    expect(b.codigo, 'L2VqC2QF');
  });

  test('JSON y enlace con query', () {
    expect(EtiquetaImou.leer('{"SN":"C3CE8CAPSFA2E62","SC":"L2VqC2QF"}')!.codigo, 'L2VqC2QF');
    final e = EtiquetaImou.leer('https://imou.example/add?deviceId=C3CE8CAPSFA2E62&code=L2VqC2QF')!;
    expect(e.serie, 'C3CE8CAPSFA2E62');
    expect(e.codigo, 'L2VqC2QF');
  });

  test('la etiqueta impresa: líneas con S/N, SAFETY CODE y modelo', () {
    final e = EtiquetaImou.leer('imou CONSUMER CAMERA\nModel:IPC-DK2N-4H1W\nSAFETY CODE:L2VqC2QF\nS/N:C3CE8CAPSFA2E62')!;
    expect(e.serie, 'C3CE8CAPSFA2E62');
    expect(e.codigo, 'L2VqC2QF');
    expect(e.modelo, 'IPC-DK2N-4H1W');
  });

  test('sólo la serie, o serie y código pegados', () {
    expect(EtiquetaImou.leer('C3CE8CAPSFA2E62')!.codigo, '');
    final e = EtiquetaImou.leer('C3CE8CAPSFA2E62 L2VqC2QF')!;
    expect(e.codigo, 'L2VqC2QF');
  });

  test('lo que no es una etiqueta Imou se rechaza', () {
    expect(EtiquetaImou.leer(''), isNull);
    expect(EtiquetaImou.leer('IMOU'), isNull);
    expect(EtiquetaImou.leer('hola mundo'), isNull);
  });
}
