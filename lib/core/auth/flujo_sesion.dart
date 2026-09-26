import 'package:flutter/material.dart';

import '../../screens/home_screen.dart';
import '../../screens/invitacion_biometria_screen.dart';
import '../di/injection_container.dart';
import 'biometria.dart';
import 'session_manager.dart';

/// Tras entrar (con contraseña o tras crear la definitiva) decide si toca la
/// invitación a Face ID antes del home. Se muestra UNA vez, sólo si el
/// dispositivo tiene biometría enrolada y aún no está activada.
Future<void> irAlHomeTrasEntrar(BuildContext context, {required VoidCallback onToggleTheme, bool promptFoto = false}) async {
  final manager = sl.get<SessionManager>();
  final biometria = sl.get<BiometriaService>();
  final invitar = !await manager.biometriaActivada() && !await manager.invitacionMostrada() && await biometria.disponible();
  if (!context.mounted) return;
  final home = MaterialPageRoute<void>(builder: (_) => HomeScreen(onToggleTheme: onToggleTheme, promptFoto: promptFoto));
  if (!invitar) {
    Navigator.of(context).pushAndRemoveUntil(home, (_) => false);
    return;
  }
  await manager.marcarInvitacionMostrada();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => InvitacionBiometriaScreen(
        onTerminar: (ctx) => Navigator.of(ctx).pushAndRemoveUntil(home, (_) => false),
      ),
    ),
    (_) => false,
  );
}
