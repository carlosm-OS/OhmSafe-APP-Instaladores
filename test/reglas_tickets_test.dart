// Reglas de las tarjetas de instalación. Nacieron de un caso real: al
// terminar la instalación, el ticket seguía apareciendo en su día y ofrecía
// "Iniciar ruta de servicio" — una acción que además vuelve a avisarle al
// cliente que el técnico va en camino.
//
//   Regla 1: una orden completada o cancelada sale de la lista de trabajo
//            (y del conteo del calendario). Vive en Historial.
//   Regla 2: una orden cerrada no ofrece acción de trabajo.
//   Regla 3: sin fecha agendada no hay ruta que iniciar (agendar es de
//            operaciones, no del instalador).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/config/env_config.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/network/dio_client.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/notificaciones/data/notificaciones_repository.dart';
import 'package:ohmsafe_app/features/ordenes/domain/entities/orden.dart';
import 'package:ohmsafe_app/features/ordenes/domain/entities/tarifas.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/screens/instalaciones_screen.dart';

/// Repositorio de prueba: devuelve exactamente las órdenes del caso.
class _RepoFalso implements OrdenesRepository {
  final List<Orden> ordenes;
  _RepoFalso(this.ordenes);

  @override
  Future<Result<List<Orden>>> getOrdenes({required String tipo}) async =>
      Success(ordenes.where((o) => o.tipo == tipo).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} no se usa en esta prueba');
}

Orden _orden({
  required String id,
  required String estado,
  required String pasoActual,
  String? fechaAgendada,
}) =>
    Orden(
      id: id,
      tipo: 'instalacion',
      titulo: 'Instalación $id',
      estado: estado,
      urgente: false,
      cliente: 'Cliente $id',
      direccion: 'Calle 1',
      ciudad: 'CDMX',
      cp: '06700',
      telefono: '+525500000000',
      metraje: '80',
      fechaCreacion: '2026-09-01 10:00:00',
      diasAbierto: '3',
      fechaAgendada: fechaAgendada,
      agendado: fechaAgendada != null,
      pasoActual: pasoActual,
    );

void main() {
  String hoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} 10:00:00';
  }

  Future<void> abrir(WidgetTester tester, List<Orden> ordenes) async {
    sl.registerSingleton<OrdenesRepository>(_RepoFalso(ordenes));
    sl.registerSingleton<EnvConfig>(const EnvConfig(
      environment: Environment.development,
      apiBaseUrl: 'http://localhost',
      hubspotApiKey: 'test',
    ));
    sl.registerSingleton<NotificacionesRepository>(
      NotificacionesRepository(dioClient: DioClient(envConfig: sl.get<EnvConfig>())),
    );
    await tester.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: const InstalacionesScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('regla 1: una instalación terminada sale de la lista del día',
      (tester) async {
    await abrir(tester, [
      _orden(id: 'A', estado: 'completo', pasoActual: 'completo', fechaAgendada: hoy()),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('Instalación A'), findsNothing,
        reason: 'lo terminado pertenece al historial, no a la lista de trabajo');
    expect(find.text('Iniciar ruta de servicio'), findsNothing,
        reason: 'jamás debe ofrecer reiniciar un servicio cerrado');
  });

  testWidgets('regla 1: una cancelada tampoco ocupa el día', (tester) async {
    await abrir(tester, [
      _orden(id: 'B', estado: 'cancelado', pasoActual: 'cancelado', fechaAgendada: hoy()),
    ]);
    expect(find.text('Instalación B'), findsNothing);
  });

  testWidgets('una orden viva sí se muestra y ofrece iniciar ruta', (tester) async {
    await abrir(tester, [
      _orden(id: 'C', estado: 'por_hacer', pasoActual: 'iniciar_ruta', fechaAgendada: hoy()),
    ]);
    expect(find.text('Instalación C'), findsOneWidget);
    await tester.tap(find.text('Instalación C'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar ruta de servicio'), findsOneWidget);
  });

  testWidgets('regla 2: una orden a medias ofrece continuar, no reiniciar',
      (tester) async {
    await abrir(tester, [
      _orden(id: 'D', estado: 'en_curso', pasoActual: 'cierre', fechaAgendada: hoy()),
    ]);
    await tester.tap(find.text('Instalación D'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar · Cierre y firma'), findsOneWidget);
    expect(find.text('Iniciar ruta de servicio'), findsNothing);
  });

  testWidgets('regla 3: sin fecha agendada no se puede iniciar ruta',
      (tester) async {
    await abrir(tester, [
      _orden(id: 'E', estado: 'por_hacer', pasoActual: 'agendar'),
    ]);
    expect(find.text('Pendientes de agendar'), findsOneWidget);
    await tester.tap(find.text('Instalación E'));
    await tester.pumpAndSettle();
    // La tarjeta no ofrece botón: explica que falta agendar, y agendar es de
    // operaciones, no del instalador.
    expect(find.byType(ElevatedButton), findsNothing);
    expect(
      find.text('Pendiente de agendar — el equipo de servicio confirmará día y hora'),
      findsOneWidget,
    );
  });
}
