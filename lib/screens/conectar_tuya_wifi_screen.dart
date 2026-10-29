import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/tuya/emparejador_tuya.dart';
import '../core/utils/serie_qr.dart';
import '../core/wifi/wifi_casa_local.dart';
import '../core/wifi/redes_wifi.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/ayuda.dart';
import '../widgets/botones_dialogo.dart';
import '../widgets/hoja_decision.dart';
import '../widgets/movimiento.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/progreso_flujo.dart';
import 'escanear_serie_screen.dart';
import 'wifi_casa_screen.dart';

/// «Conectar sensor / cámara Tuya a la Wi‑Fi» (2026-10-17, fase 2 de docs/instalador-wifi.md).
///
/// El instalador pone el equipo en modo de emparejamiento y la app le pasa la red de la casa (la
/// del paso 4) con el **permiso de la casa** (token de nube que da el backend). El equipo queda en
/// la cuenta del cliente, visible en OhmSafe GO; aquí se registra con el NOMBRE de la red. La
/// contraseña no se guarda. Devuelve (pop) `true` si quedó.
///
/// 2026-10-22 (regla de oro de Carlos tras el video de la cámara de Nahum): en **4 pasos
/// consecutivos** en vez de todo en una pantalla, y mientras conecta la pantalla dice en cada
/// momento qué está pasando (etapas hechas / en curso / pendientes, frases que avanzan, tiempo
/// transcurrido contra lo que dura el permiso):
///
///  1. Datos — qué es, nombre, serie (opcional) y la Wi‑Fi de la casa ya capturada.
///  2. Prepara el equipo — listo para conectar y modo de conexión («Cerca del teléfono» = BLE,
///     «Rápido» = EZ, «Red de la cámara/del sensor» = AP; v2 2026-10-23: nombres sin jerga).
///  3. Conectando — línea de progreso; si falla, en qué etapa y qué hacer.
///  4. Listo — la tarjeta «Equipo conectado» con lo que dijo el registro.
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

enum _Paso { datos, preparar, conectando, listo }

/// Etapas que se muestran en el paso 3 (más finas que [EtapaTuya]: separa «pasarle la red» de
/// «esperar a que avise a la nube», que es donde se fue el tiempo en el caso de Nahum).
enum _Fase { permiso, redEquipo, pasarRed, esperarNube, guardar }

/// Tras este tiempo pasándole la red, lo que falta es que el equipo llegue a la nube.
const _pasarRedTipico = Duration(seconds: 20);

class _ConectarTuyaWifiScreenState extends State<ConectarTuyaWifiScreen> with WidgetsBindingObserver {
  late final WifiCasaLocal _local = widget.local ?? WifiCasaLocal.instancia;

  /// La Wi‑Fi del paso 4 (Carlos, 2026-10-22): aquí ya no se vuelve a pedir. Sin ella, se manda al paso.
  WifiCasa? _wifiCasa;
  bool _wifiLeida = false;

  late final EmparejadorTuya _emp = widget.emparejador ?? EmparejadorTuya(repo: sl.get<OrdenesRepository>(), ordenId: widget.ordenId);
  final _nombre = TextEditingController();
  final _red = TextEditingController();
  final _contrasena = TextEditingController();
  final _serie = TextEditingController();
  bool _conectado = false;

  /// Bluetooth primero (2026-10-22, como la app del cliente): si no ve el equipo, sigue sola en modo rápido.
  String _modo = 'BLE';

  /// Paso que eligió el instalador mientras no hay nada corriendo (datos ↔ preparar).
  _Paso _elegido = _Paso.datos;

  /// Cronología del intento en curso, para la línea de progreso.
  DateTime? _desdeConectar;
  DateTime? _desdePasarRed;
  bool _pasoPorRedEquipo = false;
  _Fase _faseActiva = _Fase.permiso;
  Timer? _reloj;

  static const _tipos = {'door': 'Puerta', 'motion': 'Movimiento', 'smoke': 'Humo'};

  bool get _esSensor => widget.clase == 'sensor';
  String get _que => _esSensor ? 'el sensor' : 'la cámara';
  String get _queMayus => _esSensor ? 'El sensor' : 'La cámara';

  /// Concordancia: «lo» para el sensor, «la» para la cámara.
  String get _lo => _esSensor ? 'lo' : 'la';

  _Paso get _paso {
    if (_conectado) return _Paso.listo;
    if (_emp.ocupado || _emp.etapa == EtapaTuya.error) return _Paso.conectando;
    return _elegido;
  }

  @override
  void initState() {
    super.initState();
    _emp.addListener(_cambio);
    WidgetsBinding.instance.addObserver(this);
    _cargarWifiCasa();
    _buscarRedDelEquipo();
  }

  /// Red que crea el equipo en modo punto de acceso, si el teléfono la ve (Android). Con ella se
  /// sugiere ese modo (caso de Nahum en i77: la cámara estaba en punto de acceso y se probó rápido).
  String? _redEquipoVista;
  bool _modoTocado = false;

  Future<void> _buscarRedDelEquipo() async {
    final listador = widget.listador ?? ListadorRedesPlataforma();
    if (!listador.puedeListar) return;
    try {
      final r = await listador.escanear();
      if (!mounted || r.estado != EstadoEscaneo.ok) return;
      final vista = r.redes.map((x) => x.ssid).where(esRedDeEquipo).firstOrNull;
      if (vista == null) return;
      setState(() {
        _redEquipoVista = vista;
        if (!_modoTocado && !_emp.ocupado) _modo = 'AP';
      });
    } catch (_) {}
  }

  /// Al volver de los ajustes de Wi‑Fi, si ya está en la red del equipo, sigue solo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _emp.etapa == EtapaTuya.esperandoRedEquipo) {
      _emp.continuarAP();
    }
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
    _reloj?.cancel();
    _emp.removeListener(_cambio);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.emparejador == null) _emp.dispose();
    _nombre.dispose();
    _red.dispose();
    _contrasena.dispose();
    _serie.dispose();
    super.dispose();
  }

  void _cambio() {
    if (!mounted) return;
    final e = _emp.etapa;
    if (_emp.ocupado) {
      _desdeConectar ??= DateTime.now();
      if (e == EtapaTuya.esperandoRedEquipo) _pasoPorRedEquipo = true;
      if (e == EtapaTuya.emparejando) _desdePasarRed ??= DateTime.now();
      // Bluetooth que cae al modo rápido pide un permiso nuevo: el reloj de «pasar la red» reinicia.
      if (e == EtapaTuya.preparando) _desdePasarRed = null;
      _faseActiva = _faseDe(e);
      // Cada segundo: el tiempo transcurrido y el paso de «pasar la red» a «esperar la nube».
      _reloj ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_emp.ocupado) _faseActiva = _faseDe(_emp.etapa);
        });
      });
    } else {
      _reloj?.cancel();
      _reloj = null;
    }
    if (e == EtapaTuya.listo && !_conectado) {
      _contrasena.clear();
      _conectado = true;
      HapticFeedback.mediumImpact();
    }
    setState(() {});
  }

  _Fase _faseDe(EtapaTuya e) => switch (e) {
    EtapaTuya.preparando => _Fase.permiso,
    EtapaTuya.esperandoRedEquipo => _Fase.redEquipo,
    EtapaTuya.emparejando => _esperandoNube() ? _Fase.esperarNube : _Fase.pasarRed,
    EtapaTuya.registrando => _Fase.guardar,
    _ => _faseActiva,
  };

  /// El equipo ya recibió la red (el SDK lo dijo, o ya pasó lo que suele tardar) y falta que se registre.
  bool _esperandoNube() {
    final t = _emp.texto.toLowerCase();
    if (t.contains('registr') || t.contains('recibió')) return true;
    final d = _desdePasarRed;
    return d != null && DateTime.now().difference(d) >= _pasarRedTipico;
  }

  bool get _completo => _nombre.text.trim().isNotEmpty && _wifiCasa != null;

  Future<void> _empezar() async {
    FocusScope.of(context).unfocus();
    // Con la Wi‑Fi del paso 4 ya se confirmó ahí si la red no tiene contraseña.
    if (_wifiCasa == null && _contrasena.text.isEmpty) {
      final sinClave = await mostrarHojaDecision(
        context,
        titulo: '¿La red no tiene contraseña?',
        texto: 'Si la Wi‑Fi de la casa tiene contraseña, pídesela al cliente y que la escriba aquí.',
        seguir: 'Conectar sin contraseña',
        salir: 'Escribir la contraseña',
      );
      if (sinClave != true) return;
    }
    setState(() {
      _desdeConectar = DateTime.now();
      _desdePasarRed = null;
      _pasoPorRedEquipo = false;
      _faseActiva = _Fase.permiso;
    });
    await _emp.empezar(
      clase: widget.clase,
      tipo: null, // lo pone el emparejador según la categoría del equipo
      nombre: _nombre.text,
      red: _red.text,
      contrasena: _contrasena.text,
      modo: _modo,
      serie: _serie.text,
    );
  }

  /// Desde un error: volver al paso 2 para cambiar el modo o los datos.
  Future<void> _revisar() async {
    await _emp.cancelar();
    if (mounted) setState(() => _elegido = _Paso.preparar);
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
          'Luego pon el equipo correcto listo para conectar (luz parpadeando rápido) y vuelve a conectarlo.',
        ),
        actions: [BotonesDialogo(primario: 'Entendido, avisaré', onPrimario: () => Navigator.pop(ctx))],
      ),
    );
  }

  /// La flecha de regreso va un paso atrás; sólo en el paso 1 (o al terminar) sale de la pantalla.
  Future<void> _salir() async {
    switch (_paso) {
      case _Paso.listo:
        Navigator.pop(context, true);
        return;
      case _Paso.preparar:
        setState(() => _elegido = _Paso.datos);
        return;
      case _Paso.conectando:
        if (_emp.etapa == EtapaTuya.error) return _revisar();
        // v2 (2026-10-23, lienzo «V5 · Hoja»): decidir en una hoja desde abajo; salir pierde lo que va.
        final seguir = await mostrarHojaDecision(
          context,
          titulo: _esSensor ? '¿Dejar de conectar el sensor?' : '¿Dejar de conectar la cámara?',
          texto: 'Lo que llevas de este paso no se guarda; $_que se queda sin registrar y puedes volver a empezar cuando quieras.',
          seguir: 'Seguir conectando',
          salir: 'Salir sin conectar',
          pierde: true,
        );
        if (seguir != false || !mounted) return;
        await _emp.cancelar();
        if (mounted) setState(() => _elegido = _Paso.preparar);
        return;
      case _Paso.datos:
        Navigator.pop(context, false);
    }
  }

  String _tituloPaso(_Paso p) => switch (p) {
    _Paso.datos => _esSensor ? 'Datos del sensor' : 'Datos de la cámara',
    _Paso.preparar => _esSensor ? 'Prepara el sensor' : 'Prepara la cámara',
    _Paso.conectando => _emp.etapa == EtapaTuya.error ? 'No se pudo conectar' : 'Conectando',
    _Paso.listo => 'Listo',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paso = _paso;
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
              IndicadorPasos(actual: paso.index + 1, total: _Paso.values.length, titulo: _tituloPaso(paso)),
              Expanded(
                child: CambioSuave(
                  alineacion: Alignment.topCenter,
                  child: KeyedSubtree(
                    key: ValueKey(paso),
                    child: switch (paso) {
                      _Paso.datos => _pasoDatos(context),
                      _Paso.preparar => _pasoPreparar(context),
                      _Paso.conectando => _pasoConectando(context),
                      _Paso.listo => _Conectado(
                        emp: _emp,
                        esSensor: _esSensor,
                        tipo: _tipos[_emp.tipo] ?? '',
                        alListo: () => Navigator.pop(context, true),
                        alNoEsEste: _noEsEste,
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lista(List<Widget> hijos) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
    physics: const BouncingScrollPhysics(),
    children: [for (var i = 0; i < hijos.length; i++) EntradaSuave(index: i, child: hijos[i])],
  );

  // ---------------------------------------------------------------------------
  // Paso 1 · Datos
  // ---------------------------------------------------------------------------
  Widget _pasoDatos(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final faltaNombre = _nombre.text.trim().isEmpty;
    return _lista([
      if (!_emp.puente.tieneLlaves)
        MensajeFlujo(
          icono: Icons.error_outline_rounded,
          color: cs.error,
          titulo: 'Esta versión no puede conectar equipos Wi‑Fi',
          texto: 'Le falta una configuración a la app. Actualízala; si sigue, avisa a soporte.',
        ),
      EtiquetaSeccion(_esSensor ? 'El sensor' : 'La cámara'),
      // El tipo ya no se elige: lo dice el sensor al conectarse (2026-10-23, «Sala» de la i77).
      if (_esSensor) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Si es de puerta, movimiento o humo lo dice el sensor al conectarse; no hay que elegirlo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
      TextField(
        controller: _nombre,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: 'Nombre', hintText: _esSensor ? 'Ej. Puerta principal' : 'Ej. Cochera', counterText: ''),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _serie,
        maxLength: 64,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: 'Número de serie (opcional)',
          helperText: 'Está en la etiqueta del equipo o de su caja. Sirve para inventario y garantía.',
          helperMaxLines: 2,
          counterText: '',
          suffixIcon: IconButton(tooltip: 'Escanear la etiqueta', icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _escanearSerie),
        ),
      ),
      const SizedBox(height: 20),
      const EtiquetaSeccion(
        'La Wi‑Fi de la casa',
        tituloAyuda: 'Wi‑Fi de la casa',
        ayuda: [
          'Se usa la red que capturaste en el paso «Wi‑Fi de la casa»: el cliente escribió la contraseña una sola vez.',
          'Si hay que cambiarla, toca «Cambiar»: vuelves al paso y al regresar se usa la nueva.',
        ],
      ),
      if (!_wifiLeida)
        const SizedBox(height: 56)
      else
        // Zona de estado (propuesta A del lienzo, Carlos 2026-10-23): verde «EN ORDEN» o rojo «FALTA».
        ZonaEstado(
          estado: _wifiCasa != null ? EstadoZona.enOrden : EstadoZona.falta,
          titulo: 'Wi‑Fi de la casa',
          detalle: _wifiCasa != null
              ? '«${_wifiCasa!.red}» · la contraseña es la que escribió el cliente en el paso 4.'
              : 'Sin ella $_que no se puede conectar. Captúrala una vez en el paso 4 y aquí se usa sola.',
          accionEtiqueta: _wifiCasa != null ? 'Cambiar red' : 'Ir al paso 4 · Wi‑Fi de la casa',
          accionIcono: Icons.wifi_rounded,
          accionPrincipal: _wifiCasa == null,
          alAccion: _irWifiCasa,
        ),
      const SizedBox(height: 24),
      OhmGradientButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: _completo && _emp.puente.tieneLlaves
            ? () {
                FocusScope.of(context).unfocus();
                setState(() => _elegido = _Paso.preparar);
              }
            : null,
      ),
      if (_wifiLeida && _wifiCasa == null) ...[
        const SizedBox(height: 10),
        FaltaParaSeguir([if (faltaNombre) 'nombre', 'Wi‑Fi de la casa']),
      ] else if (_wifiLeida && faltaNombre) ...[
        const SizedBox(height: 10),
        _Nota('Escribe un nombre para $_que y sigue.'),
      ],
    ]);
  }

  // ---------------------------------------------------------------------------
  // Paso 2 · Prepara el equipo
  // ---------------------------------------------------------------------------
  Widget _pasoPreparar(BuildContext context) {
    final serie = _serie.text.trim();
    return _lista([
      GrupoFilas(
        children: [
          FilaFlujo(
            titulo: '«${_nombre.text.trim()}»',
            subtitulo: [if (serie.isNotEmpty) 'Serie $serie', if (_wifiCasa != null) 'Wi‑Fi «${_wifiCasa!.red}»'].join(' · '),
            trailing: BotonFila(etiqueta: 'Editar', icono: Icons.edit_rounded, onPressed: () => setState(() => _elegido = _Paso.datos)),
          ),
        ],
      ),
      EtiquetaSeccion(
        'Antes de conectar',
        tituloAyuda: 'Cómo preparar $_que',
        ayuda: [
          'Enciende $_que y ${_esSensor ? 'déjalo listo' : 'déjala lista'} para conectar: mantén su botón (RESET) 5–10 s hasta que la luz parpadee rápido.',
          'Este teléfono debe estar en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»); los equipos no se conectan a redes de 5 GHz.',
          if (_modo == 'BLE')
            'Cerca del teléfono: el teléfono busca $_que por Bluetooth y le pasa la red; ten el Bluetooth encendido. Si no $_lo encuentra en 20 s, la app cambia sola al modo rápido.',
          if (_modo == 'EZ') 'Rápido: $_que escucha en la red de la casa; deja el teléfono cerca.',
          if (_modo == 'AP')
            '${_esSensor ? 'Red del sensor' : 'Red de la cámara'}: el teléfono se conecta un momento a la red Wi‑Fi que crea $_que (aparece nueva y sin contraseña) y luego vuelve solo a la de la casa.',
        ],
      ),
      TarjetaFlujo(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Punto('1', 'Enciende $_que y mantén su botón de reinicio 5–10 s, hasta que la luz parpadee rápido.'),
            const _Punto('2', 'Deja este teléfono en la Wi‑Fi de la casa, en la red de 2.4 GHz (la que no dice «5G»).'),
            _Punto('3', switch (_modo) {
              'AP' => 'Al tocar «Conectar» la app te pedirá unir el teléfono a la red Wi‑Fi de $_que y regresar.',
              'EZ' => 'Quédate cerca de $_que con el teléfono.',
              _ => 'Ten el Bluetooth del teléfono encendido y acércate a $_que.',
            }),
          ],
        ),
      ),
      const SizedBox(height: 24),
      EtiquetaSeccion('¿Cómo $_lo conectamos?'),
      if (_redEquipoVista != null && _modo == 'AP')
        MensajeFlujo(
          icono: Icons.router_rounded,
          color: context.ohm.info,
          titulo: '$_queMayus creó su propia red',
          texto: 'El teléfono ve su red «$_redEquipoVista». Por eso elegimos «${_esSensor ? 'Red del sensor' : 'Red de la cámara'}».',
        ),
      GrupoFilas(
        children: [
          for (final (valor, icono, titulo, texto) in [
            (
              'BLE',
              Icons.bluetooth_rounded,
              'Cerca del teléfono',
              'Lo normal. El teléfono $_lo encuentra y le pasa la red. Si no $_lo encuentra en 20 s, la app cambia sola al modo rápido.',
            ),
            ('EZ', Icons.bolt_rounded, 'Rápido', 'Si la luz de $_que parpadea rápido.'),
            (
              'AP',
              Icons.router_rounded,
              _esSensor ? 'Red del sensor' : 'Red de la cámara',
              'Si en la lista de Wi‑Fi del teléfono aparece una red nueva y abierta.',
            ),
          ])
            _OpcionModo(
              icono: icono,
              titulo: titulo,
              texto: texto,
              elegida: _modo == valor,
              alElegir: () => setState(() {
                _modo = valor;
                _modoTocado = true;
              }),
            ),
        ],
      ),
      OhmGradientButton(
        label: _esSensor ? 'Conectar el sensor' : 'Conectar la cámara',
        icon: Icons.wifi_rounded,
        onPressed: _emp.puente.tieneLlaves ? _empezar : null,
      ),
      const SizedBox(height: 12),
      BotonSecundario(etiqueta: 'Volver a los datos', onPressed: () => setState(() => _elegido = _Paso.datos)),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Paso 3 · Conectando (o en qué etapa falló)
  // ---------------------------------------------------------------------------
  Widget _pasoConectando(BuildContext context) {
    final error = _emp.etapa == EtapaTuya.error;
    final red = _wifiCasa?.red ?? _red.text.trim();
    final modoTexto = switch (_emp.modoUsado.isEmpty ? _modo : _emp.modoUsado) {
      'AP' => _esSensor ? 'red del sensor' : 'red de la cámara',
      'EZ' => 'modo rápido',
      _ => 'cerca del teléfono',
    };
    return _lista([
      TarjetaProceso(
        titulo: error ? 'No se pudo conectar $_que' : 'Conectando $_que…',
        subtitulo: '«${_nombreVisible()}» a la Wi‑Fi «$red» · $modoTexto',
        linea: LineaProgreso(etapas: _etapas(red), desde: _desdeConectar, hasta: _emp.venceToken),
      ),
      const SizedBox(height: 16),
      if (!error) ...[
        _Nota('No cierres la app ni te alejes de $_que: la pantalla avanza sola en cuanto responde.'),
        const SizedBox(height: 16),
        BotonSecundario(etiqueta: 'Dejar de conectar', onPressed: _salir),
      ],
    ]);
  }

  String _nombreVisible() => _emp.nombre.isNotEmpty ? _emp.nombre : _nombre.text.trim();

  List<EtapaProgreso> _etapas(String red) {
    // El modo que de verdad usa el emparejador (Bluetooth puede caer a rápido); antes de arrancar, el elegido.
    final ap = _pasoPorRedEquipo || (_emp.modoUsado.isEmpty ? _modo : _emp.modoUsado) == 'AP';
    final fases = [_Fase.permiso, if (ap) _Fase.redEquipo, _Fase.pasarRed, _Fase.esperarNube, _Fase.guardar];
    final error = _emp.etapa == EtapaTuya.error;
    final activa = error ? _faseActiva : _faseDe(_emp.etapa);
    final iActiva = fases.indexOf(activa);
    return [
      for (var i = 0; i < fases.length; i++)
        _etapa(
          fases[i],
          red,
          i < iActiva
              ? EstadoEtapa.hecha
              : i == iActiva
              ? (error ? EstadoEtapa.error : EstadoEtapa.enCurso)
              : EstadoEtapa.pendiente,
        ),
    ];
  }

  EtapaProgreso _etapa(_Fase f, String red, EstadoEtapa estado) {
    final error = estado == EstadoEtapa.error;
    final textoEmp = _emp.texto.trim();
    final accionError = error
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OhmGradientButton(label: 'Volver a intentar', icon: Icons.refresh_rounded, onPressed: _empezar),
              const SizedBox(height: 10),
              BotonSecundario(etiqueta: 'Cambiar el modo o los datos', onPressed: _revisar),
            ],
          )
        : null;
    final detalleError = error ? _emp.error : null;
    switch (f) {
      case _Fase.permiso:
        return EtapaProgreso(
          titulo: 'Pedir el permiso de la casa',
          estado: estado,
          frases: [if (textoEmp.isNotEmpty) textoEmp, 'Con este permiso $_que queda en la cuenta del cliente.'],
          detalle: detalleError,
          accion: accionError,
        );
      case _Fase.redEquipo:
        return EtapaProgreso(
          titulo: 'Unir el teléfono a la red del equipo',
          estado: estado,
          detalle: detalleError,
          accion: error ? accionError : (estado == EstadoEtapa.enCurso ? _RedDelEquipo(emp: _emp, redVista: _redEquipoVista) : null),
        );
      case _Fase.pasarRed:
        return EtapaProgreso(
          titulo: 'Pasarle la red de la casa a $_que',
          estado: estado,
          frases: [if (textoEmp.isNotEmpty) textoEmp, 'Cuando $_que recibe la red, su luz deja de parpadear rápido.', 'Mantén el teléfono cerca de $_que.'],
          detalle: detalleError,
          accion: accionError,
        );
      case _Fase.esperarNube:
        return EtapaProgreso(
          titulo: 'Esperar a que $_que se registre',
          estado: estado,
          frases: [
            '$_queMayus se está conectando a «$red»…',
            'En cuanto se registre, esta pantalla avanza sola.',
            'Suele tardar menos de 1 minuto; tienes 5 minutos.',
            'Si la contraseña de la Wi‑Fi no es la correcta, $_que no llega: revísala en el paso «Wi‑Fi de la casa».',
          ],
          detalle: detalleError,
          accion: accionError,
        );
      case _Fase.guardar:
        return EtapaProgreso(
          titulo: 'Guardar en la casa del cliente',
          estado: estado,
          frases: ['$_queMayus ya llegó; ${_esSensor ? 'guardándolo' : 'guardándola'} con el nombre «${_nombreVisible()}»…'],
          detalle: detalleError,
          accion: accionError,
        );
    }
  }
}

/// Una opción de «¿Cómo la conectamos?»: fila con su explicación (antes un SegmentedButton que
/// partía «Bluetooth» en dos líneas en teléfonos angostos, video de Nahum 2026-10-22). Va dentro de
/// un [GrupoFilas].
class _OpcionModo extends StatelessWidget {
  const _OpcionModo({required this.icono, required this.titulo, required this.texto, required this.elegida, required this.alElegir});
  final IconData icono;
  final String titulo;
  final String texto;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      selected: elegida,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: alElegir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icono, size: 22, color: elegida ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: elegida ? FontWeight.w600 : FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CirculoCheck(marcado: elegida),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(texto, textAlign: TextAlign.center, style: theme.textTheme.bodySmall);
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

/// Tarjeta «Equipo conectado» (2026-10-22): lo que se registró del equipo que entró, para que el
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
    final cs = theme.colorScheme;
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        TarjetaFlujo(
          child: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: ok, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Equipo conectado', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text('«${emp.nombre}» quedó en la casa del cliente.', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GrupoFilas(
          pie: 'Revisa que sea el equipo que tienes en la mano: su luz ya no parpadea rápido.',
          children: [
            for (final (k, v) in datos)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: SelectableText(v, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        OhmGradientButton(label: 'Volver a dispositivos', icon: Icons.check_rounded, onPressed: alListo),
        const SizedBox(height: 12),
        BotonSecundario(etiqueta: 'No es este equipo', onPressed: alNoEsEste),
      ],
    );
  }
}

/// Modo «Red de la cámara/del sensor» (AP): el teléfono tiene que unirse a la red del equipo antes
/// de seguir (2026-10-22). Va dentro de la etapa «Unir el teléfono a la red del equipo».
class _RedDelEquipo extends StatelessWidget {
  const _RedDelEquipo({required this.emp, this.redVista});
  final EmparejadorTuya emp;
  final String? redVista;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final actual = emp.redDelTelefono;
    final todaviaNo = actual != null && !esRedDeEquipo(actual);
    final cual = redVista != null ? '«$redVista»' : 'la red nueva y abierta que crea el equipo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Toca «Abrir ajustes de Wi‑Fi» (en iPhone: Ajustes › Wi‑Fi).\n'
          '2. Elige $cual. No tiene contraseña.\n'
          '3. Regresa a esta app: sigue sola. Tienes 5 minutos en total, así que hazlo sin pausas.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (todaviaNo) ...[
          const SizedBox(height: 10),
          Text(
            'Todavía estás en «$actual».',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 14),
        OhmGradientButton(label: 'Abrir ajustes de Wi‑Fi', icon: Icons.settings_rounded, onPressed: emp.puente.abrirAjustesWifi),
        const SizedBox(height: 10),
        BotonSecundario(etiqueta: 'Ya me conecté', onPressed: () => emp.continuarAP()),
        if (todaviaNo) ...[
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.onSurface, minimumSize: const Size(44, 44)),
            onPressed: () => emp.continuarAP(forzar: true),
            child: const Text('Seguir de todos modos'),
          ),
        ],
      ],
    );
  }
}
