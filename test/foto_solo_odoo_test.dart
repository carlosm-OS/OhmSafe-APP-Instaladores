// La foto de perfil sólo la sube el equipo de OhmSafe en Odoo: en «Mi cuenta» ya no hay
// botón para cambiarla (el backend además rechaza la subida con 403).
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
import 'package:ohmsafe_app/screens/profile_main_screen.dart';

class _PerfilSinRed implements PerfilRepository {
  @override
  Future<Result<Perfil>> getPerfil() async => const FailureResult(NetworkFailure());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => sl.registerSingleton<PerfilRepository>(_PerfilSinRed()));

  testWidgets('Mi cuenta muestra la foto pero no ofrece cambiarla', (tester) async {
    await tester.pumpWidget(AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(theme: AppTheme.light, home: const ProfileMainScreen()),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.textContaining('Sube tu foto'), findsNothing);
  });
}
