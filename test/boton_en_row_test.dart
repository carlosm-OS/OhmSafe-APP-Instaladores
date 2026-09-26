// Regresión: el tema global fija `minimumSize: Size.fromHeight(AppTouch.primary)`
// para ElevatedButton, que es Size(double.infinity, 56). Dentro de un Row el
// ancho disponible no está acotado, así que el botón pide un ancho infinito y
// el layout de ese subárbol falla: el botón no se pinta ni recibe toques.
//
// Ya rompió dos pantallas (Facturación en blanco, y el botón "Confirmar Firma"
// del cierre, que dejó al instalador sin poder terminar la instalación). Esta
// prueba fija el contrato: un ElevatedButton dentro de un Row necesita su
// propio minimumSize finito.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';

Widget _enRow(Widget boton) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Limpiar'), boton],
        ),
      ),
    );

void main() {
  testWidgets('sin minimumSize propio, un ElevatedButton en un Row revienta el layout',
      (tester) async {
    final errores = <FlutterErrorDetails>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = errores.add;
    await tester.pumpWidget(_enRow(
      ElevatedButton(onPressed: () {}, child: const Text('Confirmar Firma')),
    ));
    FlutterError.onError = anterior;
    tester.takeException();

    expect(
      errores.any((e) => e.exception.toString().contains('infinite width')),
      isTrue,
      reason: 'el tema global pide un ancho infinito en un contexto sin acotar',
    );
  });

  testWidgets('con minimumSize finito, se dibuja y es tocable', (tester) async {
    var tocado = false;
    await tester.pumpWidget(_enRow(
      ElevatedButton(
        onPressed: () => tocado = true,
        style: ElevatedButton.styleFrom(minimumSize: const Size(150, 44)),
        child: const Text('Confirmar Firma'),
      ),
    ));
    expect(tester.takeException(), isNull);

    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.width, greaterThan(0));
    expect(size.width, lessThan(400), reason: 'no debe ocupar un ancho infinito');

    await tester.tap(find.text('Confirmar Firma'));
    expect(tocado, isTrue);
  });
}
