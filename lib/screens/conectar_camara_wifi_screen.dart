import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/di/injection_container.dart';
import '../core/ezviz/emparejador_ezviz.dart';
import '../core/utils/etiqueta_ezviz.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/hoja_decision.dart';
import '../widgets/ohm_gradient_button.dart';
import 'escanear_serie_screen.dart';

/// «Conectar cámara EZVIZ a la Wi‑Fi» (2026-10-17, fase 2 de docs/instalador-wifi.md del backend).
///
/// El instalador escanea (o escribe) la etiqueta de la cámara, el cliente escribe la contraseña de
/// su Wi‑Fi en este teléfono, y la app se la pasa a la cámara con el SDK de EZVIZ usando la cuenta
/// de la casa. Al terminar, la cámara queda registrada en la casa con el NOMBRE de la red; la
/// contraseña no se guarda en ningún lado. Devuelve (pop) `true` si se registró.
class ConectarCamaraWifiScreen extends StatefulWidget {
  const ConectarCamaraWifiScreen({super.key, required this.ordenId, this.emparejador});
  final String ordenId;

  /// Las pruebas inyectan uno con un puente falso.
  final EmparejadorEzviz? emparejador;

  @override
  State<ConectarCamaraWifiScreen> createState() => _ConectarCamaraWifiScreenState();
}

class _ConectarCamaraWifiScreenState extends State<ConectarCamaraWifiScreen> {
  late final EmparejadorEzviz _emp = widget.emparejador ?? EmparejadorEzviz(repo: sl.get<OrdenesRepository>(), ordenId: widget.ordenId);
  final _serie = TextEditingController();
  final _codigo = TextEditingController();
  final _red = TextEditingController();
  final _contrasena = TextEditingController();
  final _nombre = TextEditingController();
  bool _verContrasena = false;
  bool _leyendoRed = true;

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
    for (final c in [_serie, _codigo, _red, _contrasena, _nombre]) {
      c.dispose();
    }
    super.dispose();
  }

  void _cambio() {
    if (!mounted) return;
    setState(() {});
    if (_emp.etapa == EtapaEzviz.listo) {
      _contrasena.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cámara «${_nombre.text.trim()}» conectada y guardada')));
      Navigator.pop(context, true);
    }
  }

  /// La red actual del teléfono para prellenarla (hace falta ubicación en iOS y Android).
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

  Future<void> _escanear() async {
    final crudo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EscanearSerieScreen(leer: (t) => EtiquetaEzviz.leer(t) == null ? '' : t, indicacion: 'Apunta al código QR de la etiqueta de la cámara'),
      ),
    );
    if (crudo == null || !mounted) return;
    final e = EtiquetaEzviz.leer(crudo);
    if (e == null) return;
    setState(() {
      _serie.text = e.serie;
      if (e.codigo.isNotEmpty) _codigo.text = e.codigo;
      if (_nombre.text.isEmpty && e.modelo != null) _nombre.text = 'Cámara ${e.modelo}';
    });
  }

  bool get _completo =>
      EtiquetaEzviz.pareceSerie(_serie.text) && EtiquetaEzviz.pareceCodigo(_codigo.text) && _red.text.trim().isNotEmpty && _nombre.text.trim().isNotEmpty;

  Future<void> _empezar() async {
    FocusScope.of(context).unfocus();
    if (_contrasena.text.isEmpty) {
      final sinClave = await mostrarHojaDecision(
        context,
        titulo: '¿La red no tiene contraseña?',
        texto: 'Si la Wi‑Fi de la casa tiene contraseña, pídesela al cliente y que la escriba aquí.',
        seguir: 'Conectar sin contraseña',
        salir: 'Escribir la contraseña',
      );
      if (sinClave != true) return;
    }
    await _emp.empezar(serie: _serie.text, codigo: _codigo.text, red: _red.text, contrasena: _contrasena.text, nombre: _nombre.text);
  }

  Future<void> _salir() async {
    if (_emp.ocupado) {
      final seguir = await mostrarHojaDecision(
        context,
        titulo: '¿Dejar de conectar la cámara?',
        texto: 'Lo que llevas de este paso no se guarda; la cámara se queda sin registrar y puedes volver a empezar cuando quieras.',
        seguir: 'Seguir conectando',
        salir: 'Salir sin conectar',
        pierde: true,
      );
      if (seguir != false || !mounted) return;
      await _emp.cancelar();
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ocupado = _emp.ocupado;
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
              EncabezadoFlujo(titulo: 'Conectar cámara a la Wi‑Fi', alVolver: _salir),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (ocupado) EsperandoSenal(titulo: _emp.texto, texto: 'No cierres la app ni te alejes de la cámara. Puede tardar hasta 3 minutos.'),
                    const EtiquetaSeccion(
                      'Antes de empezar',
                      tituloAyuda: 'Cómo preparar la cámara',
                      ayuda: [
                        'Conecta la cámara a la corriente y espera 2 minutos a que esté lista.',
                        'Si ya se usó antes, mantén RESET 10–15 s hasta que la luz parpadee.',
                        'Este teléfono debe estar en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»); la cámara no se conecta a redes de 5 GHz.',
                        'Si el teléfono pregunta si quieres conectarte a la red de la cámara, acepta.',
                      ],
                    ),
                    TarjetaFlujo(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Punto('1', 'Enchufa la cámara y espera a que la luz parpadee: así está lista para conectarse.'),
                          const _Punto(
                            '2',
                            'Conecta este teléfono a la Wi‑Fi de la casa, a la red de 2.4 GHz: si el módem tiene dos redes, es la que no dice «5G» en el nombre.',
                          ),
                          const _Punto('3', 'Ten al cliente cerca: él escribe la contraseña de su Wi‑Fi en este teléfono.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const EtiquetaSeccion(
                      'La cámara',
                      tituloAyuda: 'Etiqueta de la cámara',
                      ayuda: [
                        'Serie (S/N) y código de verificación de 6 letras: están en la etiqueta de la cámara o de la caja.',
                        'Escanea el QR de la etiqueta y se llenan solos.',
                      ],
                    ),
                    TextField(
                      controller: _serie,
                      enabled: !ocupado,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Número de serie',
                        helperText: 'En la etiqueta, como S/N.',
                        suffixIcon: IconButton(
                          tooltip: 'Escanear la etiqueta',
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: ocupado ? null : _escanear,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codigo,
                      enabled: !ocupado,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Código de verificación', helperText: '6 letras, en la misma etiqueta.', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nombre,
                      enabled: !ocupado,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Cochera', counterText: ''),
                    ),
                    const SizedBox(height: 20),
                    const EtiquetaSeccion(
                      'La Wi‑Fi de la casa',
                      tituloAyuda: 'Red y contraseña',
                      ayuda: [
                        'El nombre de la red se guarda en la ficha de la casa: si el cliente cambia de módem, soporte sabrá a qué red estaba la cámara.',
                        'La contraseña la escribe el cliente, sólo sirve para pasársela a la cámara y no se guarda.',
                      ],
                    ),
                    TextField(
                      controller: _red,
                      enabled: !ocupado,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nombre de la red (Wi‑Fi)',
                        helperText: _leyendoRed
                            ? 'Leyendo la red del teléfono…'
                            : 'Es la red a la que está conectado este teléfono. Si no es la de la casa, cambia la Wi‑Fi del teléfono y vuelve aquí.',
                        suffixIcon: _leyendoRed
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
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
                          tooltip: _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
                          icon: Icon(_verContrasena ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // El error va junto al botón (v2).
                    if (_emp.etapa == EtapaEzviz.error)
                      MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: 'No se pudo conectar la cámara', texto: _emp.error),
                    OhmGradientButton(
                      label: _emp.etapa == EtapaEzviz.error ? 'Volver a intentar' : 'Conectar la cámara',
                      icon: Icons.wifi_rounded,
                      loading: ocupado,
                      loadingLabel: 'Conectando la cámara…',
                      onPressed: ocupado || !_completo ? null : _empezar,
                    ),
                    if (ocupado) ...[const SizedBox(height: 12), BotonSecundario(etiqueta: 'Dejar de conectar', onPressed: _salir)],
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
            child: Text(
              n,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
