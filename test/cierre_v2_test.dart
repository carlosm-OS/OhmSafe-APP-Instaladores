import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/screens/cierre_instalacion_screen.dart';
import 'package:ohmsafe_app/widgets/cancellation_flow.dart';

// Cierre y cancelación en v2 (2026-10-23): encabezado único con el subpaso, error junto al botón y
// «reparación» donde corresponde.
Future<void> _abrir(WidgetTester t, Map<String, dynamic> ticket, {ThemeData? tema}) async {
  t.view.physicalSize = const Size(1200, 4200);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(
        theme: tema ?? AppTheme.light,
        home: CierreInstalacionScreen(ticket: ticket),
      ),
    ),
  );
  await t.pump();
}

void main() {
  testWidgets('instalación: encabezado del subpaso y error junto al botón si faltan fotos', (t) async {
    await _abrir(t, {'id': 'i76', 'type': 'instalacion'});
    expect(find.text('Fotos de la instalación'), findsOneWidget);
    expect(find.text('Cierre · paso 1 de 3'), findsOneWidget);
    expect(find.text('Tomar foto'), findsNWidgets(4));

    await t.tap(find.text('Siguiente: entrega'));
    await t.pump();
    expect(find.text('Faltan fotos: toma las 4 para seguir.'), findsOneWidget);
    expect(find.text('Fotos de la instalación'), findsOneWidget, reason: 'sin fotos no avanza');
  });

  testWidgets('reparación: una foto con su fila para agregar otra, en tema oscuro sin errores de diseño', (t) async {
    await _abrir(t, {'id': 'i80', 'type': 'reparacion'}, tema: AppTheme.dark);
    expect(find.text('Fotos de la reparación'), findsWidgets);
    expect(find.text('Foto 1'), findsOneWidget);
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('cancelar una reparación dice «reparación», no «instalación»', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(onPressed: () => showCancellationFlow(ctx, {'id': 'i80', 'type': 'reparacion'}), child: const Text('abrir')),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('Cancelar reparación'), findsOneWidget);
    expect(find.text('Mal clima impide reparar'), findsOneWidget);
    expect(find.text('Cancelar instalación'), findsNothing);
  });
}
