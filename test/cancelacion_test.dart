import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/ordenes/domain/entities/orden.dart';
import 'package:ohmsafe_app/features/ordenes/domain/repositories/ordenes_repository.dart';
import 'package:ohmsafe_app/widgets/cancellation_flow.dart';

class _RepoCancel implements OrdenesRepository {
  final llamadas = <Map<String, dynamic>>[];
  @override
  Future<Result<Map<String, dynamic>>> cancelar(String id, {required String motivo, String? notas, String? fotoBase64, Map<String, dynamic>? ubicacion}) async {
    llamadas.add({'id': id, 'motivo': motivo, 'notas': notas});
    return const Success({'estado': 'cancelado'});
  }

  // Tras cancelar, la hoja navega al listado, que recarga las órdenes.
  @override
  Future<Result<List<Orden>>> getOrdenes({required String tipo}) async => const Success(<Orden>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('cancelar en sitio: exige motivo, «Otro» exige notas, y manda el motivo tipado al backend', (t) async {
    // Sin plugin de GPS en pruebas: el canal contesta «servicio apagado» y la hoja sigue sin ubicación.
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geolocator'), (c) async => c.method == 'isLocationServiceEnabled' ? false : null);
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final repo = _RepoCancel();
    sl.registerSingleton<OrdenesRepository>(repo);
    await t.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () => showCancellationFlow(ctx, {'id': 'i27', 'title': 'Instalación'}), child: const Text('abrir')))),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.text('No hay nadie en el domicilio'), findsOneWidget);
    expect(find.text('Mal clima impide instalar'), findsOneWidget);

    await t.tap(find.text('Confirmar cancelación'));
    await t.pump();
    expect(find.text('Elige el motivo de la cancelación.'), findsOneWidget);

    await t.tap(find.text('Otro'));
    await t.pump();
    await t.tap(find.text('Confirmar cancelación'));
    await t.pump();
    expect(find.textContaining('cuéntanos qué pasó'), findsOneWidget);
    expect(repo.llamadas, isEmpty);

    await t.tap(find.text('No hay nadie en el domicilio'));
    await t.enterText(find.byType(TextField), 'Toqué 10 minutos');
    await t.tap(find.text('Confirmar cancelación'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(repo.llamadas.single, {'id': 'i27', 'motivo': 'cliente_ausente', 'notas': 'Toqué 10 minutos'});
  });
}
