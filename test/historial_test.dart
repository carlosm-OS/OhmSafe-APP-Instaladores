import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/historial_screen.dart';

class _RepoHistorial implements OrdenesRepository {
  int llamadas = 0;
  @override
  Future<Result<List<Map<String, dynamic>>>> historial({String rango = 'todo'}) async {
    llamadas++;
    return const Success([
      {'id': 'i41', 'tipo': 'instalacion', 'titulo': 'Instalación · Plan Hogar', 'cliente': 'Carlos M', 'direccion': 'Av. 1', 'ciudad': 'CDMX',
        'estado': 'cancelado', 'fecha': '2026-09-28 22:39:00', 'canceladoEn': '2026-09-28 22:39:00', 'completadoEn': null, 'motivo': 'No hay nadie en el domicilio — sin respuesta'},
      {'id': 'i40', 'tipo': 'instalacion', 'titulo': 'Instalación · Fortress', 'cliente': 'Ana', 'direccion': 'Calle 2', 'ciudad': '',
        'estado': 'completado', 'fecha': '2026-09-20 18:00:00', 'completadoEn': '2026-09-20 18:00:00', 'canceladoEn': null, 'motivo': null},
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('el historial viene del backend y muestra las canceladas con su motivo', (t) async {
    t.view.physicalSize = const Size(1200, 2600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final repo = _RepoHistorial();
    sl.registerSingleton<OrdenesRepository>(repo);
    final estado = AppState();
    // Lo cerrado en esta sesión se conserva y no se duplica con lo del backend.
    estado.addCompletedTicket({'id': 'i40', 'title': 'Instalación · Fortress', 'type': 'instalacion'});
    estado.addCompletedTicket({'id': 'i99', 'title': 'Reparación local', 'type': 'reparacion'});

    await t.pumpWidget(AppStateProvider(notifier: estado, child: MaterialApp(theme: AppTheme.light, home: const HistorialScreen())));
    await t.pumpAndSettle();

    expect(repo.llamadas, 1);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.textContaining('Cancelada el'), findsOneWidget);
    expect(find.textContaining('Motivo: No hay nadie en el domicilio'), findsOneWidget);
    expect(find.text('Instalación · Fortress'), findsOneWidget); // una sola vez (deduplicada por id)
    expect(find.text('Reparación local'), findsOneWidget);
    expect(find.textContaining('Completado el'), findsNWidgets(2));
  });

  test('entradaHistorial convierte la fila del backend (fecha UTC de Odoo → local)', () {
    final e = AppState.entradaHistorial({'id': 'i41', 'estado': 'cancelado', 'fecha': '2026-09-28 22:39:00', 'motivo': 'Mal clima', 'titulo': 'X', 'ciudad': ''});
    expect(e['status'], 'Cancelada');
    expect(e['motivo'], 'Mal clima');
    expect((e['completedAt'] as DateTime).toUtc(), DateTime.utc(2026, 9, 28, 22, 39));
    expect((e['details'] as Map)['ciudad'], isNull);
  });
}
