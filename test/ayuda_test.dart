import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/screens/help_screen.dart';

void main() {
  testWidgets('Ayuda muestra el número real de soporte (el mismo que se marca), no los de ejemplo', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: const HelpScreen()),
    ));
    expect(find.text('55 5199 1396'), findsNWidgets(2), reason: 'teléfono y WhatsApp');
    expect(find.text('55 1900 9090'), findsNothing);
    expect(find.text('55 5018 9090'), findsNothing);
    expect(find.text('Reportar incidencias'), findsOneWidget);
    expect(find.text('Reporte enviado correctamente'), findsNothing);
  });
}
