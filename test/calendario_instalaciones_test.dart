// El calendario de Instalaciones solo mostraba días sueltos desplazables: no
// había forma de ver el mes en curso. Esta prueba fija el comportamiento nuevo
// —compacto por defecto, expandible al mes— y, sobre todo, que la cuadrícula
// se dibuje sin romper el layout (la lección del botón "Confirmar Firma", que
// existía en el árbol pero no se pintaba ni recibía toques).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/ordenes/data/datasources/ordenes_mock_data_source.dart';
import 'package:ohmsafe_app/features/ordenes/data/repositories/ordenes_repository_impl.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/instalaciones_screen.dart';

void main() {
  setUp(() {
    sl.registerSingleton<OrdenesRepository>(
      OrdenesRepositoryImpl(dataSource: OrdenesMockDataSource()),
    );
  });

  Future<void> abrirPantalla(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const InstalacionesScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('arranca compacto y ofrece ver el mes', (tester) async {
    await abrirPantalla(tester);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Ver el mes completo'), findsOneWidget);
    // La navegación entre meses solo aparece con la cuadrícula abierta.
    expect(find.bySemanticsLabel('Mes anterior'), findsNothing);
    expect(find.bySemanticsLabel('Mes siguiente'), findsNothing);
  });

  testWidgets('al expandir muestra el mes completo sin romper el layout',
      (tester) async {
    await abrirPantalla(tester);

    await tester.tap(find.bySemanticsLabel('Ver el mes completo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'la cuadrícula no debe desbordar ni forzar tamaños inválidos');

    // Los siete encabezados de la semana.
    for (final d in ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom']) {
      expect(find.text(d), findsOneWidget, reason: 'falta el encabezado $d');
    }

    // Un día que jamás cabría en la tira de una semana desde hoy.
    expect(find.text('28'), findsOneWidget);

    // Navegación entre meses y regreso a la vista compacta.
    expect(find.bySemanticsLabel('Mes anterior'), findsOneWidget);
    expect(find.bySemanticsLabel('Mes siguiente'), findsOneWidget);
    expect(find.bySemanticsLabel('Ver solo la semana'), findsOneWidget);
  });

  testWidgets('cambiar de mes no rompe la cuadrícula', (tester) async {
    await abrirPantalla(tester);
    await tester.tap(find.bySemanticsLabel('Ver el mes completo'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mes siguiente'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.bySemanticsLabel('Mes anterior'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    // Febrero y los meses de 31 días deben seguir cuadrando en 7 columnas.
    expect(find.text('Dom'), findsOneWidget);
  });
}
