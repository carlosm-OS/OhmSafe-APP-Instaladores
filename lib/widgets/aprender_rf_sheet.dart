import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

/// Tipos de sensor 433 que el instalador da de alta en sitio (2026-10-14). El control remoto
/// (llavero) se queda en el dashboard por ahora: necesita asignar función a cada botón.
const tiposRf = <({String id, String etiqueta, IconData icono})>[
  (id: 'door', etiqueta: 'Contacto de puerta', icono: Icons.sensor_door_outlined),
  (id: 'pir', etiqueta: 'Movimiento', icono: Icons.directions_walk),
  (id: 'smoke', etiqueta: 'Humo', icono: Icons.local_fire_department_outlined),
  (id: 'panic_button', etiqueta: 'Botón de pánico', icono: Icons.emergency_outlined),
];

const _fase = <String, String>{
  'btn': 'Pulsa el botón del aparato',
  'open': 'Abre la puerta (separa el imán)',
  'close': 'Cierra la puerta (junta el imán)',
  'motion': 'Pasa frente al sensor',
  'alarm': 'Pulsa el botón de prueba del detector',
};

/// Asistente de aprendizaje 433: el energizador escucha, el instalador dispara el sensor y, cuando
/// el equipo lo captura, le pone nombre. Devuelve el nombre dado de alta, o null si se canceló.
Future<String?> aprenderSensorRf(BuildContext context, {required String ordenId, required String tipo, required String etiqueta}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (_) => _AprenderRf(ordenId: ordenId, tipo: tipo, etiqueta: etiqueta),
  );
}

class _AprenderRf extends StatefulWidget {
  const _AprenderRf({required this.ordenId, required this.tipo, required this.etiqueta});
  final String ordenId;
  final String tipo;
  final String etiqueta;

  @override
  State<_AprenderRf> createState() => _AprenderRfState();
}

class _AprenderRfState extends State<_AprenderRf> {
  final OrdenesRepository _repo = sl.get<OrdenesRepository>();
  final _nombre = TextEditingController();
  Map<String, dynamic>? _s;
  String? _error;
  bool _guardando = false;
  Timer? _sondeo;

  String? get _sid => _s?['sid']?.toString();
  String get _status => (_s?['status'] ?? '').toString();
  bool get _viva => const {'listening', 'captured', 'awaiting_next'}.contains(_status);
  bool get _puedeGuardar => _s?['addr'] != null && const {'captured', 'awaiting_next', 'done'}.contains(_status);

  @override
  void initState() {
    super.initState();
    _nombre.text = widget.etiqueta;
    _empezar();
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _empezar() async {
    setState(() {
      _s = null;
      _error = null;
    });
    final r = await _repo.rfAprender(widget.ordenId, tipo: widget.tipo);
    if (!mounted) return;
    r.fold((d) {
      setState(() => _s = (d['sesion'] as Map?)?.cast<String, dynamic>());
      _sondeo?.cancel();
      _sondeo = Timer.periodic(const Duration(milliseconds: 1500), (_) => Actividad.enSilencio(_leer));
    }, (f) => setState(() => _error = f.message));
  }

  Future<void> _leer() async {
    final sid = _sid;
    if (sid == null) return;
    final r = await _repo.rfSesion(widget.ordenId, sid);
    if (!mounted) return;
    r.fold((d) {
      setState(() => _s = (d['sesion'] as Map?)?.cast<String, dynamic>() ?? _s);
      if (!_viva) _sondeo?.cancel();
    }, (_) {});
  }

  Future<void> _cancelar() async {
    _sondeo?.cancel();
    final sid = _sid;
    if (sid != null && _viva) await _repo.rfCancelar(widget.ordenId, sid);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _guardar() async {
    final sid = _sid;
    final nombre = _nombre.text.trim();
    if (sid == null || nombre.isEmpty) return;
    setState(() => _guardando = true);
    final r = await _repo.rfTerminar(widget.ordenId, sid, nombre: nombre);
    if (!mounted) return;
    setState(() => _guardando = false);
    r.fold((_) {
      _sondeo?.cancel();
      Navigator.pop(context, nombre);
    }, (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final paso = (_s?['step'] as num?)?.toInt() ?? 1;
    final pasos = (_s?['steps'] as num?)?.toInt() ?? 1;
    final fase = _fase[(_s?['phase'] ?? '').toString()] ?? 'Dispara el sensor';
    final frames = (_s?['frames'] as num?)?.toInt() ?? 0;
    final need = (_s?['need'] as num?)?.toInt() ?? 0;

    Widget estado;
    if (_error != null) {
      estado = _Caja(color: cs.error, icono: Icons.error_outline, titulo: 'No se pudo abrir el aprendizaje', texto: _error!);
    } else if (_s == null) {
      estado = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_viva) {
      estado = _Caja(
        color: cs.primary,
        icono: Icons.wifi_tethering,
        titulo: 'Paso $paso de $pasos: $fase',
        texto: _status == 'captured' ? '¡Capturado! Sigue con el siguiente paso.' : 'El energizador está escuchando. Señales recibidas: $frames de $need.',
        cargando: true,
      );
    } else if (_status == 'done') {
      estado = _Caja(
        color: ohm.success,
        icono: Icons.check_circle,
        titulo: 'Aprendido',
        texto: 'El equipo ya reconoce el sensor${_s?['openOnly'] == true ? ' (sólo manda apertura)' : ''}. Ponle nombre y guarda.',
      );
    } else if (_status == 'duplicate') {
      estado = _Caja(color: cs.error, icono: Icons.copy_all, titulo: 'Ya estaba aprendido', texto: 'Es «${(_s?['duplicateOf'] as Map?)?['name'] ?? 'otro sensor'}». No se agrega dos veces.');
    } else if (_status == 'timeout') {
      estado = _Caja(color: cs.error, icono: Icons.timer_off_outlined, titulo: 'Se acabó el tiempo', texto: 'No llegó ninguna señal. Acércate al sensor y vuelve a intentar.');
    } else if (_status == 'full') {
      estado = _Caja(color: cs.error, icono: Icons.block, titulo: 'Sin cupo', texto: 'El energizador ya no tiene lugar para este tipo de sensor.');
    } else {
      estado = _Caja(color: cs.error, icono: Icons.error_outline, titulo: 'Aprendizaje detenido', texto: (_s?['error'] ?? 'Se canceló.').toString());
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar ${widget.etiqueta.toLowerCase()} 433', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            estado,
            if (_puedeGuardar) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _nombre,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Nombre del sensor', hintText: 'Puerta de la cocina'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _guardando ? null : _cancelar, child: Text(_viva || _s == null ? 'Cancelar' : 'Cerrar')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: !_viva && !_puedeGuardar && _s != null
                      ? FilledButton(onPressed: _empezar, child: const Text('Intentar de nuevo'))
                      : FilledButton(
                          onPressed: _puedeGuardar && !_guardando ? _guardar : null,
                          child: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.color, required this.icono, required this.titulo, required this.texto, this.cargando = false});
  final Color color;
  final IconData icono;
  final String titulo;
  final String texto;
  final bool cargando;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cargando ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: color)) : Icon(icono, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 4),
                Text(texto, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
