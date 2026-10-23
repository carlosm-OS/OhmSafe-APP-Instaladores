import 'package:flutter/material.dart';

import '../core/auth/biometria.dart';
import '../core/auth/session_manager.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../widgets/menu_item_tile.dart';

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

  /// No se pudo confirmar el cambio: aviso en la pantalla, no en SnackBar (v2).
  String? _error;

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
    setState(() => _error = null);
    final bio = sl.get<BiometriaService>();
    final ok = await bio.autenticar(valor ? 'Confirma para entrar con $_nombre' : 'Confirma para dejar de usar $_nombre');
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'No se pudo confirmar con $_nombre');
      return;
    }
    await sl.get<SessionManager>().setBiometriaActivada(valor);
    if (!mounted) return;
    setState(() => _activada = valor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoFlujo(titulo: 'Seguridad'),
            Expanded(
              child: _cargando
                  ? Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary)),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text('Revisando tu teléfono…', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        if (_error != null)
                          MensajeFlujo(
                            icono: Icons.error_outline_rounded,
                            color: cs.error,
                            titulo: _error!,
                            texto: 'No se hicieron cambios. Vuelve a intentar.',
                          ),
                        GrupoFilas(
                          pie:
                              'Tu sesión queda guardada de forma segura en este teléfono. Al cambiar tu contraseña se cierran las sesiones de tus otros dispositivos.',
                          children: [
                            FilaFlujo(
                              leading: MosaicoIcono(icono: _nombre == 'Face ID' ? Icons.face_rounded : Icons.fingerprint_rounded, color: context.ohm.info),
                              titulo: 'Entrar con $_nombre',
                              subtitulo: _disponible
                                  ? 'Desbloquea tu sesión sin escribir la contraseña. Se vuelve a pedir tras 15 minutos en segundo plano.'
                                  : 'Este teléfono no tiene $_nombre configurado. Actívalo en los ajustes del sistema.',
                              trailing: Switch.adaptive(value: _activada && _disponible, onChanged: _disponible ? _cambiar : null),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
