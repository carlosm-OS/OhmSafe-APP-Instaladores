import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/navigation/volver_a_listado.dart';

/// Regresión: al terminar una instalación la app abría el listado borrando
/// toda la pila y el chevron de regresar dejaba la pantalla en negro.
void main() {
  testWidgets('tras cerrar un servicio, regresar del listado vuelve al Inicio', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (inicio) => Scaffold(
          body: Column(children: [
            const Text('Inicio'),
            TextButton(
              onPressed: () => Navigator.of(inicio).push(MaterialPageRoute<void>(
                builder: (flujo) => Scaffold(
                  body: TextButton(
                    onPressed: () => volverAListado(
                      flujo,
                      Builder(
                        builder: (listado) => Scaffold(
                          body: Column(children: [
                            const Text('Listado'),
                            TextButton(onPressed: () => Navigator.maybePop(listado), child: const Text('Regresar')),
                          ]),
                        ),
                      ),
                    ),
                    child: const Text('Terminar'),
                  ),
                ),
              )),
              child: const Text('Abrir servicio'),
            ),
          ]),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir servicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    expect(find.text('Listado'), findsOneWidget);

    await tester.tap(find.text('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Terminar'), findsNothing, reason: 'el flujo cerrado no debe quedar en la pila');
  });
}
