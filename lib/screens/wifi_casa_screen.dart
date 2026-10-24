import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/di/injection_container.dart';
import '../core/tuya/tuya_puente.dart';
import '../core/wifi/redes_wifi.dart';
import '../core/wifi/wifi_casa_local.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../widgets/campo_red_wifi.dart';
import '../widgets/hoja_decision.dart';
import '../widgets/ohm_gradient_button.dart';

/// Paso «Wi‑Fi de la casa» (Carlos, 2026-10-22), antes de «Agregar dispositivos».
///
/// El cliente escribe la contraseña UNA vez y la usan los sensores y cámaras Wi‑Fi y, si la casa
/// lleva energizador (OhmBox), el energizador como segunda conexión además de la red celular. No todas las casas la
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

  /// «Omitir» también guarda; así sólo su botón dice que está trabajando (auditoría 2026-10-23).
  bool _omitiendo = false;
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
      // v2 (2026-10-23): decisión en hoja desde abajo, con verbos.
      final sinClave = await mostrarHojaDecision(
        context,
        titulo: '¿La red no tiene contraseña?',
        texto: 'Si la Wi‑Fi de la casa tiene contraseña, pídesela al cliente y que la escriba aquí.',
        seguir: 'Guardar sin contraseña',
        salir: 'Escribir la contraseña',
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
      _omitiendo = true;
      _error = null;
    });
    final r = await _repo.wifiCasaGuardar(_id, omitir: true);
    if (!mounted) return;
    if (r.isFailure) {
      setState(() {
        _guardando = false;
        _omitiendo = false;
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
    final ohm = context.ohm;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoFlujo(
              titulo: 'Wi‑Fi de la casa',
              subtitulo: 'Opcional · para sensores, cámaras y el energizador',
              alVolver: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const BouncingScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Captúrala una sola vez: la usan los sensores y cámaras Wi‑Fi y, si la casa lleva energizador, '
                      'será su segunda conexión además de la red celular. Si esta casa no la necesita, omite el paso; '
                      'puedes volver aquí cuando quieras.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_estado == 'omitida')
                    MensajeFlujo(
                      icono: Icons.info_outline_rounded,
                      color: ohm.info,
                      titulo: 'Este paso estaba omitido',
                      texto: 'Si la casa sí la necesita, captúrala ahora y toca «Guardar Wi‑Fi de la casa».',
                    ),
                  const EtiquetaSeccion(
                    'La red',
                    tituloAyuda: 'Red y contraseña',
                    ayuda: [
                      'Pon este teléfono en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»): los equipos no se conectan a redes de 5 GHz.',
                      'El nombre de la red se guarda en la instalación para soporte.',
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
                        tooltip: _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        icon: Icon(_verContrasena ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _verContrasena = !_verContrasena),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // El error va junto al botón: qué pasó y cómo seguir.
                  if (_error != null)
                    MensajeFlujo(
                      icono: Icons.error_outline_rounded,
                      color: cs.error,
                      titulo: 'No se guardó la Wi‑Fi de la casa',
                      texto: '${_error!} Vuelve a intentar; si no hay señal, puedes omitir el paso y volver después.',
                    ),
                  OhmGradientButton(
                    label: 'Guardar Wi‑Fi de la casa',
                    icon: Icons.wifi_rounded,
                    loading: _guardando && !_omitiendo,
                    loadingLabel: 'Guardando la Wi‑Fi de la casa…',
                    onPressed: (_omitiendo || _red.text.trim().isEmpty) ? null : _guardar,
                  ),
                  const SizedBox(height: 12),
                  BotonSecundario(
                    etiqueta: _omitiendo ? 'Omitiendo la Wi‑Fi de la casa…' : 'Omitir: esta casa no la necesita',
                    onPressed: _guardando ? null : _omitir,
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
