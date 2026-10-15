import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';

/// Prueba del energizador (build 39, Carlos 2026-10-13): después de vincular, el instalador tiene
/// una ventana de tiempo para ENCENDER y APAGAR la cerca y enseñarle al cliente que el equipo
/// trabaja. El permiso lo da el backend sólo mientras la ventana está abierta y se retira al
/// terminar el paso (o al cerrar/cancelar). Sirena, pánico y sensores van en otro paso.
///
/// Devuelve 'prueba_terminada' al salir (terminada u omitida): el flujo sigue al cierre.
class PruebaEnergizadorScreen extends StatefulWidget {
  const PruebaEnergizadorScreen({super.key, required this.ticket});
  final Map<String, dynamic> ticket;

  @override
  State<PruebaEnergizadorScreen> createState() => _PruebaEnergizadorScreenState();
}

class _PruebaEnergizadorScreenState extends State<PruebaEnergizadorScreen> {
  final OrdenesRepository _repo = sl.get<OrdenesRepository>();
  String get _id => (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();

  Map<String, dynamic>? _estado;
  String? _error;
  bool _cargando = true;
  bool _enviando = false;
  Timer? _refresco;

  /// Lo que el instalador ya le enseñó al cliente en esta prueba (guía la pantalla: al tener las
  /// dos, «Terminar prueba» pasa a ser la acción principal).
  bool _vioEncendida = false;
  bool _vioApagada = false;
  bool get _demostrada => _vioEncendida && _vioApagada;

  /// La ventana de control existe pero no se muestra (Carlos, 2026-10-14): se abre al entrar, se
  /// renueva sola mientras la pantalla está abierta y se cierra al salir, para que el instalador no
  /// pueda controlar la cerca del cliente después.
  static const _renovarAntesDe = 5 * 60;

  @override
  void initState() {
    super.initState();
    _abrir();
    // El equipo reporta solo; cada 15 s se refresca cómo quedó (cerca, en línea) y se renueva la ventana.
    _refresco = Timer.periodic(const Duration(seconds: 15), (_) => Actividad.enSilencio(_refrescar));
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _ventana => (_estado?['ventana'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get _equipo => (_estado?['equipo'] as Map?)?.cast<String, dynamic>() ?? const {};
  bool get _abierta => _ventana['abierta'] == true;
  int get _segundosRestantes => (_ventana['segundosRestantes'] as num?)?.toInt() ?? 0;
  bool get _enLinea => _equipo['enLinea'] == true;
  bool get _cercaEncendida => _equipo['cercaEncendida'] == true;

  void _aplicar(Map<String, dynamic> e) {
    setState(() {
      _estado = e;
      _error = null;
    });
  }

  String _msg(Failure f) => f is ServerFailure && f.code.isNotEmpty ? f.message : f.message;

  Future<void> _abrir() async {
    setState(() => _cargando = true);
    final r = await _repo.pruebaAbrir(_id);
    if (!mounted) return;
    r.fold(_aplicar, (f) => setState(() => _error = _msg(f)));
    setState(() => _cargando = false);
  }

  Future<void> _refrescar() async {
    if (_enviando || !mounted) return;
    final r = await _repo.pruebaEstado(_id);
    if (!mounted) return;
    r.fold(_aplicar, (_) {});
    // Renovación silenciosa: sin reloj en pantalla, la ventana no debe vencer a media prueba.
    if (_abierta && _segundosRestantes < _renovarAntesDe) {
      final x = await _repo.pruebaExtender(_id);
      if (mounted) x.fold(_aplicar, (_) {});
    } else if (!_abierta && _estado != null) {
      final x = await _repo.pruebaAbrir(_id);
      if (mounted) x.fold(_aplicar, (_) {});
    }
  }

  Future<void> _accion(String accion) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    var r = await _repo.pruebaAccion(_id, accion);
    // Si la ventana venció (p. ej. el teléfono estuvo bloqueado), se reabre en silencio y se reintenta una vez.
    final f0 = r.isFailure ? r.failureValue : null;
    if (f0 is ServerFailure && f0.code == 'PRUEBA_NO_ABIERTA') {
      final a = await _repo.pruebaAbrir(_id);
      if (a.isSuccess) r = await _repo.pruebaAccion(_id, accion);
    }
    if (!mounted) return;
    r.fold((e) {
      _aplicar(e);
      if (accion == 'cerca_on') _vioEncendida = true;
      if (accion == 'cerca_off') _vioApagada = true;
    }, (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(f)))));
    setState(() => _enviando = false);
  }

  Future<void> _terminar({required bool omitir}) async {
    if (_enviando) return;
    if (!omitir && _cercaEncendida) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Dejas la cerca encendida?'),
          content: const Text('Al terminar ya no podrás encenderla ni apagarla desde tu app. Se queda encendida y el control lo tiene sólo el cliente.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, dejarla así')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _enviando = true);
    final r = await _repo.pruebaTerminar(_id);
    if (!mounted) return;
    // Si el backend ya no tiene ventana (venció, o nunca abrió) igual se sigue: el permiso ya no existe.
    r.fold((_) {}, (f) {
      final s = f is ServerFailure ? f : null;
      if (s == null || !{'PRUEBA_NO_ABIERTA', 'EQUIPO_NO_VINCULADO'}.contains(s.code)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(f))));
      }
    });
    setState(() => _enviando = false);
    Navigator.pop(context, 'prueba_terminada');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final muted = theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final serie = (_equipo['serie'] ?? '').toString();

    // Cualquier salida (botón, gesto o atrás del sistema) cierra la ventana de control.
    final puedeMandar = _estado != null && _enLinea && !_enviando;
    final acento = _cercaEncendida ? cs.primary : cs.onSurfaceVariant;
    final alternar = _enviando
        ? 'Enviando al energizador…'
        : (_cercaEncendida ? 'Apagar la cerca' : 'Encender la cerca');
    final iconoAlternar = _cercaEncendida ? Icons.power_settings_new_rounded : Icons.bolt_rounded;
    // Mientras envía, el botón sigue con color y spinner (loading ya ignora los toques).
    final accionAlternar = puedeMandar || (_enviando && _enLinea) ? () => _accion(_cercaEncendida ? 'cerca_off' : 'cerca_on') : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _terminar(omitir: true);
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(onPressed: () => _terminar(omitir: true), icon: const Icon(Icons.chevron_left, size: 30), tooltip: 'Salir de la prueba'),
                        const Expanded(
                          child: Text(
                            'Prueba del energizador',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const NotificationBell(),
                      ],
                    ),
                  ),
                  const PasoDeInstalacion(paso: 5),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                            children: [
                              if (_error != null) ...[
                                AvisoEnLinea(
                                  icono: Icons.error_outline,
                                  color: cs.error,
                                  titulo: 'No pudimos conectar con el equipo',
                                  texto: _error!,
                                  accion: OutlinedButton.icon(onPressed: _abrir, icon: const Icon(Icons.refresh), label: const Text('Intentar de nuevo')),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Text('Enciende y apaga la cerca frente al cliente para que vea que funciona.', style: theme.textTheme.bodyLarge?.copyWith(height: 1.4)),
                              const SizedBox(height: 16),

                              // Estado actual, grande: es lo que el cliente está mirando.
                              AnimatedContainer(
                                key: const Key('prueba-estado-cerca'),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: acento.withValues(alpha: _cercaEncendida ? 0.10 : 0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: acento.withValues(alpha: _cercaEncendida ? 0.6 : 0.25), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(color: acento.withValues(alpha: 0.15), shape: BoxShape.circle),
                                      child: Icon(_cercaEncendida ? Icons.bolt_rounded : Icons.power_off_rounded, size: 32, color: acento),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _cercaEncendida ? 'La cerca está encendida' : 'La cerca está apagada',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _cercaEncendida ? cs.primary : null),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _enLinea ? ohm.success : cs.error, shape: BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  '${_enLinea ? 'En línea' : 'Sin señal'}${serie.isEmpty ? '' : ' · $serie'}',
                                                  style: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_enLinea) ...[
                                const SizedBox(height: 10),
                                AvisoEnLinea(
                                  icono: Icons.wifi_off_rounded,
                                  color: cs.error,
                                  titulo: 'El energizador no tiene señal',
                                  texto: 'Revisa que esté conectado a la corriente y con señal. Esta pantalla se actualiza sola.',
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (!_demostrada)
                                OhmGradientButton(key: const Key('prueba-alternar'), label: alternar, icon: iconoAlternar, loading: _enviando, onPressed: accionAlternar)
                              else
                                OutlinedButton.icon(key: const Key('prueba-alternar'), onPressed: accionAlternar, icon: Icon(iconoAlternar), label: Text(alternar)),
                              const SizedBox(height: 20),

                              // Qué falta enseñarle al cliente.
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 6, 6, 12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TituloSeccion(
                                      'MUÉSTRALE AL CLIENTE · ${(_vioEncendida ? 1 : 0) + (_vioApagada ? 1 : 0)} DE 2',
                                      ayuda: const InfoAyuda(
                                        titulo: 'Control temporal de la cerca',
                                        puntos: [
                                          'Sólo puedes controlar la cerca del cliente mientras esta pantalla está abierta.',
                                          'Al terminar (o salir), ese control se retira y queda sólo en manos del cliente.',
                                          'La cerca se queda como esté en ese momento: encendida o apagada.',
                                          'La sirena y los sensores se prueban en el siguiente paso.',
                                        ],
                                      ),
                                    ),
                                    _Check(hecho: _vioEncendida, texto: 'Encendiste la cerca'),
                                    const SizedBox(height: 8),
                                    _Check(hecho: _vioApagada, texto: 'La apagaste'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (_demostrada)
                                OhmGradientButton(label: 'Terminar prueba', icon: Icons.check, loading: _enviando, onPressed: () => _terminar(omitir: false))
                              else
                                OutlinedButton.icon(onPressed: _enviando ? null : () => _terminar(omitir: false), icon: const Icon(Icons.check), label: const Text('Terminar prueba')),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _enviando ? null : () => _terminar(omitir: true), child: const Text('Salir sin probar')),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            // La barra es un Positioned: va sobre el Stack, no dentro de la columna.
            const AppBottomNav(),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.hecho, required this.texto});
  final bool hecho;
  final String texto;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ohm = context.ohm;
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            hecho ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            key: ValueKey(hecho),
            color: hecho ? ohm.success : theme.colorScheme.outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: hecho ? FontWeight.w600 : FontWeight.w400))),
      ],
    );
  }
}
