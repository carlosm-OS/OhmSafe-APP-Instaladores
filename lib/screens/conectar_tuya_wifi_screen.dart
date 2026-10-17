import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/di/injection_container.dart';
import '../core/tuya/emparejador_tuya.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/botones_dialogo.dart';
import '../widgets/ohm_gradient_button.dart';

/// «Conectar sensor / cámara Tuya a la Wi‑Fi» (2026-10-17, fase 2 de docs/instalador-wifi.md).
///
/// El instalador pone el equipo en modo de emparejamiento, el cliente escribe la contraseña de su
/// Wi‑Fi en este teléfono, y la app le pasa la red al equipo con el **permiso de la casa** (token
/// de nube que da el backend). El equipo queda en la cuenta del cliente, visible en OhmSafe GO; aquí
/// se registra con el NOMBRE de la red. La contraseña no se guarda. Devuelve (pop) `true` si quedó.
class ConectarTuyaWifiScreen extends StatefulWidget {
  const ConectarTuyaWifiScreen({super.key, required this.ordenId, required this.clase, this.emparejador});
  final String ordenId;

  /// `sensor` o `camara`.
  final String clase;
  final EmparejadorTuya? emparejador;

  @override
  State<ConectarTuyaWifiScreen> createState() => _ConectarTuyaWifiScreenState();
}

class _ConectarTuyaWifiScreenState extends State<ConectarTuyaWifiScreen> {
  late final EmparejadorTuya _emp = widget.emparejador ?? EmparejadorTuya(repo: sl.get<OrdenesRepository>(), ordenId: widget.ordenId);
  final _nombre = TextEditingController();
  final _red = TextEditingController();
  final _contrasena = TextEditingController();
  String _tipo = 'door';
  String _modo = 'EZ';
  bool _verContrasena = false;
  bool _leyendoRed = true;

  static const _tipos = {'door': 'Puerta', 'motion': 'Movimiento', 'smoke': 'Humo'};

  bool get _esSensor => widget.clase == 'sensor';

  @override
  void initState() {
    super.initState();
    _emp.addListener(_cambio);
    _leerRed();
  }

  @override
  void dispose() {
    _emp.removeListener(_cambio);
    if (widget.emparejador == null) _emp.dispose();
    _nombre.dispose();
    _red.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _cambio() {
    if (!mounted) return;
    setState(() {});
    if (_emp.etapa == EtapaTuya.listo) {
      _contrasena.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${_nombre.text.trim()}» conectado y guardado')));
      Navigator.pop(context, true);
    }
  }

  Future<void> _leerRed() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    } catch (_) {}
    final red = await _emp.puente.redActual();
    if (!mounted) return;
    setState(() {
      _leyendoRed = false;
      if (red != null && _red.text.isEmpty) _red.text = red;
    });
  }

  bool get _completo => _nombre.text.trim().isNotEmpty && _red.text.trim().isNotEmpty;

  Future<void> _empezar() async {
    FocusScope.of(context).unfocus();
    if (_contrasena.text.isEmpty) {
      final sinClave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿La red no tiene contraseña?'),
          content: const Text('Si la Wi‑Fi de la casa tiene contraseña, pídesela al cliente y que la escriba aquí.'),
          actions: [BotonesDialogo(secundario: 'Volver', onSecundario: () => Navigator.pop(ctx, false), primario: 'Sí, sin contraseña', onPrimario: () => Navigator.pop(ctx, true))],
        ),
      );
      if (sinClave != true) return;
    }
    await _emp.empezar(clase: widget.clase, tipo: _esSensor ? _tipo : null, nombre: _nombre.text, red: _red.text, contrasena: _contrasena.text, modo: _modo);
  }

  Future<void> _salir() async {
    if (_emp.ocupado) {
      final si = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cancelar el emparejamiento?'),
          content: const Text('El equipo se quedará sin registrar. Puedes volver a intentarlo después.'),
          actions: [BotonesDialogo(secundario: 'Seguir', onSecundario: () => Navigator.pop(ctx, false), primario: 'Cancelar', onPrimario: () => Navigator.pop(ctx, true))],
        ),
      );
      if (si != true || !mounted) return;
      await _emp.cancelar();
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ocupado = _emp.ocupado;
    final que = _esSensor ? 'el sensor' : 'la cámara';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoFlujo(titulo: _esSensor ? 'Conectar sensor Wi‑Fi' : 'Conectar cámara Tuya', alVolver: _salir),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (!_emp.puente.tieneLlaves)
                      MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'Esta versión no puede emparejar equipos Tuya', texto: 'Falta la configuración de Tuya en la app. Avisa a soporte.'),
                    if (_emp.etapa == EtapaTuya.error) MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo conectar $que', texto: _emp.error),
                    if (ocupado) EsperandoSenal(titulo: _emp.texto, texto: 'No cierres la app ni te alejes del equipo. Puede tardar hasta 2 minutos.'),
                    EtiquetaSeccion(
                      'ANTES DE EMPEZAR',
                      tituloAyuda: 'Cómo preparar $que',
                      ayuda: [
                        'Enciende $que y ponlo en modo de emparejamiento: mantén su botón (RESET) 5–10 s hasta que la luz parpadee rápido.',
                        'Este teléfono conectado a la Wi‑Fi de la casa, de 2.4 GHz (no 5 GHz).',
                        'Modo rápido (EZ): el equipo escucha en la red; es el normal. Modo AP: el teléfono se une a la red «SmartLife-XXXX» del equipo; úsalo si el rápido falla.',
                        'El cliente a la mano para escribir su contraseña.',
                      ],
                    ),
                    TarjetaFlujo(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Punto('1', 'Equipo encendido con la luz parpadeando rápido (modo de emparejamiento).'),
                          const _Punto('2', 'Este teléfono en la Wi‑Fi de la casa, de 2.4 GHz.'),
                          const _Punto('3', 'El cliente a la mano para escribir su contraseña.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    EtiquetaSeccion(_esSensor ? 'EL SENSOR' : 'LA CÁMARA'),
                    if (_esSensor) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _tipo,
                        decoration: const InputDecoration(labelText: '¿Qué es?'),
                        items: [for (final e in _tipos.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: ocupado ? null : (v) => setState(() => _tipo = v ?? 'door'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _nombre,
                      enabled: !ocupado,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: 'Nombre', hintText: _esSensor ? 'Ej. Puerta principal' : 'Ej. Cochera', counterText: ''),
                    ),
                    const SizedBox(height: 20),
                    const EtiquetaSeccion(
                      'LA WI‑FI DE LA CASA',
                      tituloAyuda: 'Red y contraseña',
                      ayuda: [
                        'El nombre de la red se guarda en la ficha de la casa: si el cliente cambia de módem, soporte sabrá a qué red estaba el equipo.',
                        'La contraseña la escribe el cliente, sólo sirve para pasársela al equipo y no se guarda.',
                      ],
                    ),
                    TextField(
                      controller: _red,
                      enabled: !ocupado,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nombre de la red (Wi‑Fi)',
                        helperText: _leyendoRed ? 'Leyendo la red del teléfono…' : 'La red a la que está conectado este teléfono.',
                        suffixIcon: _leyendoRed ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contrasena,
                      enabled: !ocupado,
                      obscureText: !_verContrasena,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de la Wi‑Fi',
                        helperText: 'La escribe el cliente. No se guarda.',
                        suffixIcon: IconButton(
                          tooltip: _verContrasena ? 'Ocultar' : 'Mostrar',
                          icon: Icon(_verContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const EtiquetaSeccion('MODO'),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'EZ', label: Text('Rápido'), icon: Icon(Icons.wifi_rounded)),
                        ButtonSegment(value: 'AP', label: Text('Punto de acceso'), icon: Icon(Icons.router_outlined)),
                      ],
                      selected: {_modo},
                      onSelectionChanged: ocupado ? null : (s) => setState(() => _modo = s.first),
                    ),
                    const SizedBox(height: 24),
                    OhmGradientButton(
                      label: _emp.etapa == EtapaTuya.error ? 'Volver a intentar' : (_esSensor ? 'Conectar el sensor' : 'Conectar la cámara'),
                      icon: Icons.wifi_rounded,
                      loading: ocupado,
                      onPressed: ocupado || !_completo || !_emp.puente.tieneLlaves ? null : _empezar,
                    ),
                    if (ocupado) ...[const SizedBox(height: 12), BotonSecundario(etiqueta: 'Cancelar', onPressed: _salir)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto(this.n, this.texto);
  final String n;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35))),
        ],
      ),
    );
  }
}
