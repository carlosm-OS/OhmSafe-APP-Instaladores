import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/tuya/emparejador_tuya.dart';
import '../core/utils/serie_qr.dart';
import '../core/wifi/wifi_casa_local.dart';
import '../core/wifi/redes_wifi.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/botones_dialogo.dart';
import '../widgets/ohm_gradient_button.dart';
import 'escanear_serie_screen.dart';
import 'wifi_casa_screen.dart';

/// «Conectar sensor / cámara Tuya a la Wi‑Fi» (2026-10-17, fase 2 de docs/instalador-wifi.md).
///
/// El instalador pone el equipo en modo de emparejamiento, el cliente escribe la contraseña de su
/// Wi‑Fi en este teléfono, y la app le pasa la red al equipo con el **permiso de la casa** (token
/// de nube que da el backend). El equipo queda en la cuenta del cliente, visible en OhmSafe GO; aquí
/// se registra con el NOMBRE de la red. La contraseña no se guarda. Devuelve (pop) `true` si quedó.
///
/// 2026-10-22: serie de la etiqueta opcional (se escanea o se escribe) y, al terminar, la tarjeta
/// «Equipo conectado» con lo que dijo la nube, para que el instalador confirme que es el que tiene
/// en la mano antes de salir.
class ConectarTuyaWifiScreen extends StatefulWidget {
  const ConectarTuyaWifiScreen({super.key, required this.ordenId, required this.clase, this.emparejador, this.listador, this.local});
  final String ordenId;

  /// `sensor` o `camara`.
  final String clase;
  final EmparejadorTuya? emparejador;

  /// Las pruebas inyectan un listador de redes falso.
  final ListadorRedes? listador;

  /// Wi‑Fi de la casa de la visita (las pruebas inyectan una en memoria).
  final WifiCasaLocal? local;

  @override
  State<ConectarTuyaWifiScreen> createState() => _ConectarTuyaWifiScreenState();
}

class _ConectarTuyaWifiScreenState extends State<ConectarTuyaWifiScreen> {
  late final WifiCasaLocal _local = widget.local ?? WifiCasaLocal.instancia;

  /// La Wi‑Fi del paso 4 (Carlos, 2026-10-22): aquí ya no se vuelve a pedir. Sin ella, se manda al paso.
  WifiCasa? _wifiCasa;
  bool _wifiLeida = false;

  late final EmparejadorTuya _emp = widget.emparejador ?? EmparejadorTuya(repo: sl.get<OrdenesRepository>(), ordenId: widget.ordenId);
  final _nombre = TextEditingController();
  final _red = TextEditingController();
  final _contrasena = TextEditingController();
  final _serie = TextEditingController();
  String _tipo = 'door';
  bool _conectado = false;

  /// Bluetooth primero (2026-10-22, como la app del cliente): si no ve el equipo, sigue sola en modo rápido.
  String _modo = 'BLE';

  static const _tipos = {'door': 'Puerta', 'motion': 'Movimiento', 'smoke': 'Humo'};

  bool get _esSensor => widget.clase == 'sensor';

  @override
  void initState() {
    super.initState();
    _emp.addListener(_cambio);
    _cargarWifiCasa();
  }

  /// Wi‑Fi de la casa de esta visita (paso 4): red y contraseña que el cliente escribió una vez.
  Future<void> _cargarWifiCasa() async {
    final w = await _local.leer(widget.ordenId);
    if (!mounted) return;
    setState(() {
      _wifiCasa = w;
      _wifiLeida = true;
      _red.text = w?.red ?? '';
      _contrasena.text = w?.contrasena ?? '';
    });
  }

  /// Regresa al paso «Wi‑Fi de la casa» para capturarla o cambiarla.
  Future<void> _irWifiCasa() async {
    await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => WifiCasaScreen(ticket: {'id': widget.ordenId})));
    if (mounted) await _cargarWifiCasa();
  }

  @override
  void dispose() {
    _emp.removeListener(_cambio);
    if (widget.emparejador == null) _emp.dispose();
    _nombre.dispose();
    _red.dispose();
    _contrasena.dispose();
    _serie.dispose();
    super.dispose();
  }

  void _cambio() {
    if (!mounted) return;
    if (_emp.etapa == EtapaTuya.listo && !_conectado) {
      _contrasena.clear();
      _conectado = true;
    }
    setState(() {});
  }

  bool get _completo => _nombre.text.trim().isNotEmpty && _wifiCasa != null;

  Future<void> _empezar() async {
    FocusScope.of(context).unfocus();
    // Con la Wi‑Fi del paso 4 ya se confirmó ahí si la red no tiene contraseña.
    if (_wifiCasa == null && _contrasena.text.isEmpty) {
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
      if (sinClave != true) return;
    }
    await _emp.empezar(
      clase: widget.clase,
      tipo: _esSensor ? _tipo : null,
      nombre: _nombre.text,
      red: _red.text,
      contrasena: _contrasena.text,
      modo: _modo,
      serie: _serie.text,
    );
  }

  Future<void> _escanearSerie() async {
    final leida = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const EscanearSerieScreen(leer: serieDeEtiqueta, indicacion: 'Apunta al código de la etiqueta del equipo'),
      ),
    );
    if (!mounted || leida == null || leida.trim().isEmpty) return;
    setState(() => _serie.text = leida.trim());
  }

  Future<void> _noEsEste() async {
    final id = _emp.devId ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avisa a operaciones'),
        content: Text(
          'Diles que el equipo con ID $id no es el que instalaste, para que lo quiten de la casa. '
          'Luego pon el equipo correcto en modo de emparejamiento y vuelve a conectarlo.',
        ),
        actions: [BotonesDialogo(primario: 'Entendido', onPrimario: () => Navigator.pop(ctx))],
      ),
    );
  }

  Future<void> _salir() async {
    if (_conectado) {
      Navigator.pop(context, true);
      return;
    }
    if (_emp.ocupado) {
      final si = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cancelar el emparejamiento?'),
          content: const Text('El equipo se quedará sin registrar. Puedes volver a intentarlo después.'),
          actions: [
            BotonesDialogo(
              secundario: 'Seguir',
              onSecundario: () => Navigator.pop(ctx, false),
              primario: 'Cancelar',
              onPrimario: () => Navigator.pop(ctx, true),
            ),
          ],
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
              EncabezadoFlujo(titulo: _esSensor ? 'Conectar sensor Wi‑Fi' : 'Conectar cámara Wi‑Fi', alVolver: _salir),
              Expanded(
                child: _conectado
                    ? _Conectado(emp: _emp, esSensor: _esSensor, tipo: _tipos[_tipo] ?? '', alListo: () => Navigator.pop(context, true), alNoEsEste: _noEsEste)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (!_emp.puente.tieneLlaves)
                            MensajeFlujo(
                              icono: Icons.error_outline,
                              color: cs.error,
                              titulo: 'Esta versión no puede emparejar equipos Wi‑Fi',
                              texto: 'Falta la configuración de emparejamiento en la app. Avisa a soporte.',
                            ),
                          if (_emp.etapa == EtapaTuya.error)
                            MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo conectar $que', texto: _emp.error),
                          if (ocupado) EsperandoSenal(titulo: _emp.texto, texto: 'No cierres la app ni te alejes del equipo. Puede tardar hasta 2 minutos.'),
                          EtiquetaSeccion(
                            'ANTES DE EMPEZAR',
                            tituloAyuda: 'Cómo preparar $que',
                            ayuda: [
                              'Enciende $que y ponlo en modo de emparejamiento: mantén su botón (RESET) 5–10 s hasta que la luz parpadee rápido.',
                              'Este teléfono debe estar en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»); los equipos no se conectan a redes de 5 GHz.',
                              'Bluetooth (el normal): el teléfono busca el equipo cerca y le pasa la red; ten el Bluetooth encendido. Si no lo ve en 20 segundos, la app sigue sola en modo rápido.',
                              'Modo rápido: el equipo escucha en la red. Modo punto de acceso: el teléfono se conecta un momento a la red Wi‑Fi que crea el equipo (aparece nueva y sin contraseña); úsalo si los otros fallan.',
                              'La red y la contraseña son las del paso «Wi‑Fi de la casa»: aquí no se vuelven a escribir.',
                            ],
                          ),
                          TarjetaFlujo(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Punto('1', 'Enciende el equipo y mantén su botón de reinicio 5–10 s, hasta que la luz parpadee rápido.'),
                                const _Punto(
                                  '2',
                                  'Conecta este teléfono a la Wi‑Fi de la casa, a la red de 2.4 GHz: si el módem tiene dos redes, es la que NO dice «5G» en el nombre.',
                                ),
                                const _Punto('3', 'Ten el Bluetooth del teléfono encendido y acércate al equipo.'),
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
                          const SizedBox(height: 12),
                          TextField(
                            controller: _serie,
                            enabled: !ocupado,
                            maxLength: 64,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Número de serie (opcional)',
                              helperText: 'Está en la etiqueta del equipo o de su caja. Sirve para inventario y garantía.',
                              helperMaxLines: 2,
                              counterText: '',
                              suffixIcon: IconButton(
                                tooltip: 'Escanear la etiqueta',
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                onPressed: ocupado ? null : _escanearSerie,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const EtiquetaSeccion(
                            'LA WI‑FI DE LA CASA',
                            tituloAyuda: 'Wi‑Fi de la casa',
                            ayuda: [
                              'Se usa la red que capturaste en el paso «Wi‑Fi de la casa»: el cliente escribió la contraseña una sola vez.',
                              'Si hay que cambiarla, toca «Cambiar»: vuelves al paso y al regresar se usa la nueva.',
                            ],
                          ),
                          if (!_wifiLeida)
                            const SizedBox(height: 56)
                          else if (_wifiCasa != null)
                            FilaFlujo(
                              titulo: 'Conectado a la Wi‑Fi de la casa',
                              subtitulo: '«${_wifiCasa!.red}» · la contraseña es la del paso 4',
                              marcada: true,
                              trailing: BotonFila(etiqueta: 'Cambiar', icono: Icons.wifi_rounded, onPressed: ocupado ? null : _irWifiCasa),
                            )
                          else ...[
                            MensajeFlujo(
                              icono: Icons.wifi_off_rounded,
                              color: cs.primary,
                              titulo: 'Falta la Wi‑Fi de la casa',
                              texto: 'Captúrala una vez en el paso «Wi‑Fi de la casa» y aquí se usa sola, sin volver a escribirla.',
                            ),
                            BotonSecundario(etiqueta: 'Ir a Wi‑Fi de la casa', onPressed: ocupado ? null : _irWifiCasa),
                          ],
                          const SizedBox(height: 16),
                          const EtiquetaSeccion('MODO'),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'BLE', label: Text('Bluetooth'), icon: Icon(Icons.bluetooth_rounded)),
                              ButtonSegment(value: 'EZ', label: Text('Rápido'), icon: Icon(Icons.wifi_rounded)),
                              ButtonSegment(value: 'AP', label: Text('Punto de acceso'), icon: Icon(Icons.router_outlined)),
                            ],
                            selected: {_modo},
                            showSelectedIcon: false,
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
            child: Text(
              n,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35))),
        ],
      ),
    );
  }
}

/// Tarjeta «Equipo conectado» (2026-10-22): lo que la nube dijo del equipo que entró, para que el
/// instalador confirme que es el que tiene en la mano.
class _Conectado extends StatelessWidget {
  const _Conectado({required this.emp, required this.esSensor, required this.tipo, required this.alListo, required this.alNoEsEste});
  final EmparejadorTuya emp;
  final bool esSensor;
  final String tipo;
  final VoidCallback alListo;
  final VoidCallback alNoEsEste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = context.ohm.success;
    final fabrica = emp.nombreDeFabrica.trim();
    final datos = <(String, String)>[
      ('Qué es', esSensor ? 'Sensor de ${tipo.toLowerCase()}' : 'Cámara'),
      if (fabrica.isNotEmpty && fabrica != emp.nombre) ('Modelo', fabrica),
      ('Serie', emp.serie ?? 'Sin serie'),
      ('ID del equipo', emp.devId ?? '—'),
      ('Red Wi‑Fi', emp.red.isEmpty ? '—' : emp.red),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        TarjetaFlujo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: ok, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Equipo conectado', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('«${emp.nombre}» quedó en la casa del cliente.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              for (final (k, v) in datos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          k,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(v, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Revisa que sea el equipo que tienes en la mano: su luz ya no parpadea rápido.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.4),
        ),
        const SizedBox(height: 24),
        OhmGradientButton(label: 'Listo', icon: Icons.check_rounded, onPressed: alListo),
        const SizedBox(height: 12),
        BotonSecundario(etiqueta: 'No es este equipo', onPressed: alNoEsEste),
      ],
    );
  }
}
