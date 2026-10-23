import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import 'botones_dialogo.dart';
import 'ayuda.dart';

/// Tipos de sensor 433 que el instalador da de alta en sitio (2026-10-14). El control remoto volvió
/// el 2026-10-22: el backend le pone las funciones por omisión de GO (botón 1 cerca, botón 2 pánico)
/// y el cliente las cambia en su app.
const tiposRf = <({String id, String etiqueta, IconData icono})>[
  (id: 'door', etiqueta: 'Contacto de puerta', icono: Icons.sensor_door_rounded),
  (id: 'pir', etiqueta: 'Movimiento', icono: Icons.directions_walk_rounded),
  (id: 'smoke', etiqueta: 'Humo', icono: Icons.local_fire_department_rounded),
  (id: 'panic_button', etiqueta: 'Botón de pánico', icono: Icons.emergency_rounded),
  (id: 'fob', etiqueta: 'Control remoto', icono: Icons.settings_remote_rounded),
];

/// El control que vende OhmSafe es de 3 botones; si tiene menos, se guarda en cuanto capta el primero.
const botonesControl = 3;

const _fase = <String, String>{
  'btn': 'Presiona el botón del aparato',
  'open': 'Abre la puerta (separa el imán)',
  'close': 'Cierra la puerta (junta el imán)',
  'motion': 'Pasa frente al sensor',
  'alarm': 'Presiona el botón de prueba del detector',
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

  /// Error al guardar, junto a los botones (v2: antes en un SnackBar).
  String? _errorGuardar;

  bool get _esControl => widget.tipo == 'fob';
  String get _textoGuardar => _esControl ? 'Guardar control' : 'Guardar sensor';
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
    final r = await _repo.rfAprender(widget.ordenId, tipo: widget.tipo, botones: _esControl ? botonesControl : null);
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
    setState(() {
      _guardando = true;
      _errorGuardar = null;
    });
    final r = await _repo.rfTerminar(widget.ordenId, sid, nombre: nombre);
    if (!mounted) return;
    setState(() => _guardando = false);
    r.fold((_) {
      _sondeo?.cancel();
      Navigator.pop(context, nombre);
    }, (f) => setState(() => _errorGuardar = f.message));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final paso = (_s?['step'] as num?)?.toInt() ?? 1;
    final pasos = (_s?['steps'] as num?)?.toInt() ?? 1;
    final faseId = (_s?['phase'] ?? '').toString();
    final fase = _esControl && (faseId == 'btn' || faseId.isEmpty)
        ? 'Mantén presionado el botón $paso del control 1 segundo'
        : _fase[faseId] ?? 'Dispara el sensor';
    final frames = (_s?['frames'] as num?)?.toInt() ?? 0;
    final need = (_s?['need'] as num?)?.toInt() ?? 0;

    Widget estado;
    if (_error != null) {
      estado = _Caja(color: cs.error, icono: Icons.error_outline_rounded, titulo: 'No pudimos empezar', texto: '${_error!} Toca «Volver a intentar».');
    } else if (_s == null) {
      estado = _Caja(
        color: cs.onSurfaceVariant,
        icono: Icons.hearing_rounded,
        titulo: 'Preparando el energizador…',
        texto: 'En un momento empieza a escuchar el sensor.',
        cargando: true,
      );
    } else if (_viva) {
      estado = _Caja(
        color: cs.primary,
        icono: Icons.wifi_tethering_rounded,
        titulo: 'Paso $paso de $pasos: $fase',
        texto: _status == 'captured'
            ? '¡Lo captó! Sigue con lo que dice arriba.'
            : 'El energizador está escuchando ($frames de $need señales). Si tarda, acércate con el sensor.',
        cargando: true,
      );
    } else if (_status == 'done') {
      estado = _Caja(
        color: ohm.success,
        icono: Icons.check_circle_rounded,
        titulo: 'Aprendido',
        texto: _esControl
            ? 'El energizador ya reconoce el control. Botón 1: enciende y apaga la cerca. Botón 2: pánico. El cliente puede cambiarlos en su app. Ponle nombre y guárdalo.'
            : 'El energizador ya reconoce el sensor.${_s?['openOnly'] == true ? ' Este sensor sólo avisa cuando se abre.' : ''} Ponle nombre y guárdalo.',
      );
    } else if (_status == 'duplicate') {
      estado = _Caja(
        color: cs.error,
        icono: Icons.copy_all_rounded,
        titulo: 'Ya estaba aprendido',
        texto: 'Es «${(_s?['duplicateOf'] as Map?)?['name'] ?? 'otro sensor'}». No hace falta agregarlo otra vez: cierra y sigue con el siguiente.',
      );
    } else if (_status == 'timeout') {
      estado = _Caja(
        color: cs.error,
        icono: Icons.timer_off_rounded,
        titulo: 'Se acabó el tiempo',
        texto: 'No llegó ninguna señal. Acércate al energizador con el sensor y toca «Volver a intentar».',
      );
    } else if (_status == 'full') {
      // v2 (2026-10-23): además de qué pasó, cómo seguir.
      estado = _Caja(
        color: cs.error,
        icono: Icons.block_rounded,
        titulo: 'Ya no caben más',
        texto:
            'El energizador llegó al máximo de sensores de este tipo. Cierra y avisa a soporte para liberar un lugar; los demás tipos sí los puedes agregar.',
      );
    } else {
      final motivo = (_s?['error'] ?? '').toString().trim();
      estado = _Caja(
        color: cs.error,
        icono: Icons.error_outline_rounded,
        titulo: 'Se detuvo',
        texto: '${motivo.isEmpty ? 'El energizador dejó de escuchar.' : motivo} Toca «Volver a intentar» para empezar de nuevo.',
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Agregar ${widget.etiqueta.toLowerCase()}', style: theme.textTheme.headlineSmall)),
                const InfoAyuda(
                  titulo: 'Cómo se agrega un sensor inalámbrico',
                  puntos: [
                    'El energizador escucha la señal del sensor inalámbrico.',
                    'Haz lo que diga la pantalla: abrir la puerta, pasar frente al sensor o apretar su botón.',
                    'Cuando lo reconoce, le pones nombre y se guarda.',
                    'Si tarda, acércate al energizador con el sensor.',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            estado,
            if (_puedeGuardar) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _nombre,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: _esControl ? 'Nombre del control' : 'Nombre del sensor',
                  hintText: _esControl ? 'Ej. Control de Carlos' : 'Ej. Puerta de la cocina',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_errorGuardar != null)
              MensajeFlujo(
                icono: Icons.error_outline_rounded,
                color: cs.error,
                titulo: 'No se guardó',
                texto: '${_errorGuardar!} Toca «$_textoGuardar» otra vez.',
              ),
            if ((!_viva && !_puedeGuardar && _s != null) || _error != null)
              BotonesDialogo(secundario: 'Cerrar', onSecundario: _cancelar, primario: 'Volver a intentar', onPrimario: _empezar)
            else
              BotonesDialogo(
                secundario: _viva || _s == null ? 'Dejar de escuchar' : 'Cerrar',
                onSecundario: _guardando ? null : _cancelar,
                primario: _textoGuardar,
                onPrimario: _puedeGuardar ? _guardar : null,
                primarioCargando: _guardando,
                primarioCargandoTexto: _esControl ? 'Guardando el control…' : 'Guardando el sensor…',
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
    final cs = theme.colorScheme;
    // v2 (2026-10-23): grupo gris claro sin borde sobre la hoja blanca; el color va en el ícono y,
    // sólo si es error o éxito, en el título.
    final colorTitulo = color == cs.error || color == context.ohm.success ? color : cs.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.ohm.surfaceContainer, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cargando ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color)) : Icon(icono, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorTitulo),
                  ),
                  const SizedBox(height: 4),
                  Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
