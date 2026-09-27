import 'package:flutter/material.dart';

import '../controllers/app_state_provider.dart';
import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../core/error/exceptions.dart';
import '../core/push/push_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Pantalla de bloqueo (nivel A): Face ID desbloquea el uso del refresh
/// guardado y, si el servidor lo acepta, entra al home. «Usar contraseña»
/// cierra la sesión guardada y va al login. Se usa al arrancar y al volver del
/// fondo pasados 15 minutos.
class BloqueoScreen extends StatefulWidget {
  const BloqueoScreen({super.key, required this.onToggleTheme, this.alDesbloquear});

  final VoidCallback onToggleTheme;

  /// Si viene (bloqueo al volver del fondo), al desbloquear sólo se cierra
  /// esta pantalla; si no (arranque), se navega al home.
  final VoidCallback? alDesbloquear;

  @override
  State<BloqueoScreen> createState() => _BloqueoScreenState();
}

class _BloqueoScreenState extends State<BloqueoScreen> {
  String _nombre = 'biometría';
  String? _email;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final manager = sl.get<SessionManager>();
    sl.get<BiometriaService>().nombre().then((n) {
      if (mounted) setState(() => _nombre = n);
    });
    manager.emailGuardado().then((e) {
      if (mounted) setState(() => _email = e);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final ok = await sl.get<BiometriaService>().autenticar('Desbloquea OhmSafe Instaladores');
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _ocupado = false;
        _error = 'No se reconoció tu $_nombre. Inténtalo de nuevo o usa tu contraseña.';
      });
      return;
    }
    await _entrar();
  }

  Future<void> _entrar() async {
    try {
      final sesion = await sl.get<AuthRepository>().restaurar();
      if (!mounted) return;
      if (sesion == null) {
        _irAlLogin(mensaje: 'Tu sesión venció. Entra de nuevo con tu contraseña.');
        return;
      }
      await AppStateProvider.of(context).seedFromSesion(sesion);
      PushService.instance.registrarToken();
      if (!mounted) return;
      if (widget.alDesbloquear != null) {
        widget.alDesbloquear!();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)),
        (_) => false,
      );
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'Sin conexión. Revisa tu red e inténtalo de nuevo.';
      });
    }
  }

  Future<void> _usarContrasena() async {
    await sl.get<AuthRepository>().logout();
    if (!mounted) return;
    _irAlLogin();
  }

  void _irAlLogin({String? mensaje}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme, aviso: mensaje)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esCara = _nombre == 'Face ID';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.lock_outline_rounded, size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Sesión protegida', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (_email != null && _email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_email!, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
                const SizedBox(height: 28),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _ocupado ? null : _desbloquear,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: _ocupado
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Icon(esCara ? Icons.face_retouching_natural : Icons.fingerprint),
                    label: Text('Desbloquear con $_nombre', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _ocupado ? null : _usarContrasena,
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Usar contraseña', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
