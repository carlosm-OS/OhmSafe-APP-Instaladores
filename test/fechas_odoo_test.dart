import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/utils/fechas_odoo.dart';

void main() {
  group('FechasOdoo', () {
    test('la fecha de Odoo se interpreta como UTC, no como hora local', () {
      final d = FechasOdoo.aLocal('2026-09-18 16:00:00');
      expect(d, isNotNull);
      expect(d!.isUtc, isFalse, reason: 'se entrega ya en hora del dispositivo');
      expect(d.isAtSameMomentAs(DateTime.utc(2026, 9, 18, 16)), isTrue);
    });

    test('respeta la zona si el ISO ya la trae', () {
      final conZ = FechasOdoo.aLocal('2026-09-18T16:00:00Z')!;
      final conOffset = FechasOdoo.aLocal('2026-09-18T10:00:00-06:00')!;
      expect(conZ.isAtSameMomentAs(DateTime.utc(2026, 9, 18, 16)), isTrue);
      expect(conOffset.isAtSameMomentAs(DateTime.utc(2026, 9, 18, 16)), isTrue);
    });

    test('formatea en hora local del dispositivo', () {
      final esperado = DateTime.utc(2026, 9, 18, 16).toLocal();
      String dos(int n) => n.toString().padLeft(2, '0');
      expect(
        FechasOdoo.fechaHora('2026-09-18 16:00:00'),
        '${dos(esperado.day)}/${dos(esperado.month)}/${esperado.year} ${dos(esperado.hour)}:${dos(esperado.minute)}',
      );
      expect(FechasOdoo.soloDia('2026-09-18 16:00:00'),
          DateTime(esperado.year, esperado.month, esperado.day));
    });

    test('vacio o basura no rompe', () {
      expect(FechasOdoo.aLocal(null), isNull);
      expect(FechasOdoo.aLocal('   '), isNull);
      expect(FechasOdoo.aLocal('no es fecha'), isNull);
      expect(FechasOdoo.fechaHora('no es fecha'), 'no es fecha');
      expect(FechasOdoo.fechaHora(null), '');
    });
  });

  test('una fecha sin hora es un día calendario: no se corre por la zona horaria', () {
    expect(FechasOdoo.fecha('2026-09-20'), '20/09/2026');
    final d = FechasOdoo.aLocal('2026-09-20')!;
    expect([d.year, d.month, d.day, d.hour], [2026, 9, 20, 0]);
    expect(FechasOdoo.soloDia('2026-01-01'), DateTime(2026, 1, 1));
  });

  test('cubreDia: una instalación de dos días aparece en ambos días y no en el siguiente', () {
    // 26 sep 15:00 UTC → 27 sep 23:00 UTC; en cualquier zona de América cubre 26 y 27.
    expect(FechasOdoo.cubreDia('2026-09-26 15:00:00', '2026-09-27 23:00:00', DateTime(2026, 9, 26)), isTrue);
    expect(FechasOdoo.cubreDia('2026-09-26 15:00:00', '2026-09-27 23:00:00', DateTime(2026, 9, 27)), isTrue);
    expect(FechasOdoo.cubreDia('2026-09-26 15:00:00', '2026-09-27 23:00:00', DateTime(2026, 9, 28)), isFalse);
    expect(FechasOdoo.cubreDia('2026-09-26 15:00:00', null, DateTime(2026, 9, 26)), isTrue);
    expect(FechasOdoo.cubreDia(null, null, DateTime(2026, 9, 26)), isFalse);
  });

  test('rango: mismo día muestra sólo la hora de fin; varios días muestra ambas fechas', () {
    final uno = FechasOdoo.rango('2026-09-26 15:00:00', '2026-09-26 23:00:00');
    expect(uno.split('–').length, 2);
    expect(uno.split('–')[1].trim().length, 5); // «HH:MM»
    final dos = FechasOdoo.rango('2026-09-26 15:00:00', '2026-09-27 23:00:00');
    expect(dos.split('–')[1].trim().contains('/2026'), isTrue);
  });
}
