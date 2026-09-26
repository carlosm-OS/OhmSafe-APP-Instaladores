import 'package:flutter/material.dart';

import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';

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

  @override
  void initState() {
    super.initState();
    sl.get<BiometriaService>().nombre().then((n) {
      if (mounted) setState(() => _nombre = n);
    });
  }

  Future<void> _activar() async {
    setState(() => _ocupado = true);
    final ok = await sl.get<BiometriaService>().autenticar('Confirma para entrar con $_nombre', soloBiometria: true);
    if (!mounted) return;
    if (ok) {
      await sl.get<SessionManager>().setBiometriaActivada(true);
      if (!mounted) return;
      widget.onTerminar(context);
      return;
    }
    setState(() => _ocupado = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo confirmar con $_nombre. Puedes activarlo después en Perfil › Seguridad.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esCara = _nombre == 'Face ID';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Icon(esCara ? Icons.face_retouching_natural : Icons.fingerprint, size: 96, color: cs.primary),
              const SizedBox(height: 28),
              Text('Entra con $_nombre', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'La próxima vez no tendrás que escribir tu correo ni tu contraseña. Tu sesión se queda protegida en este teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.4, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _ocupado ? null : _activar,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _ocupado
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Activar $_nombre', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _ocupado ? null : () => widget.onTerminar(context),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Ahora no', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
