import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/serie_formato.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import 'escanear_serie_screen.dart';
import '../widgets/aprender_rf_sheet.dart';

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
    final idCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    String tipo = 'door';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'ID del sensor', helperText: 'Viene en la etiqueta o en la app del sensor.', helperMaxLines: 2),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Ventana de la sala'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, idCtrl.text.trim().isNotEmpty && nombreCtrl.text.trim().isNotEmpty), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final externalId = idCtrl.text.trim();
    final nombre = nombreCtrl.text.trim();
    idCtrl.dispose();
    nombreCtrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    final r = await _repo.sensorWifiAgregar(_id, externalId: externalId, nombre: nombre, tipo: tipo);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((_) => _aviso('Sensor Wi‑Fi «$nombre» guardado'), (f) => _aviso(f.message));
    await _cargarDisp();
  }

  // ---------------------------------------------------------------- Cámaras
  Future<void> _agregarCamara() async {
    final serieCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar cámara'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('La cámara debe estar encendida y con internet.', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(controller: serieCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Número de serie', helperText: 'En la etiqueta, como S/N.')),
              const SizedBox(height: 12),
              TextField(controller: codigoCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código de verificación', helperText: 'En la misma etiqueta.')),
              const SizedBox(height: 12),
              TextField(controller: nombreCtrl, maxLength: 40, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Cochera')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, serieCtrl.text.trim().isNotEmpty && codigoCtrl.text.trim().isNotEmpty && nombreCtrl.text.trim().isNotEmpty),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    final serie = serieCtrl.text.trim();
    final codigo = codigoCtrl.text.trim();
    final nombre = nombreCtrl.text.trim();
    serieCtrl.dispose();
    codigoCtrl.dispose();
    nombreCtrl.dispose();
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    // Sin marca: el backend prueba cada nube habilitada y se queda con la que reconoce la cámara.
    final r = await _repo.camaraAgregar(_id, serie: serie, codigo: codigo, nombre: nombre);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((_) => _aviso('Cámara «$nombre» guardada'), (f) => _aviso(f.message));
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

  Future<String?> _pedirSerie() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otro energizador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se suma a «$_casaNombre» como complemento. No crea otra suscripción.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
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
                    if (leida != null && leida.isNotEmpty) ctrl.text = leida;
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
              final s = normalizarSerie(ctrl.text);
              if (s.isNotEmpty) Navigator.pop(ctx, s);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return r;
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
    final c = TextEditingController(text: inicial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: ejemplo, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    c.dispose();
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<_AltaSalida?> _formSalida(int index) async {
    final nombre = TextEditingController();
    var tipo = 'luz';
    var modo = 'on_off';
    final r = await showDialog<_AltaSalida>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('¿Qué conectaste a la salida $index?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nombre,
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
            FilledButton(onPressed: () => nombre.text.trim().isEmpty ? null : Navigator.pop(ctx, _AltaSalida(nombre.text.trim(), tipo, modo, 2)), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    nombre.dispose();
    return r;
  }

  // ---------------------------------------------------------------- UI
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
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(onPressed: _salir, icon: const Icon(Icons.chevron_left, size: 30)),
                        const Expanded(
                          child: Text(
                            'Agregar dispositivos',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const NotificationBell(),
                      ],
                    ),
                  ),
                  const PasoDeInstalacion(paso: 6, opcional: true),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                            children: [
                              if (_error != null) _Aviso(icono: Icons.error_outline, color: cs.error, titulo: 'No pudimos leer el equipo', texto: _error!),
                              if (_e != null && !_firmwareOk)
                                _Aviso(
                                  icono: Icons.system_update_alt,
                                  color: cs.error,
                                  titulo: 'Este energizador necesita actualizarse',
                                  texto:
                                      'Las puertas con cable, la sirena y las salidas piden la versión ${_equipo['firmwareMinimo'] ?? '2.10'} o más nueva (tiene ${_equipo['firmware'] ?? 'una desconocida'}). Lo demás sí lo puedes agregar.',
                                ),
                              if (_e != null && _firmwareOk && !_enLinea)
                                _Aviso(icono: Icons.wifi_off, color: cs.error, titulo: 'El energizador no tiene señal', texto: 'Revisa que esté conectado a la corriente y con señal.'),
                              const SizedBox(height: 8),
                              Text('Agrega sólo lo que el cliente compró. Cada cosa se prueba en vivo y sólo se guarda si funciona.', style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                              const SizedBox(height: 18),

                              // ---------------- Entradas
                              const TituloSeccion(
                                'PUERTAS CON CABLE',
                                ayuda: InfoAyuda(
                                  titulo: 'Puertas con cable',
                                  puntos: [
                                    'Son sensores de puerta conectados con cable a las entradas del energizador.',
                                    'Toca «Probar», cierra la puerta y espera; luego ábrela.',
                                    'Cuando el equipo ve las dos cosas, le pones nombre y se guarda.',
                                  ],
                                ),
                              ),
                              for (final x in _entradas) _tarjetaEntrada(x, theme, cs, ohm),

                              // ---------------- Sirena
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'SIRENA',
                                ayuda: InfoAyuda(
                                  titulo: 'Sirena',
                                  puntos: [
                                    'Al probarla, la sirena suena 3 segundos.',
                                    'Avísale al cliente antes: es fuerte.',
                                    'Después la app te pregunta si sonó.',
                                  ],
                                ),
                              ),
                              _Tarjeta(
                                titulo: 'Sirena del energizador',
                                subtitulo: _sirena['sono'] == true
                                    ? 'Funciona: sí sonó'
                                    : _sirena['sono'] == false
                                    ? 'No sonó. Revisa el cable y vuelve a probar.'
                                    : 'Suena 3 segundos al probarla',
                                color: _sirena['sono'] == true ? ohm.success : (_sirena['sono'] == false ? cs.error : null),
                                accion: OutlinedButton.icon(onPressed: _listo ? _probarSirena : null, icon: const Icon(Icons.campaign_outlined), label: const Text('Probar')),
                              ),

                              // ---------------- Salidas
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'LUCES, PORTÓN Y OTROS (SALIDAS)',
                                ayuda: InfoAyuda(
                                  titulo: 'Salidas',
                                  puntos: [
                                    'Son las conexiones del energizador para encender algo: una luz, un portón, una bomba.',
                                    'Al probarla, la salida se enciende 5 segundos.',
                                    'Si funcionó, le pones nombre y eliges qué es.',
                                  ],
                                ),
                              ),
                              for (final x in _salidas) _tarjetaSalida(x, theme, cs, ohm),

                              // ---------------- Sensores 433
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'SENSORES INALÁMBRICOS',
                                ayuda: InfoAyuda(
                                  titulo: 'Sensores inalámbricos',
                                  puntos: [
                                    'Puerta, movimiento, humo o botón de pánico que se ligan al energizador por radio, sin cable.',
                                    'El energizador los «aprende» en vivo: la app te dice qué hacer con el sensor (abrir la puerta, pasar frente a él…).',
                                    'El energizador debe tener señal.',
                                  ],
                                ),
                              ),
                              for (final x in _lista('rf', 'dispositivos'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: _tipoRfTexto[x['tipo']] ?? 'Sensor inalámbrico',
                                  color: ohm.success,
                                  accion: Icon(Icons.check_circle, color: ohm.success),
                                ),
                              _Tarjeta(
                                titulo: 'Sensor inalámbrico',
                                subtitulo: !_rfSoportado
                                    ? 'Este energizador no maneja sensores inalámbricos.'
                                    : (_enLinea ? 'Puerta, movimiento, humo o botón de pánico' : 'El energizador necesita señal para aprenderlo.'),
                                accion: OutlinedButton.icon(
                                  onPressed: _ocupado || _disp == null || !_rfSoportado || !_enLinea ? null : _agregarRf,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar'),
                                ),
                              ),

                              // ---------------- Sensores Wi‑Fi
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'SENSORES WI‑FI',
                                ayuda: InfoAyuda(
                                  titulo: 'Sensores Wi‑Fi',
                                  puntos: [
                                    'Se conectan al internet de la casa, no al energizador.',
                                    'Aquí sólo registras su ID; el cliente termina de conectarlo desde su app.',
                                    'El ID viene en la etiqueta o en la app del sensor.',
                                  ],
                                ),
                              ),
                              for (final x in _lista('wifi', 'sensores'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: '${_tipoWifiTexto[x['tipo']] ?? 'Sensor'} · ID ${x['externalId'] ?? ''}',
                                  color: ohm.success,
                                  accion: Icon(Icons.check_circle, color: ohm.success),
                                ),
                              _Tarjeta(
                                titulo: 'Sensor Wi‑Fi',
                                subtitulo: 'Puerta, movimiento o humo',
                                accion: OutlinedButton.icon(onPressed: _ocupado || _disp == null ? null : _agregarWifi, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),

                              // ---------------- Cámaras
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'CÁMARAS',
                                ayuda: InfoAyuda(
                                  titulo: 'Cámaras',
                                  puntos: [
                                    'La cámara debe estar encendida y conectada al internet de la casa.',
                                    'Escribe el número de serie y el código de verificación: los dos vienen en su etiqueta.',
                                    'Al guardarla, el cliente la ve en su app.',
                                  ],
                                ),
                              ),
                              for (final x in _lista('camaras', 'lista'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: 'Serie ${x['serie'] ?? ''} · ${x['estado'] == 'online' ? 'en línea' : 'sin respuesta'}',
                                  color: x['estado'] == 'online' ? ohm.success : null,
                                  accion: Icon(Icons.videocam_outlined, color: x['estado'] == 'online' ? ohm.success : cs.onSurfaceVariant),
                                ),
                              _Tarjeta(
                                titulo: 'Cámara',
                                subtitulo: _hayProveedor ? 'Con la serie y el código de su etiqueta' : 'Las cámaras no están disponibles por ahora.',
                                accion: OutlinedButton.icon(onPressed: _ocupado || !_hayProveedor ? null : _agregarCamara, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),

                              // ---------------- OhmBox (energizadores de la casa): lo menos común, al final.
                              const SizedBox(height: 14),
                              const TituloSeccion(
                                'OTRO ENERGIZADOR EN ESTA CASA',
                                ayuda: InfoAyuda(
                                  titulo: 'Otro energizador (OhmBox)',
                                  puntos: [
                                    'Úsalo si el cliente compró un segundo energizador para la misma casa.',
                                    'Se suma como complemento de su suscripción; no crea una nueva.',
                                    'Para otra casa u otra dirección se hace una venta aparte.',
                                  ],
                                ),
                              ),
                              for (final x in _energizadores)
                                _Tarjeta(
                                  titulo: '${x['serie']}${x['principal'] == true ? ' · principal' : ''}',
                                  subtitulo: x['enLinea'] == true ? 'En línea' : 'Sin señal todavía',
                                  color: x['enLinea'] == true ? ohm.success : null,
                                  accion: Icon(Icons.bolt, color: x['enLinea'] == true ? ohm.success : cs.onSurfaceVariant),
                                ),
                              _Tarjeta(
                                titulo: 'OhmBox adicional',
                                subtitulo: 'Escanea su QR o escribe su serie',
                                accion: OutlinedButton.icon(onPressed: _ocupado || _ohmbox == null ? null : _agregarOhmbox, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),
                              const SizedBox(height: 24),
                              OhmGradientButton(label: 'Listo, volver a los pasos', icon: Icons.check, loading: _saliendo, onPressed: _ocupado ? null : _salir),
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
    String subtitulo;
    Color? color;
    Widget accion;
    if (alta) {
      subtitulo =
          'Guardada · ahora está ${abierta == true
              ? 'abierta'
              : abierta == false
              ? 'cerrada'
              : 'sin reporte'}';
      color = ohm.success;
      accion = Icon(Icons.check_circle, color: ohm.success);
    } else if (fase == 'cerrar') {
      subtitulo = '1 de 2 · Cierra la puerta y espera 3 segundos…';
      color = cs.secondary;
      accion = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (fase == 'abrir') {
      subtitulo = '2 de 2 · ¡Bien! Ahora ábrela…';
      color = cs.secondary;
      accion = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (fase == 'verificada') {
      subtitulo = '¡Funciona! Ponle nombre para guardarla.';
      color = ohm.success;
      accion = FilledButton(onPressed: _ocupado ? null : () => _registrarEntrada(index, nombre), child: const Text('Guardar'));
    } else if (fase == 'expirada') {
      subtitulo = 'No vimos la puerta cerrar y abrir. Revisa el cable del sensor y vuelve a probar.';
      color = cs.error;
      accion = OutlinedButton(onPressed: _listo ? () => _probarEntrada(index) : null, child: const Text('Reintentar'));
    } else {
      subtitulo = 'Sin probar · ahora marca ${abierta == true
          ? 'abierta'
          : abierta == false
          ? 'cerrada'
          : 'sin reporte'}';
      accion = OutlinedButton.icon(onPressed: _listo ? () => _probarEntrada(index) : null, icon: const Icon(Icons.sensor_door_outlined), label: const Text('Probar'));
    }
    return _Tarjeta(titulo: alta && nombre != 'Entrada $index' ? 'Entrada $index · $nombre' : 'Entrada $index', subtitulo: subtitulo, color: color, accion: accion);
  }

  Widget _tarjetaSalida(Map<String, dynamic> s, ThemeData theme, ColorScheme cs, OhmColors ohm) {
    final index = (s['index'] as num).toInt();
    final alta = s['dadaDeAlta'] == true;
    final nombre = s['nombre']?.toString();
    final tipo = s['tipo']?.toString();
    final modo = s['modo']?.toString();
    return _Tarjeta(
      titulo: alta ? 'Salida $index · $nombre' : 'Salida $index',
      subtitulo: alta ? 'Guardada · ${_tipoSalidaTexto[tipo] ?? tipo ?? ''} · ${modo == 'pulso' ? 'pulso' : 'encendido/apagado'}' : 'Se enciende 5 segundos al probarla',
      color: alta ? ohm.success : null,
      accion: alta
          ? Icon(Icons.check_circle, color: ohm.success)
          : OutlinedButton.icon(onPressed: _listo ? () => _probarSalida(index) : null, icon: const Icon(Icons.power), label: const Text('Probar')),
    );
  }
}

class _AltaSalida {
  const _AltaSalida(this.nombre, this.tipo, this.modo, this.pulsoSeg);
  final String nombre;
  final String tipo;
  final String modo;
  final int pulsoSeg;
}

const _compacto = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 44)), padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)));

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.subtitulo, required this.accion, this.color});
  final String titulo;
  final String subtitulo;
  final Widget accion;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (color ?? theme.dividerColor).withValues(alpha: color == null ? 0.6 : 0.8),
          width: color == null ? 1 : 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitulo, style: theme.textTheme.bodySmall?.copyWith(color: color ?? cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // El tema hace los botones de ancho completo; dentro de la fila van compactos.
          Theme(
            data: theme.copyWith(
              outlinedButtonTheme: OutlinedButtonThemeData(style: _compacto.merge(theme.outlinedButtonTheme.style)),
              filledButtonTheme: FilledButtonThemeData(style: _compacto.merge(theme.filledButtonTheme.style)),
            ),
            child: accion,
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 8),
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
