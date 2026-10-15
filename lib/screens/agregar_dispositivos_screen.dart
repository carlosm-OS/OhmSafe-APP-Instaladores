import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/serie_formato.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../widgets/ohm_gradient_button.dart';
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
    _ventana = Timer.periodic(const Duration(minutes: 1), (_) => _renovarVentana());
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
              child: Text('¿Qué sensor 433 vas a agregar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
    if (nombre != null) _aviso('Sensor 433 «$nombre» dado de alta');
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
                Text('Se registra con el id del sensor; el cliente lo empareja desde su app.', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [for (final e in _tipoWifiTexto.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => set(() => tipo = v ?? 'door'),
                ),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'Id del sensor'),
                ),
                TextField(
                  controller: nombreCtrl,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ventana de la sala'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, idCtrl.text.trim().isNotEmpty && nombreCtrl.text.trim().isNotEmpty), child: const Text('Registrar')),
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
    r.fold((_) => _aviso('Sensor Wi‑Fi «$nombre» registrado'), (f) => _aviso(f.message));
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
              Text('La cámara debe estar encendida y con internet. La serie y el código vienen en su etiqueta.', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(controller: serieCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Número de serie (S/N)')),
              TextField(controller: codigoCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código de verificación')),
              TextField(controller: nombreCtrl, maxLength: 40, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Cochera')),
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
    r.fold((_) => _aviso('Cámara «$nombre» agregada'), (f) => _aviso(f.message));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OhmBox $serie agregado a «$_casaNombre»')));
    }, (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))));
  }

  Future<String?> _pedirSerie() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OhmBox adicional'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se suma a «$_casaNombre» como complemento de su suscripción.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [SerieInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Número de serie',
                hintText: 'OS-OBV01-0000',
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
      _sondeo = Timer.periodic(const Duration(seconds: 2), (_) => _cargar());
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
    final nombre = await _pedirNombre('Nombre de la entrada $index', nombreActual, ejemplo: 'Puerta principal');
    if (nombre == null || !mounted) return;
    await _run(() => _repo.cableadoRegistrarEntrada(_id, index, nombre: nombre));
  }

  // ---------------------------------------------------------------- sirena
  Future<void> _probarSirena() async {
    await _run(() => _repo.cableadoProbarSirena(_id));
    if (!mounted || _sirena['probada'] != true || _sirena['sono'] != null) return;
    final sono = await _preguntar('¿Sonó la sirena?', 'El equipo activó la sirena 3 segundos.');
    if (sono == null || !mounted) return;
    await _run(() => _repo.cableadoConfirmarSirena(_id, sono: sono));
  }

  // ---------------------------------------------------------------- salidas
  Future<void> _probarSalida(int index) async {
    await _run(() => _repo.cableadoProbarSalida(_id, index));
    if (!mounted) return;
    final fila = _salidas.firstWhere((s) => s['index'] == index, orElse: () => const {});
    if (fila['probada'] != true) return;
    final funciono = await _preguntar('¿Se encendió?', 'El relé de la salida $index cerró 5 segundos.');
    if (funciono == null || !mounted) return;
    final alta = await _formSalida(index);
    if (alta == null || !mounted) return;
    await _run(() => _repo.cableadoRegistrarSalida(_id, index, nombre: alta.nombre, tipo: alta.tipo, modo: alta.modo, pulsoSeg: alta.modo == 'pulso' ? alta.pulsoSeg : null, funciono: funciono));
    if (!funciono && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quedó en el acta que la salida no encendió; no se dio de alta.')));
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
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Dar de alta')),
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
          title: Text('Salida $index'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Luz del jardín', border: OutlineInputBorder()),
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
                  DropdownMenuItem(value: 'pulso', child: Text('Pulso (cierra y suelta, como un portón)')),
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
    final muted = theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
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
                  Expanded(
                    child: _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                            children: [
                              if (_error != null) _Aviso(icono: Icons.error_outline, color: cs.error, titulo: 'No se pudo leer el equipo', texto: _error!),
                              if (_e != null && !_firmwareOk)
                                _Aviso(
                                  icono: Icons.system_update_alt,
                                  color: cs.error,
                                  titulo: 'Firmware ${_equipo['firmware'] ?? 'desconocido'}',
                                  texto:
                                      'Las entradas cableadas, la sirena y las salidas piden ${_equipo['firmwareMinimo'] ?? '2.10'} o superior. Los sensores, las cámaras y el OhmBox sí se pueden agregar.',
                                ),
                              if (_e != null && _firmwareOk && !_enLinea)
                                _Aviso(icono: Icons.wifi_off, color: cs.error, titulo: 'El energizador no reporta', texto: 'Revisa que esté encendido y con señal.'),
                              const SizedBox(height: 12),
                              Text('Cada elemento se prueba en vivo; sólo se da de alta lo que el equipo confirma.', style: muted),
                              const SizedBox(height: 16),

                              // ---------------- OhmBox (energizadores de la casa)
                              _Titulo('OHMBOX · ENERGIZADORES DE LA CASA'),
                              for (final x in _energizadores)
                                _Tarjeta(
                                  titulo: '${x['serie']}${x['principal'] == true ? ' · principal' : ''}',
                                  subtitulo: x['enLinea'] == true ? 'En línea' : 'Sin reporte todavía',
                                  color: x['enLinea'] == true ? ohm.success : null,
                                  accion: Icon(Icons.bolt, color: x['enLinea'] == true ? ohm.success : cs.onSurfaceVariant),
                                ),
                              _Tarjeta(
                                titulo: 'Otro OhmBox en esta casa',
                                subtitulo: 'Un segundo energizador es un complemento de la suscripción, no un paquete nuevo.',
                                accion: OutlinedButton.icon(onPressed: _ocupado || _ohmbox == null ? null : _agregarOhmbox, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),
                              const SizedBox(height: 10),

                              // ---------------- Entradas
                              _Titulo('ENTRADAS CABLEADAS (PUERTAS)'),
                              for (final x in _entradas) _tarjetaEntrada(x, theme, cs, ohm),

                              // ---------------- Sirena
                              const SizedBox(height: 10),
                              _Titulo('SIRENA'),
                              _Tarjeta(
                                titulo: 'Sirena del equipo',
                                subtitulo: _sirena['sono'] == true
                                    ? 'Probada: sonó'
                                    : _sirena['sono'] == false
                                    ? 'Probada: NO sonó (revisar conexión)'
                                    : 'Sin probar',
                                color: _sirena['sono'] == true ? ohm.success : (_sirena['sono'] == false ? cs.error : null),
                                accion: OutlinedButton.icon(onPressed: _listo ? _probarSirena : null, icon: const Icon(Icons.campaign_outlined), label: const Text('Probar 3 s')),
                              ),

                              // ---------------- Salidas
                              const SizedBox(height: 10),
                              _Titulo('SALIDAS AUXILIARES'),
                              for (final s in _salidas) _tarjetaSalida(s, theme, cs, ohm),

                              // ---------------- Sensores 433
                              const SizedBox(height: 10),
                              _Titulo('SENSORES 433 (INALÁMBRICOS)'),
                              for (final x in _lista('rf', 'dispositivos'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: _tipoRfTexto[x['tipo']] ?? 'Sensor 433',
                                  color: ohm.success,
                                  accion: Icon(Icons.check_circle, color: ohm.success),
                                ),
                              _Tarjeta(
                                titulo: 'Agregar sensor 433',
                                subtitulo: !_rfSoportado
                                    ? 'El firmware de este energizador no maneja 433.'
                                    : (_enLinea ? 'Puerta, movimiento, humo o botón de pánico. El equipo lo aprende en vivo.' : 'El energizador debe estar en línea para aprender.'),
                                accion: OutlinedButton.icon(
                                  onPressed: _ocupado || _disp == null || !_rfSoportado || !_enLinea ? null : _agregarRf,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar'),
                                ),
                              ),

                              // ---------------- Sensores Wi‑Fi
                              const SizedBox(height: 10),
                              _Titulo('SENSORES WI‑FI'),
                              for (final x in _lista('wifi', 'sensores'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: '${_tipoWifiTexto[x['tipo']] ?? 'Sensor'} · id ${x['externalId'] ?? ''}',
                                  color: ohm.success,
                                  accion: Icon(Icons.check_circle, color: ohm.success),
                                ),
                              _Tarjeta(
                                titulo: 'Registrar sensor Wi‑Fi',
                                subtitulo: 'Se registra con el id del sensor; el cliente lo empareja desde su app.',
                                accion: OutlinedButton.icon(onPressed: _ocupado || _disp == null ? null : _agregarWifi, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),

                              // ---------------- Cámaras
                              const SizedBox(height: 10),
                              _Titulo('CÁMARAS'),
                              for (final x in _lista('camaras', 'lista'))
                                _Tarjeta(
                                  titulo: (x['nombre'] ?? '').toString(),
                                  subtitulo: 'Serie ${x['serie'] ?? ''} · ${x['estado'] == 'online' ? 'en línea' : 'sin respuesta'}',
                                  color: x['estado'] == 'online' ? ohm.success : null,
                                  accion: Icon(Icons.videocam_outlined, color: x['estado'] == 'online' ? ohm.success : cs.onSurfaceVariant),
                                ),
                              _Tarjeta(
                                titulo: 'Agregar cámara',
                                subtitulo: _hayProveedor ? 'Con el número de serie y el código de verificación de la etiqueta.' : 'Las cámaras no están disponibles en este ambiente.',
                                accion: OutlinedButton.icon(onPressed: _ocupado || !_hayProveedor ? null : _agregarCamara, icon: const Icon(Icons.add), label: const Text('Agregar')),
                              ),

                              const SizedBox(height: 24),
                              OhmGradientButton(label: 'Listo, volver a los pasos', icon: Icons.check, loading: _saliendo, onPressed: _ocupado || _saliendo ? null : _salir),
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
          'Dada de alta · ${abierta == true
              ? 'abierta'
              : abierta == false
              ? 'cerrada'
              : 'sin reporte'}';
      color = ohm.success;
      accion = Icon(Icons.check_circle, color: ohm.success);
    } else if (fase == 'cerrar') {
      subtitulo = 'Cierra la puerta y espera: el equipo debe verla cerrada 3 segundos…';
      color = cs.secondary;
      accion = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (fase == 'abrir') {
      subtitulo = 'Cerrada confirmada. Ahora ábrela…';
      color = cs.secondary;
      accion = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (fase == 'verificada') {
      subtitulo = 'Verificada: cerró y abrió. Ponle nombre para darla de alta.';
      color = ohm.success;
      accion = FilledButton(onPressed: _ocupado ? null : () => _registrarEntrada(index, nombre), child: const Text('Dar de alta'));
    } else if (fase == 'expirada') {
      subtitulo = 'Se acabó el tiempo sin ver la puerta cerrar y abrir. ¿Hay sensor conectado? Prueba de nuevo.';
      color = cs.error;
      accion = OutlinedButton(onPressed: _listo ? () => _probarEntrada(index) : null, child: const Text('Probar de nuevo'));
    } else {
      subtitulo =
          'Sin sensor dado de alta · ahora se lee ${abierta == true
              ? 'abierta'
              : abierta == false
              ? 'cerrada'
              : 'sin reporte'}';
      accion = OutlinedButton.icon(onPressed: _listo ? () => _probarEntrada(index) : null, icon: const Icon(Icons.sensor_door_outlined), label: const Text('Probar'));
    }
    return _Tarjeta(titulo: 'Entrada $index · $nombre', subtitulo: subtitulo, color: color, accion: accion);
  }

  Widget _tarjetaSalida(Map<String, dynamic> s, ThemeData theme, ColorScheme cs, OhmColors ohm) {
    final index = (s['index'] as num).toInt();
    final alta = s['dadaDeAlta'] == true;
    final nombre = s['nombre']?.toString();
    final tipo = s['tipo']?.toString();
    final modo = s['modo']?.toString();
    return _Tarjeta(
      titulo: alta ? 'Salida $index · $nombre' : 'Salida $index',
      subtitulo: alta ? 'Dada de alta · ${tipo ?? ''} · ${modo == 'pulso' ? 'pulso' : 'encendido/apagado'}' : 'Sin dar de alta',
      color: alta ? ohm.success : null,
      accion: alta
          ? Icon(Icons.check_circle, color: ohm.success)
          : OutlinedButton.icon(onPressed: _listo ? () => _probarSalida(index) : null, icon: const Icon(Icons.power), label: const Text('Encender 5 s')),
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

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700),
      ),
    );
  }
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
