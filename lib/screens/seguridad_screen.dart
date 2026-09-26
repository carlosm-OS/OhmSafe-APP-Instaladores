import 'package:flutter/material.dart';

import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../widgets/notification_bell.dart';

/// Perfil › Seguridad: activar o apagar la entrada con Face ID. Apagarla
/// también pide biometría (o el código del teléfono) para que nadie la quite
/// con el teléfono desbloqueado en la mano.
class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  bool _disponible = false;
  bool _activada = false;
  bool _cargando = true;
  String _nombre = 'biometría';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final bio = sl.get<BiometriaService>();
    final manager = sl.get<SessionManager>();
    final disponible = await bio.disponible();
    final nombre = await bio.nombre();
    final activada = await manager.biometriaActivada();
    if (!mounted) return;
    setState(() {
      _disponible = disponible;
      _nombre = nombre;
      _activada = activada;
      _cargando = false;
    });
  }

  Future<void> _cambiar(bool valor) async {
    final bio = sl.get<BiometriaService>();
    final ok = await bio.autenticar(valor ? 'Confirma para entrar con $_nombre' : 'Confirma para dejar de usar $_nombre');
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo confirmar. No se hicieron cambios.')));
      return;
    }
    await sl.get<SessionManager>().setBiometriaActivada(valor);
    if (!mounted) return;
    setState(() => _activada = valor);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad'), actions: const [NotificationBell(), SizedBox(width: 8)]),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _activada && _disponible,
                  onChanged: _disponible ? _cambiar : null,
                  title: Text('Entrar con $_nombre', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _disponible
                        ? 'Desbloquea tu sesión sin escribir la contraseña. Se vuelve a pedir tras 15 minutos en segundo plano.'
                        : 'Este teléfono no tiene $_nombre configurado. Actívalo en los ajustes del sistema.',
                  ),
                  secondary: Icon(_nombre == 'Face ID' ? Icons.face_retouching_natural : Icons.fingerprint, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu sesión queda guardada de forma segura en este teléfono. Al cambiar tu contraseña se cierran las sesiones de tus otros dispositivos.',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
    );
  }
}
