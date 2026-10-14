import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../widgets/ohm_gradient_button.dart';

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

  /// La ventana de control existe pero no se muestra (Carlos, 2026-10-14): se abre al entrar, se
  /// renueva sola mientras la pantalla está abierta y se cierra al salir, para que el instalador no
  /// pueda controlar la cerca del cliente después.
  static const _renovarAntesDe = 5 * 60;

  @override
  void initState() {
    super.initState();
    _abrir();
    // El equipo reporta solo; cada 15 s se refresca cómo quedó (cerca, en línea) y se renueva la ventana.
    _refresco = Timer.periodic(const Duration(seconds: 15), (_) => _refrescar());
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
    r.fold(_aplicar, (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(f)))));
    setState(() => _enviando = false);
  }

  Future<void> _terminar({required bool omitir}) async {
    if (_enviando) return;
    if (!omitir && _cercaEncendida) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('La cerca queda encendida'),
          content: const Text('Al terminar la prueba el permiso para controlar el energizador se retira y la cerca se queda como está ahora: encendida. ¿Así la dejas?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Revisar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, terminar')),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _terminar(omitir: true);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: () => _terminar(omitir: true), icon: const Icon(Icons.chevron_left, size: 30)),
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
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          if (_error != null) ...[
                            _Aviso(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo preparar el equipo', texto: _error!),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(onPressed: _abrir, icon: const Icon(Icons.refresh), label: const Text('Intentar de nuevo')),
                            const SizedBox(height: 16),
                          ],
                          Text('Enciende y apaga la cerca con el cliente las veces que haga falta. Al terminar, el control del equipo se retira.', style: muted),
                          const SizedBox(height: 16),

                          // Estado del equipo
                          Text(
                            'EQUIPO',
                            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Fila(etiqueta: 'Serie', valor: serie.isEmpty ? '—' : serie),
                                const SizedBox(height: 8),
                                _Fila(etiqueta: 'Conexión', valor: _enLinea ? 'En línea' : 'Sin conexión', color: _enLinea ? ohm.success : cs.error),
                                const SizedBox(height: 8),
                                _Fila(etiqueta: 'Cerca', valor: _cercaEncendida ? 'Encendida (alto voltaje)' : 'Apagada', color: _cercaEncendida ? cs.secondary : cs.onSurfaceVariant),
                              ],
                            ),
                          ),
                          if (!_enLinea) ...[
                            const SizedBox(height: 10),
                            _Aviso(
                              icono: Icons.wifi_off,
                              color: cs.error,
                              titulo: 'El energizador no reporta',
                              texto: 'Revisa que esté encendido y con señal; el comando no se puede mandar hasta que esté en línea.',
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Controles
                          Row(
                            children: [
                              Expanded(
                                child: _BotonGrande(
                                  etiqueta: 'Encender cerca',
                                  icono: Icons.bolt,
                                  activo: _cercaEncendida,
                                  color: cs.secondary,
                                  habilitado: _estado != null && _enLinea && !_enviando && !_cercaEncendida,
                                  onTap: () => _accion('cerca_on'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _BotonGrande(
                                  etiqueta: 'Apagar cerca',
                                  icono: Icons.power_settings_new,
                                  activo: !_cercaEncendida,
                                  color: cs.onSurfaceVariant,
                                  habilitado: _estado != null && _enLinea && !_enviando && _cercaEncendida,
                                  onTap: () => _accion('cerca_off'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Muéstrale al cliente: con la cerca encendida hay alto voltaje en la línea. La sirena y los sensores se prueban en el siguiente paso.',
                            style: muted,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          OhmGradientButton(label: 'Terminar prueba', icon: Icons.check, loading: _enviando, onPressed: _enviando ? null : () => _terminar(omitir: false)),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _enviando ? null : () => _terminar(omitir: true), child: const Text('Omitir la prueba')),
                        ],
                      ),
              ),
              const AppBottomNav(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor, this.color});
  final String etiqueta;
  final String valor;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(
          valor,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _BotonGrande extends StatelessWidget {
  const _BotonGrande({required this.etiqueta, required this.icono, required this.activo, required this.color, required this.habilitado, required this.onTap});
  final String etiqueta;
  final IconData icono;
  final bool activo;
  final Color color;
  final bool habilitado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fondo = activo ? color.withValues(alpha: 0.12) : theme.cardColor;
    return Opacity(
      opacity: habilitado || activo ? 1 : 0.45,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: habilitado ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activo ? color : theme.dividerColor.withValues(alpha: 0.6), width: activo ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 34, color: activo ? color : cs.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  style: TextStyle(fontWeight: FontWeight.w700, color: activo ? color : cs.onSurface),
                ),
                if (activo) Text('estado actual', style: theme.textTheme.labelSmall?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.color, required this.titulo, required this.texto});
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(texto, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
