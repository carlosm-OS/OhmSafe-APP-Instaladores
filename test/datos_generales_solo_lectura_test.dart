// Nombre, apellidos, teléfono, correo y CURP son de sólo lectura en la app: sólo el equipo de
// OhmSafe los corrige en Odoo (el backend además rechaza cualquier cambio con 403).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohmsafe_app/controllers/app_state.dart';
import 'package:ohmsafe_app/controllers/app_state_provider.dart';
import 'package:ohmsafe_app/core/di/injection_container.dart';
import 'package:ohmsafe_app/core/error/failures.dart';
import 'package:ohmsafe_app/core/network/result.dart';
import 'package:ohmsafe_app/core/theme/app_theme.dart';
import 'package:ohmsafe_app/features/perfil/domain/entities/perfil.dart';
import 'package:ohmsafe_app/features/perfil/domain/repositories/perfil_repository.dart';
import 'package:ohmsafe_app/screens/datos_generales_screen.dart';

/// Repositorio falso: sin red; la pantalla se queda con los valores locales.
class _PerfilSinRed implements PerfilRepository {
  @override
  Future<Result<Perfil>> getPerfil() async => const FailureResult(NetworkFailure());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => sl.registerSingleton<PerfilRepository>(_PerfilSinRed()));

  testWidgets('los datos de identidad no se pueden editar y no hay botón Guardar', (tester) async {
    await tester.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: const DatosGeneralesScreen()),
    ));
    await tester.pump();
    final campos = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(campos.length, 5);
    expect(campos.every((c) => c.readOnly), isTrue);
    expect(find.text('Guardar'), findsNothing);
    expect(find.textContaining('sólo los puede corregir el equipo de OhmSafe'), findsOneWidget);
    expect(find.text('Mora Gutierrez'), findsNothing);
  });
}
