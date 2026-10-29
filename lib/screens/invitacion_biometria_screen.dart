import 'package:flutter/material.dart';

import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';

/// «Entra con Face ID»: aparece una vez tras el primer inicio de sesión.
/// Activar exige pasar la biometría ahí mismo; «Ahora no» sigue al home y se
/// puede activar después en Perfil › Seguridad.
class InvitacionBiometriaScreen extends StatefulWidget {
  const InvitacionBiometriaScreen({super.key, required this.onTerminar});

  final void Function(BuildContext context) onTerminar;

  @override
  State<InvitacionBiometriaScreen> createState() => _InvitacionBiometriaScreenState();
}

class _InvitacionBiometriaScreenState extends State<InvitacionBiometriaScreen> {
  String _nombre = 'biometría';
  bool _ocupado = false;

  /// No se pudo confirmar: el aviso va junto al botón (v2: los errores no van en SnackBar).
  String? _error;

  @override
  void initState() {
    super.initState();
    sl.get<BiometriaService>().nombre().then((n) {
      if (mounted) setState(() => _nombre = n);
    });
  }

  Future<void> _activar() async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final ok = await sl.get<BiometriaService>().autenticar('Confirma para entrar con $_nombre', soloBiometria: true);
    if (!mounted) return;
    if (ok) {
      await sl.get<SessionManager>().setBiometriaActivada(true);
      if (!mounted) return;
      widget.onTerminar(context);
      return;
    }
    setState(() {
      _ocupado = false;
      _error = 'No se pudo confirmar con $_nombre';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final esCara = _nombre == 'Face ID';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(esCara ? Icons.face_rounded : Icons.fingerprint_rounded, size: 96, color: cs.primary),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text('Entra con $_nombre', textAlign: TextAlign.center, style: theme.textTheme.displayMedium),
              ),
              const SizedBox(height: 12),
              Text(
                'La próxima vez no tendrás que escribir tu correo ni tu contraseña. Tu sesión se queda protegida en este teléfono.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: MensajeFlujo(
                    icono: Icons.error_outline_rounded,
                    color: cs.error,
                    titulo: _error!,
                    texto: 'Vuelve a intentar, o actívalo después en Mi cuenta › Seguridad.',
                  ),
                ),
              OhmGradientButton(
                label: _error != null ? 'Volver a intentar' : 'Activar $_nombre',
                loading: _ocupado,
                loadingLabel: 'Esperando tu $_nombre…',
                onPressed: _activar,
              ),
              const SizedBox(height: 12),
              BotonSecundario(etiqueta: 'Ahora no', onPressed: _ocupado ? null : () => widget.onTerminar(context)),
            ],
          ),
        ),
      ),
    );
  }
}
