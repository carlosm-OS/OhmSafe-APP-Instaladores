import 'package:flutter/material.dart';

import '../controllers/app_state_provider.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../core/error/exceptions.dart';
import '../core/push/push_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'bloqueo_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Primera pantalla: decide a dónde ir según lo guardado en el teléfono.
///   sin sesión guardada          → login
///   sesión + biometría activada  → bloqueo (Face ID) → home
///   sesión sin biometría         → refresco silencioso → home; si murió → login
class ArranqueScreen extends StatefulWidget {
  const ArranqueScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<ArranqueScreen> createState() => _ArranqueScreenState();
}

class _ArranqueScreenState extends State<ArranqueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidir());
  }

  Future<void> _decidir() async {
    final manager = sl.get<SessionManager>();
    if (!await manager.tieneSesionGuardada()) {
      _ir(LoginScreen(onToggleTheme: widget.onToggleTheme));
      return;
    }
    if (await manager.biometriaActivada()) {
      _ir(BloqueoScreen(onToggleTheme: widget.onToggleTheme));
      return;
    }
    try {
      final sesion = await sl.get<AuthRepository>().restaurar();
      if (!mounted) return;
      if (sesion == null) {
        _ir(LoginScreen(onToggleTheme: widget.onToggleTheme, aviso: 'Tu sesión venció. Entra de nuevo con tu contraseña.'));
        return;
      }
      await AppStateProvider.of(context).seedFromSesion(sesion);
      PushService.instance.registrarToken();
      _ir(HomeScreen(onToggleTheme: widget.onToggleTheme));
    } on NetworkException {
      // Sin red no se puede rotar el refresh; la sesión sigue viva. Se entra al
      // login con aviso en vez de dejar la app colgada en el arranque.
      _ir(LoginScreen(onToggleTheme: widget.onToggleTheme, aviso: 'Sin conexión. Entra de nuevo cuando tengas red.'));
    }
  }

  void _ir(Widget pantalla) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => pantalla), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
