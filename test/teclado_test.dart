import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/core/teclado/teclado.dart';
import 'package:ohmsafe_app/widgets/app_bottom_nav.dart';

/// Regresión (inspección del perímetro): con el teclado numérico abierto la barra
/// inferior subía encima del contenido y no había forma de cerrar el teclado.
void main() {
  Widget app(FocusNode foco) => MaterialApp(
        builder: (context, child) => TecladoGlobal(child: child!),
        navigatorObservers: [CerrarTecladoAlNavegar()],
        home: Scaffold(
          body: Stack(children: [
            Center(child: SizedBox(width: 200, child: TextField(focusNode: foco, keyboardType: TextInputType.number))),
            const AppBottomNav(),
          ]),
        ),
      );

  testWidgets('teclado abierto: se esconde la barra inferior y aparece «Listo», que lo cierra (iOS)', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(t.view.resetViewInsets);
    final foco = FocusNode();
    await t.pumpWidget(app(foco));
    expect(find.text('Mi cuenta'), findsOneWidget);

    await t.tap(find.byType(TextField));
    t.view.viewInsets = const FakeViewPadding(bottom: 900); // teclado (px físicos)
    await t.pumpAndSettle();
    expect(find.text('Mi cuenta'), findsNothing, reason: 'la barra no debe subir encima del contenido');
    expect(find.byKey(const Key('teclado-listo')), findsOneWidget);

    expect(foco.hasFocus, isTrue);
    await t.tap(find.byKey(const Key('teclado-listo')));
    await t.pump();
    expect(foco.hasFocus, isFalse, reason: '«Listo» cierra el teclado');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tocar fuera del campo cierra el teclado', (t) async {
    final foco = FocusNode();
    await t.pumpWidget(app(foco));
    await t.tap(find.byType(TextField));
    await t.pump();
    expect(foco.hasFocus, isTrue);
    await t.tapAt(const Offset(20, 20));
    await t.pump();
    expect(foco.hasFocus, isFalse);
  });
}
