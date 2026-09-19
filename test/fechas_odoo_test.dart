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
}
