import 'package:flutter/material.dart';

import '../controllers/app_state_provider.dart';
import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../core/error/exceptions.dart';
import '../core/push/push_service.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
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

  /// Qué está pasando mientras [_ocupado]: primero la biometría, luego abrir la sesión.
  String _cargandoTexto = 'Esperando…';

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
      _cargandoTexto = 'Esperando tu $_nombre…';
    });
    final ok = await sl.get<BiometriaService>().autenticar('Desbloquea OhmSafe Instaladores');
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _ocupado = false;
        _error = 'No se reconoció tu $_nombre. Vuelve a intentar o usa tu contraseña.';
      });
      return;
    }
    setState(() => _cargandoTexto = 'Abriendo tu sesión…');
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
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)), (_) => false);
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'Sin conexión. Revisa tu red y vuelve a intentar.';
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
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme, aviso: mensaje),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final esCara = _nombre == 'Face ID';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.lock_outline_rounded, size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text('Sesión protegida', textAlign: TextAlign.center, style: theme.textTheme.displayMedium),
                ),
                if (_email != null && _email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _email!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                // Lo que pasó va junto al botón (v2, 2026-10-23).
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: _error!),
                  ),
                OhmGradientButton(
                  label: 'Desbloquear con $_nombre',
                  icon: esCara ? Icons.face_rounded : Icons.fingerprint_rounded,
                  loading: _ocupado,
                  loadingLabel: _cargandoTexto,
                  onPressed: _desbloquear,
                ),
                const SizedBox(height: 12),
                BotonSecundario(etiqueta: 'Usar contraseña', onPressed: _ocupado ? null : _usarContrasena),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
