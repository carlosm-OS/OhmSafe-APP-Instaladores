import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/config/marcas_camara.dart';

/// Interruptor de marcas (2026-10-20): la app de instaladores sólo ofrece Tuya; EZVIZ e Imou se
/// apagan sin borrarse y se reabren con `--dart-define=MARCAS_CAMARA=tuya,ezviz,imou`.
void main() {
  tearDown(() => MarcasCamara.habilitadas = MarcasCamara.desde('tuya'));

  test('por omisión sólo Tuya: sin registro por serie (EZVIZ/Imou)', () {
    expect(MarcasCamara.habilitadas, {'tuya'});
    expect(MarcasCamara.tuya, isTrue);
    expect(MarcasCamara.ezviz, isFalse);
    expect(MarcasCamara.imou, isFalse);
    expect(MarcasCamara.registroPorSerie, isFalse);
  });

  test('la lista del define admite espacios y mayúsculas', () {
    expect(MarcasCamara.desde(' Tuya, EZVIZ ,imou,'), {'tuya', 'ezviz', 'imou'});
    expect(MarcasCamara.desde(''), isEmpty);
  });

  test('con todas encendidas vuelve el registro por serie', () {
    MarcasCamara.habilitadas = MarcasCamara.todas;
    expect(MarcasCamara.registroPorSerie, isTrue);
  });
}
