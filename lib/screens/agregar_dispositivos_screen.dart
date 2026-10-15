import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/serie_formato.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import 'escanear_serie_screen.dart';
import '../widgets/aprender_rf_sheet.dart';
import '../widgets/con_textos.dart';

/// «Agregar dispositivos» · cableado con prueba en vivo (build 39, Carlos 2026-10-13).
/// Cada elemento se comprueba físicamente y la app sólo acepta lo que el equipo confirma:
///   · Entradas: «Cierra la puerta» → cerrada estable 3 s → «Ábrela» → abierta → nombre y alta.
///   · Sirena: «Probar 3 s» → «¿Sonó?».
///   · Salidas aux: «Encender 5 s» → «¿Se encendió?» → tipo, modo y alta.
/// Requiere firmware 2.10+, equipo en línea y la ventana de instalación abierta (la abre la prueba
/// del energizador; si venció, aquí se vuelve a abrir). Devuelve 'dispositivos_listos' al terminar.
class AgregarDispositivosScreen extends StatefulWidget {
  const AgregarDispositivosScreen({super.key, required this.ticket});
  final Map<String, dynamic> ticket;

  @override
  State<AgregarDispositivosScreen> createState() => _AgregarDispositivosScreenState();
}

class _AgregarDispositivosScreenState extends State<AgregarDispositivosScreen> {
  final OrdenesRepository _repo = sl.get<OrdenesRepository>();
  String get _id => (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();

  Map<String, dynamic>? _e;
  String? _error;
  bool _cargando = true;
  bool _ocupado = false;
  Timer? _sondeo;
  Timer? _ventana;
  bool _saliendo = false;

  /// Energizadores de la casa (principal + OhmBox adicionales). `null` = aún no se lee o falló.
  Map<String, dynamic>? _ohmbox;

  /// Sensores 433, Wi‑Fi y cámaras ya dados de alta (2026-10-14).
  Map<String, dynamic>? _disp;

  @override
  void initState() {
    super.initState();
    _inicio();
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _ventana?.cancel();
    super.dispose();
  }

  Future<void> _inicio() async {
    // Ventana de control invisible (2026-10-14): se abre al entrar, se renueva sola mientras la
    // pantalla está abierta y se cierra al salir; el instalador no se queda con control de la cerca.
    await _repo.pruebaAbrir(_id);
    _ventana = Timer.periodic(const Duration(minutes: 1), (_) => Actividad.enSilencio(_renovarVentana));
    await Future.wait([_cargar(), _cargarOhmbox(), _cargarDisp()]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargar() async {
    final r = await _repo.cableadoEstado(_id);
    if (!mounted) return;
    r.fold(
      (d) => setState(() {
        _e = d;
        _error = null;
      }),
      (f) => setState(() => _error = f.message),
    );
    _ajustarSondeo();
  }

  Future<void> _renovarVentana() async {
    if (_saliendo) return;
    final r = await _repo.pruebaEstado(_id);
    if (r.isFailure) return;
    final v = (r.successValue['ventana'] as Map?)?.cast<String, dynamic>();
    if (v == null) return;
    final restantes = (v['segundosRestantes'] as num?)?.toInt() ?? 0;
    if (v['abierta'] != true) {
      await _repo.pruebaAbrir(_id);
    } else if (restantes < 5 * 60) {
      await _repo.pruebaExtender(_id);
    }
  }

  /// Sale a la lista de pasos y cierra la ventana de control.
  Future<void> _salir() async {
    if (_saliendo) return;
    setState(() => _saliendo = true);
    _ventana?.cancel();
    _sondeo?.cancel();
    await _repo.pruebaTerminar(_id);
    if (mounted) Navigator.pop(context, 'dispositivos_listos');
  }

  Future<void> _cargarDisp() async {
    final r = await _repo.dispositivosEstado(_id);
    if (!mounted) return;
    r.fold((d) => setState(() => _disp = d), (_) {});
  }

  Map<String, dynamic> _sec(String k) => (_disp?[k] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> _lista(String k, String campo) => ((_sec(k)[campo] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  bool get _rfSoportado => _sec('rf')['soportado'] != false;
  bool get _camarasOn => _sec('camaras')['habilitadas'] == true;
  Map<String, dynamic> get _proveedores => (_sec('camaras')['proveedores'] as Map?)?.cast<String, dynamic>() ?? const {};
  bool get _hayProveedor => _camarasOn && (_proveedores['ezviz'] == true || _proveedores['imou'] == true);

  static const _tipoRfTexto = {'door': 'Puerta', 'pir': 'Movimiento', 'smoke': 'Humo', 'panic_button': 'Botón de pánico', 'fob': 'Control remoto'};
  static const _tipoWifiTexto = {'door': 'Puerta', 'motion': 'Movimiento', 'smoke': 'Humo'};
  static const _tipoSalidaTexto = {'luz': 'luz', 'bomba': 'bomba', 'porton': 'portón', 'sirena': 'sirena externa', 'otro': 'otro'};

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  // ---------------------------------------------------------------- 433
  Future<void> _agregarRf() async {
    final tipo = await showModalBottomSheet<({String id, String etiqueta, IconData icono})>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿Qué sensor vas a agregar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final t in tiposRf) ListTile(leading: Icon(t.icono), title: Text(t.etiqueta), onTap: () => Navigator.pop(ctx, t)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (tipo == null || !mounted) return;
    final nombre = await aprenderSensorRf(context, ordenId: _id, tipo: tipo.id, etiqueta: tipo.etiqueta);
    if (!mounted) return;
    if (nombre != null) _aviso('Sensor «$nombre» guardado');
    await _cargarDisp();
  }

  // ---------------------------------------------------------------- Wi‑Fi
  Future<void> _agregarWifi() async {
    // ConTextos es dueño de los controladores: los libera cuando el diálogo YA se cerró.
    // El tipo vive fuera del builder: si el diálogo se reconstruye (p. ej. al abrir el teclado) no se pierde.
    var tipo = 'door';
    final datos = await showDialog<({String id, String nombre, String tipo})>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const ['', ''],
        builder: (ctx, c) {
          return StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
              title: const Text('Sensor Wi‑Fi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Escribe el ID del sensor. El cliente termina de conectarlo desde su app.', style: Theme.of(ctx).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [for (final e in _tipoWifiTexto.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (v) => set(() => tipo = v ?? 'door'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: c[0],
                      decoration: const InputDecoration(labelText: 'ID del sensor', helperText: 'Viene en la etiqueta o en la app del sensor.', helperMaxLines: 2),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: c[1],
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Ventana de la sala'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    final id = c[0].text.trim(), nombre = c[1].text.trim();
                    if (id.isNotEmpty && nombre.isNotEmpty) Navigator.pop(ctx, (id: id, nombre: nombre, tipo: tipo));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (datos == null || !mounted) return;
    setState(() => _ocupado = true);
    final r = await _repo.sensorWifiAgregar(_id, externalId: datos.id, nombre: datos.nombre, tipo: datos.tipo);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((_) => _aviso('Sensor Wi‑Fi «${datos.nombre}» guardado'), (f) => _aviso(f.message));
    await _cargarDisp();
  }

  // ---------------------------------------------------------------- Cámaras
  Future<void> _agregarCamara() async {
    final datos = await showDialog<({String serie, String codigo, String nombre})>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const ['', '', ''],
        builder: (ctx, c) => AlertDialog(
          title: const Text('Agregar cámara'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('La cámara debe estar encendida y con internet.', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(controller: c[0], textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Número de serie', helperText: 'En la etiqueta, como S/N.')),
                const SizedBox(height: 12),
                TextField(controller: c[1], textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código de verificación', helperText: 'En la misma etiqueta.')),
                const SizedBox(height: 12),
                TextField(controller: c[2], maxLength: 40, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Cochera')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final serie = c[0].text.trim(), codigo = c[1].text.trim(), nombre = c[2].text.trim();
                if (serie.isNotEmpty && codigo.isNotEmpty && nombre.isNotEmpty) Navigator.pop(ctx, (serie: serie, codigo: codigo, nombre: nombre));
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    if (datos == null || !mounted) return;
    setState(() => _ocupado = true);
    // Sin marca: el backend prueba cada nube habilitada y se queda con la que reconoce la cámara.
    final r = await _repo.camaraAgregar(_id, serie: datos.serie, codigo: datos.codigo, nombre: datos.nombre);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((_) => _aviso('Cámara «${datos.nombre}» guardada'), (f) => _aviso(f.message));
    await _cargarDisp();
  }

  Future<void> _cargarOhmbox() async {
    final r = await _repo.ohmboxEstado(_id);
    if (!mounted) return;
    r.fold((d) => setState(() => _ohmbox = d), (_) {});
  }

  List<Map<String, dynamic>> get _energizadores => ((_ohmbox?['energizadores'] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  String get _casaNombre => ((_ohmbox?['casa'] as Map?)?['nombre'] ?? 'la casa').toString();

  /// OhmBox adicional (2026-10-14): un segundo energizador en la misma casa es un complemento
  /// de su suscripción, nunca un paquete nuevo. Va siempre a la casa del energizador principal.
  Future<void> _agregarOhmbox() async {
    final serie = await _pedirSerie();
    if (serie == null || !mounted) return;
    setState(() => _ocupado = true);
    final r = await _repo.ohmboxAgregar(_id, serie: serie);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((d) {
      setState(() => _ohmbox = d);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Energizador $serie agregado a «$_casaNombre»')));
    }, (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))));
  }

  Future<String?> _pedirSerie() {
    return showDialog<String>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const [''],
        builder: (ctx, c) => AlertDialog(
          title: const Text('Otro energizador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se suma a «$_casaNombre» como complemento. No crea otra suscripción.', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: c[0],
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [SerieInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Número de serie',
                  hintText: 'Ej. 26 u OS-OBV01-0026',
                  suffixIcon: IconButton(
                    tooltip: 'Escanear QR',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final leida = await Navigator.of(ctx).push<String>(MaterialPageRoute(builder: (_) => const EscanearSerieScreen()));
                      if (leida != null && leida.isNotEmpty && ctx.mounted) c[0].text = leida;
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final s = normalizarSerie(c[0].text);
                if (s.isNotEmpty) Navigator.pop(ctx, s);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Mientras hay una prueba de entrada en curso, se consulta el equipo cada 2 s.
  void _ajustarSondeo() {
    final activa = _entradas.any((x) => x['prueba'] != null && !{'verificada', 'expirada'}.contains((x['prueba'] as Map)['fase']));
    if (activa && _sondeo == null) {
      _sondeo = Timer.periodic(const Duration(seconds: 2), (_) => Actividad.enSilencio(_cargar));
    } else if (!activa && _sondeo != null) {
      _sondeo!.cancel();
      _sondeo = null;
    }
  }

  Map<String, dynamic> get _equipo => (_e?['equipo'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> get _entradas => ((_e?['entradas'] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  List<Map<String, dynamic>> get _salidas => ((_e?['salidas'] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  Map<String, dynamic> get _sirena => (_e?['sirena'] as Map?)?.cast<String, dynamic>() ?? const {};
  bool get _firmwareOk => _equipo['firmwareOk'] == true;
  bool get _enLinea => _equipo['enLinea'] == true;
  bool get _listo => _firmwareOk && _enLinea && !_ocupado;

  String _msg(Failure f) => f.message;

  Future<void> _run(Future<dynamic> Function() op) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final r = await op();
    if (!mounted) return;
    // ignore: avoid_dynamic_calls
    r.fold(
      (d) => setState(() {
        _e = (d as Map).cast<String, dynamic>();
        _error = null;
      }),
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_msg(f as Failure)))),
    );
    setState(() => _ocupado = false);
    _ajustarSondeo();
  }

  // ---------------------------------------------------------------- entradas
  Future<void> _probarEntrada(int index) => _run(() => _repo.cableadoProbarEntrada(_id, index));

  Future<void> _registrarEntrada(int index, String nombreActual) async {
    final nombre = await _pedirNombre('¿Qué puerta es?', nombreActual.startsWith('Entrada ') ? '' : nombreActual, ejemplo: 'Ej. Puerta principal');
    if (nombre == null || !mounted) return;
    await _run(() => _repo.cableadoRegistrarEntrada(_id, index, nombre: nombre));
  }

  // ---------------------------------------------------------------- sirena
  Future<void> _probarSirena() async {
    await _run(() => _repo.cableadoProbarSirena(_id));
    if (!mounted || _sirena['probada'] != true || _sirena['sono'] != null) return;
    final sono = await _preguntar('¿Sonó la sirena?', 'El equipo la hizo sonar 3 segundos.');
    if (sono == null || !mounted) return;
    await _run(() => _repo.cableadoConfirmarSirena(_id, sono: sono));
  }

  // ---------------------------------------------------------------- salidas
  Future<void> _probarSalida(int index) async {
    await _run(() => _repo.cableadoProbarSalida(_id, index));
    if (!mounted) return;
    final fila = _salidas.firstWhere((s) => s['index'] == index, orElse: () => const {});
    if (fila['probada'] != true) return;
    final funciono = await _preguntar('¿Se encendió?', 'El equipo encendió la salida $index durante 5 segundos. ¿Lo que está conectado (luz, portón, bomba) respondió?');
    if (funciono == null || !mounted) return;
    final alta = await _formSalida(index);
    if (alta == null || !mounted) return;
    await _run(() => _repo.cableadoRegistrarSalida(_id, index, nombre: alta.nombre, tipo: alta.tipo, modo: alta.modo, pulsoSeg: alta.modo == 'pulso' ? alta.pulsoSeg : null, funciono: funciono));
    if (!funciono && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se guardó: la salida no encendió. Quedó anotado en el reporte.')));
    }
  }

  // ---------------------------------------------------------------- diálogos
  Future<bool?> _preguntar(String titulo, String texto) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
      ],
    ),
  );

  Future<String?> _pedirNombre(String titulo, String inicial, {required String ejemplo}) async {
    final r = await showDialog<String>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: [inicial],
        builder: (ctx, c) => AlertDialog(
          title: Text(titulo),
          content: TextField(
            controller: c[0],
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: ejemplo, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c[0].text.trim()), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<_AltaSalida?> _formSalida(int index) {
    // Tipo y modo fuera del builder: sobreviven a que el diálogo se reconstruya (teclado).
    var tipo = 'luz';
    var modo = 'on_off';
    return showDialog<_AltaSalida>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const [''],
        builder: (ctx, c) {
          return StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: Text('¿Qué conectaste a la salida $index?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: c[0],
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Luz del jardín', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: '¿Qué es?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'luz', child: Text('Luz')),
                      DropdownMenuItem(value: 'bomba', child: Text('Bomba')),
                      DropdownMenuItem(value: 'porton', child: Text('Portón')),
                      DropdownMenuItem(value: 'sirena', child: Text('Sirena externa')),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (v) => setLocal(() => tipo = v ?? 'otro'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: modo,
                    decoration: const InputDecoration(labelText: '¿Cómo funciona?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'on_off', child: Text('Encendido / apagado')),
                      DropdownMenuItem(value: 'pulso', child: Text('Pulso (como un portón)')),
                    ],
                    onChanged: (v) => setLocal(() => modo = v ?? 'on_off'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    final nombre = c[0].text.trim();
                    if (nombre.isNotEmpty) Navigator.pop(ctx, _AltaSalida(nombre, tipo, modo, 2));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- UI
  /// Lo ya guardado: fila normal con el círculo marcado del paso 2.
  Widget _guardado(String titulo, String subtitulo) => FilaFlujo(titulo: titulo, subtitulo: subtitulo, trailing: const CirculoCheck(marcado: true));

  /// Fila para agregar algo nuevo: el botón tiene la forma del «+» del contador del paso 3.
  Widget _agregar(String titulo, String subtitulo, VoidCallback? onPressed) =>
      FilaFlujo(titulo: titulo, subtitulo: subtitulo, trailing: BotonFila(etiqueta: 'Agregar', icono: Icons.add, onPressed: onPressed));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    // Cualquier salida (botón, gesto o atrás del sistema) cierra la ventana de control.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EncabezadoFlujo(titulo: 'Agregar dispositivos', alVolver: _salir),
                  Expanded(
                    child: _cargando
                        ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(cs.primary)))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (_error != null) MensajeFlujo(icono: Icons.error_outline, color: cs.error, titulo: 'No pudimos leer el equipo', texto: _error!),
                              if (_e != null && !_firmwareOk)
                                MensajeFlujo(
                                  icono: Icons.system_update_alt,
                                  color: cs.error,
                                  titulo: 'Este energizador necesita actualizarse',
                                  texto:
                                      'Las puertas con cable, la sirena y las salidas piden la versión ${_equipo['firmwareMinimo'] ?? '2.10'} o más nueva. Lo demás sí lo puedes agregar.',
                                ),
                              if (_e != null && _firmwareOk && !_enLinea)
                                MensajeFlujo(icono: Icons.wifi_off_rounded, color: cs.error, titulo: 'El energizador no tiene señal', texto: 'Revisa que esté conectado a la corriente y con señal.'),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                                child: Text(
                                  'Agrega sólo lo que el cliente compró. Cada cosa se prueba en vivo y sólo se guarda si funciona.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, height: 1.4, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                                ),
                              ),

                              // ---------------- Entradas
                              const EtiquetaSeccion(
                                'PUERTAS CON CABLE',
                                tituloAyuda: 'Puertas con cable',
                                ayuda: [
                                  'Sensores de puerta conectados con cable a las entradas del energizador.',
                                  'Toca «Probar», cierra la puerta y espera; luego ábrela.',
                                  'Cuando el equipo ve las dos cosas, le pones nombre y se guarda.',
                                ],
                              ),
                              for (final x in _entradas) _tarjetaEntrada(x, theme, cs, ohm),

                              // ---------------- Sirena
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'SIRENA',
                                tituloAyuda: 'Sirena',
                                ayuda: ['Al probarla suena 3 segundos. Avísale al cliente antes: es fuerte.', 'Después la app te pregunta si sonó.'],
                              ),
                              FilaFlujo(
                                titulo: 'Sirena del energizador',
                                subtitulo: _sirena['sono'] == true
                                    ? 'Funciona'
                                    : _sirena['sono'] == false
                                    ? 'No sonó. Revisa el cable y vuelve a probar.'
                                    : 'Suena 3 segundos',
                                colorSubtitulo: _sirena['sono'] == false ? cs.error : null,
                                trailing: _sirena['sono'] == true ? const CirculoCheck(marcado: true) : BotonFila(etiqueta: 'Probar', onPressed: _listo ? _probarSirena : null),
                              ),

                              // ---------------- Salidas
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'LUCES, PORTÓN Y OTROS',
                                tituloAyuda: 'Luces, portón y otros',
                                ayuda: [
                                  'Son las salidas del energizador para encender algo: una luz, un portón, una bomba.',
                                  'Al probarla se enciende 5 segundos.',
                                  'Si funcionó, le pones nombre y eliges qué es.',
                                ],
                              ),
                              for (final x in _salidas) _tarjetaSalida(x, theme, cs, ohm),

                              // ---------------- Sensores 433
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'SENSORES INALÁMBRICOS',
                                tituloAyuda: 'Sensores inalámbricos',
                                ayuda: [
                                  'Puerta, movimiento, humo o botón de pánico que se ligan al energizador por radio.',
                                  'El energizador los aprende en vivo: la app te dice qué hacer con el sensor.',
                                  'El energizador debe tener señal.',
                                ],
                              ),
                              for (final x in _lista('rf', 'dispositivos')) _guardado((x['nombre'] ?? '').toString(), _tipoRfTexto[x['tipo']] ?? 'Sensor inalámbrico'),
                              _agregar(
                                'Sensor inalámbrico',
                                !_rfSoportado ? 'Este energizador no los maneja' : (_enLinea ? 'Puerta, movimiento, humo o pánico' : 'Necesita señal para aprenderlo'),
                                _ocupado || _disp == null || !_rfSoportado || !_enLinea ? null : _agregarRf,
                              ),

                              // ---------------- Sensores Wi‑Fi
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'SENSORES WI‑FI',
                                tituloAyuda: 'Sensores Wi‑Fi',
                                ayuda: [
                                  'Se conectan al internet de la casa, no al energizador.',
                                  'Aquí registras su ID; el cliente termina de conectarlo desde su app.',
                                  'El ID viene en la etiqueta o en la app del sensor.',
                                ],
                              ),
                              for (final x in _lista('wifi', 'sensores')) _guardado((x['nombre'] ?? '').toString(), '${_tipoWifiTexto[x['tipo']] ?? 'Sensor'} · ID ${x['externalId'] ?? ''}'),
                              _agregar('Sensor Wi‑Fi', 'Puerta, movimiento o humo', _ocupado || _disp == null ? null : _agregarWifi),

                              // ---------------- Cámaras
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'CÁMARAS',
                                tituloAyuda: 'Cámaras',
                                ayuda: [
                                  'La cámara debe estar encendida y conectada al internet de la casa.',
                                  'Necesitas el número de serie y el código de verificación de su etiqueta.',
                                  'Al guardarla, el cliente la ve en su app.',
                                ],
                              ),
                              for (final x in _lista('camaras', 'lista'))
                                FilaFlujo(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: 'Serie ${x['serie'] ?? ''} · ${x['estado'] == 'online' ? 'en línea' : 'sin respuesta'}',
                                  trailing: CirculoCheck(marcado: x['estado'] == 'online'),
                                ),
                              _agregar('Cámara', _hayProveedor ? 'Serie y código de su etiqueta' : 'No disponibles por ahora', _ocupado || !_hayProveedor ? null : _agregarCamara),

                              // ---------------- OhmBox: lo menos común, al final.
                              const SizedBox(height: 12),
                              const EtiquetaSeccion(
                                'OTRO ENERGIZADOR EN ESTA CASA',
                                tituloAyuda: 'Otro energizador (OhmBox)',
                                ayuda: [
                                  'Sólo si el cliente compró un segundo energizador para la misma casa.',
                                  'Se suma como complemento de su suscripción; no crea una nueva.',
                                  'Para otra dirección se hace una venta aparte.',
                                ],
                              ),
                              for (final x in _energizadores)
                                FilaFlujo(
                                  titulo: '${x['serie']}${x['principal'] == true ? ' · principal' : ''}',
                                  subtitulo: x['enLinea'] == true ? 'En línea' : 'Sin señal todavía',
                                  trailing: CirculoCheck(marcado: x['enLinea'] == true),
                                ),
                              _agregar('OhmBox adicional', 'Escanea su QR o escribe su serie', _ocupado || _ohmbox == null ? null : _agregarOhmbox),

                              const SizedBox(height: 20),
                              OhmGradientButton(label: 'Listo, volver a los pasos', loading: _saliendo, onPressed: _ocupado ? null : _salir),
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

  Widget _tarjetaEntrada(Map<String, dynamic> x, ThemeData theme, ColorScheme cs, OhmColors ohm) {
    final index = (x['index'] as num).toInt();
    final nombre = (x['nombre'] ?? 'Entrada $index').toString();
    final alta = x['dadaDeAlta'] == true;
    final prueba = (x['prueba'] as Map?)?.cast<String, dynamic>();
    final fase = prueba?['fase']?.toString();
    final abierta = x['abierta'];
    final ahora = abierta == true ? 'abierta' : (abierta == false ? 'cerrada' : 'sin reporte');
    final titulo = alta && nombre != 'Entrada $index' ? nombre : 'Entrada $index';
    const espera = SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    if (alta) return _guardado(titulo, 'Entrada $index · ahora está $ahora');
    return switch (fase) {
      'cerrar' => FilaFlujo(titulo: titulo, subtitulo: '1 de 2 · Cierra la puerta y espera 3 segundos', colorSubtitulo: cs.primary, trailing: espera),
      'abrir' => FilaFlujo(titulo: titulo, subtitulo: '2 de 2 · Ahora ábrela', colorSubtitulo: cs.primary, trailing: espera),
      'verificada' => FilaFlujo(
        titulo: titulo,
        subtitulo: 'Funciona. Ponle nombre para guardarla.',
        trailing: BotonFila(etiqueta: 'Guardar', lleno: true, onPressed: _ocupado ? null : () => _registrarEntrada(index, nombre)),
      ),
      'expirada' => FilaFlujo(
        titulo: titulo,
        subtitulo: 'No vimos la puerta cerrar y abrir. Revisa el cable.',
        colorSubtitulo: cs.error,
        trailing: BotonFila(etiqueta: 'Reintentar', onPressed: _listo ? () => _probarEntrada(index) : null),
      ),
      _ => FilaFlujo(titulo: titulo, subtitulo: 'Sin probar · ahora marca $ahora', trailing: BotonFila(etiqueta: 'Probar', onPressed: _listo ? () => _probarEntrada(index) : null)),
    };
  }

  Widget _tarjetaSalida(Map<String, dynamic> s, ThemeData theme, ColorScheme cs, OhmColors ohm) {
    final index = (s['index'] as num).toInt();
    if (s['dadaDeAlta'] == true) {
      final tipo = s['tipo']?.toString();
      return _guardado((s['nombre'] ?? 'Salida $index').toString(), 'Salida $index · ${_tipoSalidaTexto[tipo] ?? tipo ?? ''} · ${s['modo'] == 'pulso' ? 'pulso' : 'encendido/apagado'}');
    }
    return FilaFlujo(titulo: 'Salida $index', subtitulo: 'Se enciende 5 segundos', trailing: BotonFila(etiqueta: 'Probar', onPressed: _listo ? () => _probarSalida(index) : null));
  }
}

class _AltaSalida {
  const _AltaSalida(this.nombre, this.tipo, this.modo, this.pulsoSeg);
  final String nombre;
  final String tipo;
  final String modo;
  final int pulsoSeg;
}
