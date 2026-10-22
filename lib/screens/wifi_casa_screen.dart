import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/di/injection_container.dart';
import '../core/tuya/tuya_puente.dart';
import '../core/wifi/redes_wifi.dart';
import '../core/wifi/wifi_casa_local.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/botones_dialogo.dart';
import '../widgets/campo_red_wifi.dart';
import '../widgets/ohm_gradient_button.dart';

/// Paso «Wi‑Fi de la casa» (Carlos, 2026-10-22), antes de «Agregar dispositivos».
///
/// El cliente escribe la contraseña UNA vez y la usan los sensores y cámaras Wi‑Fi y, si la casa
/// lleva OhmBox, el OhmBox como segunda conexión además de la red celular. No todas las casas la
/// necesitan: se puede omitir y volver aquí cuando haga falta. Al servidor sólo va el nombre de la
/// red; la contraseña se queda en este teléfono ([WifiCasaLocal]) y se borra al terminar.
///
/// Devuelve (pop) `'wifi_lista'`, `'wifi_omitida'` o null si sólo regresó.
class WifiCasaScreen extends StatefulWidget {
  const WifiCasaScreen({super.key, required this.ticket, this.repo, this.local, this.listador, this.leerRedActual});
  final Map<String, dynamic> ticket;

  /// Las pruebas inyectan estas piezas.
  final OrdenesRepository? repo;
  final WifiCasaLocal? local;
  final ListadorRedes? listador;
  final Future<String?> Function()? leerRedActual;

  @override
  State<WifiCasaScreen> createState() => _WifiCasaScreenState();
}

class _WifiCasaScreenState extends State<WifiCasaScreen> {
  late final OrdenesRepository _repo = widget.repo ?? sl.get<OrdenesRepository>();
  late final WifiCasaLocal _local = widget.local ?? WifiCasaLocal.instancia;
  final _red = TextEditingController();
  final _contrasena = TextEditingController();
  bool _verContrasena = false;
  bool _guardando = false;
  String? _error;

  String get _id => (widget.ticket['id'] ?? '').toString();
  String get _estado => ((widget.ticket['wifiCasa'] as Map?)?['estado'] ?? 'pendiente').toString();

  @override
  void initState() {
    super.initState();
    final redServidor = ((widget.ticket['wifiCasa'] as Map?)?['red'] ?? '').toString();
    if (redServidor.isNotEmpty) _red.text = redServidor;
    _local.leer(_id).then((w) {
      if (!mounted || w == null) return;
      setState(() {
        if (_red.text.trim().isEmpty || _red.text.trim() == w.red) _red.text = w.red;
        _contrasena.text = w.contrasena;
      });
    });
  }

  @override
  void dispose() {
    _red.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<String?> _redDelTelefono() async {
    if (widget.leerRedActual != null) return widget.leerRedActual!();
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    } catch (_) {}
    try {
      return await TuyaPuente().redActual();
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final red = _red.text.trim();
    if (red.isEmpty) return;
    if (_contrasena.text.isEmpty) {
      final sinClave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿La red no tiene contraseña?'),
          content: const Text('Si la Wi‑Fi de la casa tiene contraseña, pídesela al cliente y que la escriba aquí.'),
          actions: [
            BotonesDialogo(
              secundario: 'Volver',
              onSecundario: () => Navigator.pop(ctx, false),
              primario: 'Sí, sin contraseña',
              onPrimario: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (sinClave != true || !mounted) return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await _repo.wifiCasaGuardar(_id, red: red);
    if (!mounted) return;
    if (r.isFailure) {
      setState(() {
        _guardando = false;
        _error = r.failureValue.message;
      });
      return;
    }
    await _local.guardar(_id, WifiCasa(red: red, contrasena: _contrasena.text));
    if (!mounted) return;
    Navigator.pop(context, 'wifi_lista');
  }

  Future<void> _omitir() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final r = await _repo.wifiCasaGuardar(_id, omitir: true);
    if (!mounted) return;
    if (r.isFailure) {
      setState(() {
        _guardando = false;
        _error = r.failureValue.message;
      });
      return;
    }
    await _local.borrar(_id);
    if (!mounted) return;
    Navigator.pop(context, 'wifi_omitida');
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
            EncabezadoFlujo(titulo: 'Wi‑Fi de la casa', alVolver: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    'Captúrala una sola vez: la usan los sensores y cámaras Wi‑Fi y, si la casa lleva OhmBox, '
                    'será su segunda conexión además de la red celular. Si esta casa no la necesita, omite el paso; '
                    'puedes volver aquí cuando quieras.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo guardar', texto: _error!),
                  if (_estado == 'omitida')
                    MensajeFlujo(
                      icono: Icons.info_outline,
                      color: cs.primary,
                      titulo: 'Este paso estaba omitido',
                      texto: 'Si la casa sí la necesita, captúrala ahora y toca «Guardar Wi‑Fi de la casa».',
                    ),
                  const EtiquetaSeccion(
                    'LA RED',
                    tituloAyuda: 'Red y contraseña',
                    ayuda: [
                      'Pon este teléfono en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»): los equipos no se conectan a redes de 5 GHz.',
                      'El nombre de la red se guarda en la orden para soporte.',
                      'La contraseña la escribe el cliente. Se queda sólo en este teléfono y se borra al terminar la instalación.',
                    ],
                  ),
                  CampoRedWifi(
                    controller: _red,
                    enabled: !_guardando,
                    leerRedActual: _redDelTelefono,
                    listador: widget.listador,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contrasena,
                    enabled: !_guardando,
                    obscureText: !_verContrasena,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Contraseña de la Wi‑Fi',
                      helperText: 'La escribe el cliente. Se queda sólo en este teléfono.',
                      suffixIcon: IconButton(
                        tooltip: _verContrasena ? 'Ocultar' : 'Mostrar',
                        icon: Icon(_verContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verContrasena = !_verContrasena),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OhmGradientButton(
                    label: 'Guardar Wi‑Fi de la casa',
                    icon: Icons.wifi_rounded,
                    loading: _guardando,
                    onPressed: _guardando || _red.text.trim().isEmpty ? null : _guardar,
                  ),
                  const SizedBox(height: 12),
                  BotonSecundario(etiqueta: 'Omitir: esta casa no la necesita', onPressed: _guardando ? null : _omitir),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
