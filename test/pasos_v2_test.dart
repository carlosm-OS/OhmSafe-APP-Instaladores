// Sistema v2 (2026-10-23) en los pasos del servicio: el paso bloqueado dice qué falta en vez de «no
// hacer nada», la animación del camión se salta con un toque (y no aparece con Reducir movimiento),
// los contadores de la cerca tienen nombre para el lector de pantalla y el error de guardar va junto
// al botón, no en un SnackBar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/ordenes/domain/entities/orden.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/fence_installation_screen.dart';
import 'package:ohmsafe_app/screens/service_steps_screen.dart';

Map<String, dynamic> _ticket() => {
  'id': 'i76',
  'title': 'Instalación Plan Hogar',
  'type': 'instalacion',
  'isUrgent': false,
  'user': 'Carlos M',
  'details': <String, String>{
    'openDays': '1',
    'createdDate': '2026-10-14 15:00:00',
    'metraje': '70 m',
    'direccion': 'Av. Reforma 222',
    'ciudad': 'CDMX',
    'cp': '06600',
    'telefono': '5512345678',
    'origen': 'intervencion',
  },
  'wifiCasa': {'estado': 'pendiente', 'red': ''},
};

/// Repositorio de prueba: la cerca no se puede guardar.
class _RepoSinSenal implements OrdenesRepository {
  @override
  Future<Result<Orden>> getOrden(String id) async => const FailureResult(ServerFailure('Sin datos'));

  @override
  Future<Result<bool>> guardarInstalacion(String id, Map<String, dynamic> registro) async =>
      const FailureResult(ServerFailure('No hay conexión. Revisa tu internet y vuelve a intentar.'));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName} no se usa en esta prueba');
}

Widget _app(Widget home, {bool reducido = false}) => AppStateProvider(
  notifier: AppState(),
  child: MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducido),
      child: child!,
    ),
    home: home,
  ),
);

void main() {
  testWidgets('los pasos: encabezado «Instalación i76» y el bloqueado dice qué falta', (t) async {
    t.view.physicalSize = const Size(1206, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(ServiceStepsScreen(ticket: _ticket())));
    await t.pump(const Duration(seconds: 5));

    expect(find.text('Instalación i76'), findsOneWidget);
    expect(find.text('Pasos'), findsOneWidget);
    expect(find.text('Primero marca tu llegada en «Ruta».'), findsNothing);

    await t.tap(find.text('Inspección del perímetro'));
    await t.pumpAndSettle();
    expect(find.text('Primero marca tu llegada en «Ruta».'), findsOneWidget, reason: 'tocar un paso bloqueado ya no «no hace nada»');
  });

  testWidgets('el camión se salta con un toque', (t) async {
    await t.pumpWidget(_app(TruckAnimationPage(ticket: _ticket())));
    await t.pump();
    expect(find.text('Iniciando la ruta…'), findsOneWidget);
    await t.tap(find.text('Iniciando la ruta…'));
    await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 6));
    expect(find.byType(ServiceStepsScreen), findsOneWidget);
    expect(find.byType(TruckAnimationPage), findsNothing);
  });

  testWidgets('con Reducir movimiento el camión no aparece: va directo a los pasos', (t) async {
    await t.pumpWidget(_app(TruckAnimationPage(ticket: _ticket()), reducido: true));
    await t.pump();
    await t.pump();
    expect(find.byType(ServiceStepsScreen), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('cerca: contadores con nombre y el error junto al botón', (t) async {
    t.view.physicalSize = const Size(1206, 4000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    sl.registerSingleton<OrdenesRepository>(_RepoSinSenal());
    await t.pumpWidget(_app(FenceInstallationScreen(ticket: _ticket())));
    await t.pumpAndSettle();

    expect(find.text('Letrero OhmSafe'), findsOneWidget);
    expect(find.bySemanticsLabel('Agregar uno'), findsNWidgets(6));
    expect(find.bySemanticsLabel('Quitar uno'), findsNWidgets(6));

    // «Postes esquina» arranca en 5: el primer «Agregar uno» lo sube a 6.
    expect(find.text('6'), findsNothing);
    await t.tap(find.bySemanticsLabel('Agregar uno').first);
    await t.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);

    await t.tap(find.text('Guardar medidas de la cerca'));
    await t.pumpAndSettle();
    expect(find.text('No pudimos guardar las medidas de la cerca'), findsOneWidget);
    expect(find.text('No hay conexión. Revisa tu internet y vuelve a intentar.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
