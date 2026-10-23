import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/marcas_camara.dart';
import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../core/error/failures.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/serie_formato.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/wifi/wifi_casa_local.dart';
import '../widgets/movimiento.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import 'conectar_camara_wifi_screen.dart';
import 'conectar_imou_screen.dart';
import 'wifi_casa_screen.dart';
import 'conectar_tuya_wifi_screen.dart';
import 'escanear_serie_screen.dart';
import 'link_energizer_screen.dart';
import 'prueba_energizador_screen.dart';
import '../widgets/aprender_rf_sheet.dart';
import '../widgets/con_textos.dart';
import '../widgets/botones_dialogo.dart';
import '../widgets/hoja_decision.dart';
import '../core/theme/app_motion.dart';

/// «Agregar dispositivos» · cableado con prueba en vivo (build 39, Carlos 2026-10-13).
/// Cada elemento se comprueba físicamente y la app sólo acepta lo que el equipo confirma:
///   · Entradas: «Cierra la puerta» → cerrada estable 3 s → «Ábrela» → abierta → nombre y alta.
///   · Sirena: «Sonar» / «Apagar» las veces que se quiera (se apaga sola a los 15 s); la primera vez la fila
///     pregunta «¿La escuchaste?» (v2 (2026-10-23): antes era una ventana que saltaba sola a los 15 s).
///   · Salidas de 12 V: «Probar» (5 s) → en la fila «¿Encendió?» → si encendió, tipo, modo y registro.
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

  /// Wi‑Fi de la casa de esta visita (sólo en el teléfono, 2026-10-22) y si ya se le pasó al OhmBox.
  WifiCasa? _wifi;
  bool _ohmboxWifiOk = false;
  bool _conectandoOhmboxWifi = false;
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
    _sirenaAutoApagado?.cancel();
    _sirenaCuenta?.cancel();
    super.dispose();
  }

  Future<void> _inicio() async {
    // Ventana de control invisible (2026-10-14): se abre al entrar, se renueva sola mientras la
    // pantalla está abierta y se cierra al salir; el instalador no se queda con control de la cerca.
    await _repo.pruebaAbrir(_id);
    _ventana = Timer.periodic(const Duration(minutes: 1), (_) => Actividad.enSilencio(_renovarVentana));
    // La Wi‑Fi de la casa sale del llavero del teléfono: no detiene la carga de la pantalla.
    unawaited(_cargarWifi());
    await Future.wait([_cargar(), _cargarOhmbox(), _cargarDisp()]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarWifi() async {
    final w = await WifiCasaLocal.instancia.leer(_id);
    if (mounted) setState(() => _wifi = w);
  }

  /// Vuelve al paso «Wi‑Fi de la casa» para capturarla o cambiarla (Carlos, 2026-10-22).
  Future<void> _irWifiCasa() async {
    final antes = _wifi?.red;
    final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => WifiCasaScreen(ticket: widget.ticket)));
    if (!mounted) return;
    await _cargarWifi();
    if (!mounted) return;
    if (r == 'wifi_lista' && _wifi != null && _wifi!.red != antes) _ohmboxWifiOk = false;
    if (r == 'wifi_lista' && _hayEnergizador && !_ohmboxWifiOk) await _ofrecerOhmboxWifi();
  }

  /// Si hay energizador y Wi‑Fi de la casa, ofrece conectarlo como segunda conexión (hoja v2).
  Future<void> _ofrecerOhmboxWifi() async {
    final w = _wifi;
    if (w == null || !mounted) return;
    final si = await mostrarHojaDecision(
      context,
      titulo: '¿Conectar el energizador a «${w.red}»?',
      texto: 'Será su segunda conexión, además de la red celular. Si la red celular falla, el energizador sigue reportando por la Wi‑Fi de la casa.',
      seguir: 'Conectar a la Wi‑Fi',
      salir: 'Ahora no',
    );
    if (si == true) await _conectarOhmboxWifi();
  }

  Future<void> _conectarOhmboxWifi() async {
    final w = _wifi;
    if (w == null || _conectandoOhmboxWifi) return;
    setState(() {
      _conectandoOhmboxWifi = true;
      _fallas.remove('energizador');
    });
    final r = await _repo.ohmboxWifi(_id, red: w.red, contrasena: w.contrasena);
    if (!mounted) return;
    setState(() {
      _conectandoOhmboxWifi = false;
      if (r.isSuccess) _ohmboxWifiOk = true;
      if (r.isFailure) _fallas['energizador'] = (titulo: 'No se conectó el energizador a «${w.red}»', texto: r.failureValue.message);
    });
    if (r.isSuccess) _aviso('Energizador conectado a «${w.red}»');
  }

  /// Lo que falló, junto al grupo donde pasó (v2: nada de errores en el SnackBar). Llave = sección.
  final Map<String, ({String titulo, String texto})> _fallas = {};

  Future<void> _cargar() async {
    final r = await _repo.cableadoEstado(_id);
    if (!mounted) return;
    r.fold(
      (d) => setState(() {
        _e = d;
        _error = null;
      }),
      (f) => setState(() {
        _e = null;
        // Sin energizador no hay cableados ni sirena: no es un error, es una casa sólo Wi‑Fi (2026-10-20).
        _error = f is ServerFailure && (f.code == 'EQUIPO_NO_VINCULADO' || f.code == 'SIN_ENERGIZADOR') ? null : f.message;
      }),
    );
    _ajustarSondeo();
  }

  /// ¿La casa ya tiene energizador vinculado? Lo dice el backend (`energizador` en /dispositivos) o la
  /// lista de energizadores de la casa. Sin él, sólo sensores Wi‑Fi y cámaras (energizador opcional).
  bool get _hayEnergizador => _disp?['energizador'] != null || _energizadores.isNotEmpty;

  /// «Vincular energizador» (2026-10-20): el primero de la casa, opcional, desde aquí. Al vincular se
  /// abre su prueba y al volver se recarga todo (el ancla pasa de la central al energizador).
  Future<void> _vincularEnergizador() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => LinkEnergizerScreen(ticket: widget.ticket)));
    if (!mounted) return;
    if (result == 'device_linked') await _probarEnergizador();
    if (mounted) await _recargarTodo();
    // Con la Wi‑Fi de la casa ya capturada, el OhmBox recién vinculado puede usarla de segunda conexión.
    if (mounted && result == 'device_linked' && _wifi != null && !_ohmboxWifiOk) await _ofrecerOhmboxWifi();
  }

  /// La prueba del energizador (encender/apagar la cerca frente al cliente) vive aquí (2026-10-20).
  Future<void> _probarEnergizador() async {
    _ventana?.cancel();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PruebaEnergizadorScreen(ticket: widget.ticket)));
    if (!mounted) return;
    // La prueba cierra su ventana al salir: se vuelve a abrir la de esta pantalla.
    await _repo.pruebaAbrir(_id);
    _ventana = Timer.periodic(const Duration(minutes: 1), (_) => Actividad.enSilencio(_renovarVentana));
    await _recargarTodo();
  }

  Future<void> _recargarTodo() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    await Future.wait([_cargar(), _cargarOhmbox(), _cargarDisp()]);
    if (mounted) setState(() => _cargando = false);
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

  /// «Listo, volver a los pasos»: cierra la ventana de control y marca el paso como hecho.
  Future<void> _salir() async {
    if (_saliendo) return;
    setState(() => _saliendo = true);
    _ventana?.cancel();
    _sondeo?.cancel();
    _sirenaAutoApagado?.cancel();
    // Si sale con la sirena sonando, se apaga antes de cerrar la ventana de control.
    if (_sirenaSonando) await _repo.cableadoSirena(_id, encender: false);
    await _repo.pruebaTerminar(_id);
    if (mounted) Navigator.pop(context, 'dispositivos_listos');
  }

  /// Atrás (flecha o el del teléfono): sale al instante SIN marcar el paso como hecho (auditoría
  /// 2026-10-23: antes regresar lo daba por listo y tardaba dos llamadas de red). La sirena y la
  /// ventana de control se cierran en segundo plano.
  void _regresar() {
    if (_saliendo) return;
    _saliendo = true;
    _ventana?.cancel();
    _sondeo?.cancel();
    _sirenaAutoApagado?.cancel();
    final repo = _repo;
    final id = _id;
    final sonando = _sirenaSonando;
    unawaited(() async {
      if (sonando) await repo.cableadoSirena(id, encender: false);
      await repo.pruebaTerminar(id);
    }());
    Navigator.pop(context);
  }

  /// Error al leer los dispositivos de la casa (p. ej. la casa no se pudo resolver): antes se callaba y
  /// la pantalla se quedaba sin filas de Wi‑Fi ni cámaras sin decir por qué (build 54, i75).
  String? _errorDisp;

  Future<void> _cargarDisp() async {
    final r = await _repo.dispositivosEstado(_id);
    if (!mounted) return;
    r.fold(
      (d) => setState(() {
        _disp = d;
        _errorDisp = null;
      }),
      (f) => setState(() => _errorDisp = f.message),
    );
  }

  Map<String, dynamic> _sec(String k) => (_disp?[k] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> _lista(String k, String campo) =>
      ((_sec(k)[campo] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  bool get _rfSoportado => _sec('rf')['soportado'] != false;
  bool get _camarasOn => _sec('camaras')['habilitadas'] == true;
  Map<String, dynamic> get _proveedores => (_sec('camaras')['proveedores'] as Map?)?.cast<String, dynamic>() ?? const {};
  // 2026-10-20 (Carlos): la app sólo ofrece Tuya; EZVIZ e Imou quedan apagadas detrás de MarcasCamara.
  bool get _hayProveedor => _camarasOn && ((MarcasCamara.ezviz && _proveedores['ezviz'] == true) || (MarcasCamara.imou && _proveedores['imou'] == true));

  /// Qué se puede emparejar a la Wi‑Fi desde este teléfono (2026-10-17): lo dice el backend según
  /// lo que tenga encendido en el ambiente (`wifi.emparejar`).
  bool get _emparejarEzviz => MarcasCamara.ezviz && (_sec('wifi')['emparejar'] as Map?)?['ezviz'] == true;
  bool get _emparejarTuya => MarcasCamara.tuya && (_sec('wifi')['emparejar'] as Map?)?['tuya'] == true;

  /// Sensor o cámara Tuya nueva: el teléfono le pasa la Wi‑Fi con el permiso de la casa (2026-10-17).
  Future<void> _conectarTuya(String clase) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConectarTuyaWifiScreen(ordenId: _id, clase: clase),
      ),
    );
    if (ok == true && mounted) await _cargarDisp();
  }

  static const _tipoRfTexto = {'door': 'Puerta', 'pir': 'Movimiento', 'smoke': 'Humo', 'panic_button': 'Botón de pánico', 'fob': 'Control remoto'};

  /// Sensores Wi‑Fi apagados por ahora (Carlos, 2026-10-15: «no borres, pero por ahora deshabilita
  /// la opción»). El código queda completo; para volver a ofrecerlos basta poner `true`. Si una casa ya
  /// tiene sensores Wi‑Fi, se siguen listando, sólo no se pueden agregar nuevos.
  static const _wifiHabilitado = false;

  static const _tipoWifiTexto = {'door': 'Puerta', 'motion': 'Movimiento', 'smoke': 'Humo'};
  // Las salidas son de 12 V (Carlos, 2026-10-20): estrobo, sirena extra u otro de 12 V. Los tipos
  // viejos (luz, bomba, portón) sólo se muestran si ya estaban registrados.
  static const _tipoSalidaTexto = {'estrobo': 'estrobo', 'sirena': 'sirena extra', 'otro': 'otro de 12 V', 'luz': 'luz', 'bomba': 'bomba', 'porton': 'portón'};

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  // ---------------------------------------------------------------- sensores inalámbricos
  Future<void> _agregarRf() async {
    final tipo = await showModalBottomSheet<({String id, String etiqueta, IconData icono})>(
      context: context,
      showDragHandle: true,
      // En teléfonos chicos la hoja se desplaza en vez de desbordarse.
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text('¿Qué sensor vas a agregar?', style: Theme.of(ctx).textTheme.headlineSmall),
              ),
              // v2 (2026-10-23): los tipos en un solo grupo, como una lista de Ajustes.
              GrupoFilas(
                children: [
                  for (final t in tiposRf)
                    FilaFlujo(
                      leading: Icon(t.icono, color: Theme.of(ctx).colorScheme.primary),
                      titulo: t.etiqueta,
                      trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (tipo == null || !mounted) return;
    final nombre = await aprenderSensorRf(context, ordenId: _id, tipo: tipo.id, etiqueta: tipo.etiqueta);
    if (!mounted) return;
    if (nombre != null) _aviso(tipo.id == 'fob' ? 'Control «$nombre» guardado' : 'Sensor «$nombre» guardado');
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
              // Con el teclado abierto el contenido se desplaza en vez de desbordarse (franja amarilla).
              scrollable: true,
              title: const Text('Sensor Wi‑Fi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Escribe el ID del sensor. El cliente termina de conectarlo desde su app.', style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // se ajusta al ancho del diálogo
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [for (final e in _tipoWifiTexto.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => set(() => tipo = v ?? 'door'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c[0],
                    decoration: const InputDecoration(
                      labelText: 'ID del sensor',
                      helperText: 'Viene en la etiqueta o en la app del sensor.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c[1],
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Ventana de la sala'),
                  ),
                ],
              ),
              actions: [
                BotonesDialogo(
                  secundario: 'Cerrar',
                  onSecundario: () => Navigator.pop(ctx),
                  primario: 'Guardar sensor',
                  onPrimario: () {
                    final id = c[0].text.trim(), nombre = c[1].text.trim();
                    if (id.isNotEmpty && nombre.isNotEmpty) Navigator.pop(ctx, (id: id, nombre: nombre, tipo: tipo));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    if (datos == null || !mounted) return;
    setState(() {
      _ocupado = true;
      _fallas.remove('wifi');
    });
    final r = await _repo.sensorWifiAgregar(_id, externalId: datos.id, nombre: datos.nombre, tipo: datos.tipo);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold(
      (_) => _aviso('Sensor Wi‑Fi «${datos.nombre}» guardado'),
      (f) => setState(() => _fallas['wifi'] = (titulo: 'No se guardó el sensor «${datos.nombre}»', texto: f.message)),
    );
    await _cargarDisp();
  }

  // ---------------------------------------------------------------- Cámaras
  /// Cámara nueva (proveedor apagado hoy): el teléfono le pasa la Wi‑Fi de la casa y la registra (2026-10-17).
  Future<void> _conectarCamaraWifi() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ConectarCamaraWifiScreen(ordenId: _id)));
    if (ok == true && mounted) await _cargarDisp();
  }

  /// Cámara con serie (2026-10-19, Carlos; proveedor apagado hoy): pantalla completa con escaneo del QR
  /// de la guía (serie + código), sin diálogos que el teclado tape.
  Future<void> _conectarImou() => _abrirRegistroCamara(proveedor: 'imou');

  /// «Cámara ya conectada»: misma pantalla sin marca; el backend prueba cada nube habilitada.
  Future<void> _agregarCamara() => _abrirRegistroCamara();

  Future<void> _abrirRegistroCamara({String? proveedor}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConectarImouScreen(ordenId: _id, proveedor: proveedor),
      ),
    );
    if (ok == true && mounted) await _cargarDisp();
  }

  Future<void> _cargarOhmbox() async {
    final r = await _repo.ohmboxEstado(_id);
    if (!mounted) return;
    r.fold((d) => setState(() => _ohmbox = d), (_) {});
  }

  List<Map<String, dynamic>> get _energizadores =>
      ((_ohmbox?['energizadores'] as List?) ?? const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
  String get _casaNombre => ((_ohmbox?['casa'] as Map?)?['nombre'] ?? 'la casa').toString();

  /// OhmBox adicional (2026-10-14): un segundo energizador en la misma casa es un complemento
  /// de su suscripción, nunca un paquete nuevo. Va siempre a la casa del energizador principal.
  Future<void> _agregarOhmbox() async {
    final serie = await _pedirSerie();
    if (serie == null || !mounted) return;
    setState(() {
      _ocupado = true;
      _fallas.remove('energizador');
    });
    final r = await _repo.ohmboxAgregar(_id, serie: serie);
    if (!mounted) return;
    setState(() => _ocupado = false);
    r.fold((d) {
      setState(() => _ohmbox = d);
      _aviso('Energizador $serie agregado a «$_casaNombre»');
    }, (f) => setState(() => _fallas['energizador'] = (titulo: 'No se agregó el energizador $serie', texto: f.message)));
  }

  Future<String?> _pedirSerie() {
    return showDialog<String>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const [''],
        builder: (ctx, c) => AlertDialog(
          // Con el teclado abierto el contenido se desplaza en vez de desbordarse (franja amarilla).
          scrollable: true,
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
                    icon: const Icon(Icons.qr_code_scanner_rounded),
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
            BotonesDialogo(
              secundario: 'Cerrar',
              onSecundario: () => Navigator.pop(ctx),
              primario: 'Agregar energizador',
              onPrimario: () {
                final s = normalizarSerie(c[0].text);
                if (s.isNotEmpty) Navigator.pop(ctx, s);
              },
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

  /// Corre una acción del cableado. Si falla, el error se queda junto al grupo de [seccion] con
  /// [tituloFalla] (v2: antes salía en un SnackBar). Devuelve si salió bien.
  Future<bool> _run(Future<dynamic> Function() op, {required String seccion, required String tituloFalla}) async {
    if (_ocupado) return false;
    setState(() {
      _ocupado = true;
      _fallas.remove(seccion);
    });
    final r = await op();
    if (!mounted) return false;
    var ok = false;
    // ignore: avoid_dynamic_calls
    r.fold(
      (d) => setState(() {
        _e = (d as Map).cast<String, dynamic>();
        _error = null;
        ok = true;
      }),
      (f) => setState(() => _fallas[seccion] = (titulo: tituloFalla, texto: (f as Failure).message)),
    );
    setState(() => _ocupado = false);
    _ajustarSondeo();
    return ok;
  }

  // ---------------------------------------------------------------- entradas
  Future<void> _probarEntrada(int index) =>
      _run(() => _repo.cableadoProbarEntrada(_id, index), seccion: 'entradas', tituloFalla: 'No se pudo probar la entrada $index');

  Future<void> _registrarEntrada(int index, String nombreActual) async {
    final nombre = await _pedirNombre('¿Qué puerta es?', nombreActual.startsWith('Entrada ') ? '' : nombreActual, ejemplo: 'Ej. Puerta principal');
    if (nombre == null || !mounted) return;
    await _run(
      () => _repo.cableadoRegistrarEntrada(_id, index, nombre: nombre),
      seccion: 'entradas',
      tituloFalla: 'No se guardó la entrada $index',
    );
  }

  // ---------------------------------------------------------------- sirena
  /// Sirena de demostración (Carlos, 2026-10-20): el instalador la enciende y la apaga cuantas veces
  /// quiera frente al cliente; encendida se apaga sola a los 15 s. La primera vez la fila pregunta
  /// «¿La escuchaste?» (eso deja el acta y la palomita); después se puede seguir mostrando.
  /// v2 (2026-10-23): la pregunta vive en la fila, con la cuenta regresiva, en vez de una ventana que
  /// saltaba sola a los 15 s.
  bool _sirenaSonando = false;
  Timer? _sirenaAutoApagado;

  /// Ya sonó al menos una vez y falta contestar si se escuchó.
  bool _sirenaPorConfirmar = false;
  DateTime? _sirenaHasta;
  Timer? _sirenaCuenta;

  static const _sirenaDura = Duration(seconds: 15);

  bool get _preguntarSirena => _sirena['sono'] == null && (_sirenaSonando || _sirenaPorConfirmar);

  Future<void> _encenderSirena() async {
    await _run(() => _repo.cableadoSirena(_id, encender: true), seccion: 'sirena', tituloFalla: 'No sonó la sirena');
    if (!mounted || _sirena['sonando'] != true) return;
    setState(() {
      _sirenaSonando = true;
      _sirenaPorConfirmar = true;
      _sirenaHasta = DateTime.now().add(_sirenaDura);
    });
    _sirenaAutoApagado?.cancel();
    _sirenaCuenta?.cancel();
    // La cuenta regresiva de la fila («se apaga en 0:12»).
    _sirenaCuenta = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // El servidor la apaga a los 15 s; la fila vuelve sola a «Sonar».
    _sirenaAutoApagado = Timer(_sirenaDura, () {
      _sirenaCuenta?.cancel();
      if (mounted && _sirenaSonando) setState(() => _sirenaSonando = false);
    });
  }

  Future<void> _apagarSirena() async {
    _sirenaAutoApagado?.cancel();
    _sirenaCuenta?.cancel();
    await _run(() => _repo.cableadoSirena(_id, encender: false), seccion: 'sirena', tituloFalla: 'No se apagó la sirena');
    if (!mounted) return;
    setState(() => _sirenaSonando = false);
  }

  /// Lo que se guarda al contestar es lo mismo que antes guardaba la ventana «¿Sonó?».
  Future<void> _contestarSirena(bool sono) async {
    final ok = await _run(
      () => _repo.cableadoConfirmarSirena(_id, sono: sono),
      seccion: 'sirena',
      tituloFalla: 'No se guardó tu respuesta',
    );
    if (ok && mounted) setState(() => _sirenaPorConfirmar = false);
  }

  String get _sirenaRestante {
    final hasta = _sirenaHasta;
    if (hasta == null) return '';
    final s = hasta.difference(DateTime.now()).inSeconds.clamp(0, _sirenaDura.inSeconds);
    return '0:${s.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------- salidas
  /// Salidas que ya se encendieron 5 s y esperan la respuesta «¿Encendió?» en su fila (v2, 2026-10-23:
  /// antes «¿Se encendió? Sí/No» → formulario → «No se guardó» en ventanas encadenadas).
  final Set<int> _salidaPorConfirmar = {};

  /// Salidas que el instalador dijo que no encendieron (queda en el reporte; se pueden volver a probar).
  final Set<int> _salidaNoEncendio = {};

  Future<void> _probarSalida(int index) async {
    setState(() => _salidaNoEncendio.remove(index));
    await _run(() => _repo.cableadoProbarSalida(_id, index), seccion: 'salidas', tituloFalla: 'No se pudo probar la salida $index');
    if (!mounted) return;
    final fila = _salidas.firstWhere((s) => s['index'] == index, orElse: () => const {});
    if (fila['probada'] != true) return;
    setState(() => _salidaPorConfirmar.add(index));
  }

  /// El formulario se abre sólo si encendió. Si no, se anota igual que antes (`funciono: false`).
  Future<void> _contestarSalida(int index, {required bool encendio}) async {
    if (!encendio) {
      final ok = await _run(
        () => _repo.cableadoRegistrarSalida(_id, index, nombre: 'Salida $index', tipo: 'otro', modo: 'on_off', funciono: false),
        seccion: 'salidas',
        tituloFalla: 'No se guardó tu respuesta',
      );
      if (ok && mounted) {
        setState(() {
          _salidaPorConfirmar.remove(index);
          _salidaNoEncendio.add(index);
        });
      }
      return;
    }
    final alta = await _formSalida(index);
    if (alta == null || !mounted) return;
    final ok = await _run(
      () => _repo.cableadoRegistrarSalida(
        _id,
        index,
        nombre: alta.nombre,
        tipo: alta.tipo,
        modo: alta.modo,
        pulsoSeg: alta.modo == 'pulso' ? alta.pulsoSeg : null,
        funciono: true,
      ),
      seccion: 'salidas',
      tituloFalla: 'No se guardó la salida $index',
    );
    if (ok && mounted) setState(() => _salidaPorConfirmar.remove(index));
  }

  // ---------------------------------------------------------------- diálogos
  Future<String?> _pedirNombre(String titulo, String inicial, {required String ejemplo}) async {
    final r = await showDialog<String>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: [inicial],
        builder: (ctx, c) => AlertDialog(
          // Con el teclado abierto el contenido se desplaza en vez de desbordarse (franja amarilla).
          scrollable: true,
          title: Text(titulo),
          content: TextField(
            controller: c[0],
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: ejemplo, border: const OutlineInputBorder()),
          ),
          actions: [
            BotonesDialogo(
              secundario: 'Cerrar',
              onSecundario: () => Navigator.pop(ctx),
              primario: 'Guardar sensor',
              onPrimario: () => Navigator.pop(ctx, c[0].text.trim()),
            ),
          ],
        ),
      ),
    );
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<_AltaSalida?> _formSalida(int index) {
    // Tipo y modo fuera del builder: sobreviven a que el diálogo se reconstruya (teclado).
    var tipo = 'estrobo';
    var modo = 'on_off';
    return showDialog<_AltaSalida>(
      context: context,
      builder: (_) => ConTextos(
        iniciales: const [''],
        builder: (ctx, c) {
          return StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              // Con el teclado abierto el contenido se desplaza en vez de desbordarse (franja amarilla).
              scrollable: true,
              title: Text('¿Qué conectaste a la salida $index?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: c[0],
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Estrobo de la entrada', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // se ajusta al ancho del diálogo
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: '¿Qué es? (12 V)', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'estrobo', child: Text('Estrobo')),
                      DropdownMenuItem(value: 'sirena', child: Text('Sirena extra')),
                      DropdownMenuItem(value: 'otro', child: Text('Otro equipo de 12 V')),
                    ],
                    onChanged: (v) => setLocal(() => tipo = v ?? 'otro'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // se ajusta al ancho del diálogo
                    initialValue: modo,
                    decoration: const InputDecoration(labelText: '¿Cómo funciona?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'on_off', child: Text('Encendido / apagado')),
                      DropdownMenuItem(value: 'pulso', child: Text('Pulso (un toque corto)')),
                    ],
                    onChanged: (v) => setLocal(() => modo = v ?? 'on_off'),
                  ),
                ],
              ),
              actions: [
                BotonesDialogo(
                  secundario: 'Cerrar',
                  onSecundario: () => Navigator.pop(ctx),
                  primario: 'Guardar salida',
                  onPrimario: () {
                    final nombre = c[0].text.trim();
                    if (nombre.isNotEmpty) Navigator.pop(ctx, _AltaSalida(nombre, tipo, modo, 2));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- UI
  // v2 (2026-10-23): un grupo blanco por sección (lista agrupada), estados con punto de color y lo que
  // pasa (preguntas, esperas, errores) dentro de la fila o junto a su grupo.

  // Regla de Carlos (2026-10-14, repetida 2026-10-20): la app no muestra marcas; todo es «Wi‑Fi».
  String _marca(Object? proveedor) => 'Wi‑Fi';

  /// Las secciones entran escalonadas (movimiento de GO, 2026-10-20).
  List<Widget> _conEntrada(List<Widget> hijos) => [for (final (i, w) in hijos.indexed) EntradaSuave(index: i, child: w)];

  /// «Casa Carlos · instalación i76», con lo que se sepa.
  String get _subtitulo {
    final casa = (_ohmbox?['casa'] as Map?)?['nombre']?.toString();
    return [if (casa != null && casa.isNotEmpty) casa, if (_id.isNotEmpty) 'instalación $_id'].join(' · ');
  }

  /// Error de una sección, junto a su grupo.
  Widget? _falla(String seccion) {
    final f = _fallas[seccion];
    if (f == null) return null;
    return MensajeFlujo(icono: Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, titulo: f.titulo, texto: f.texto);
  }

  /// Resumen de arriba: cuántos dispositivos hay y qué falta probar, con lo que la pantalla ya leyó.
  Widget? _resumen(ColorScheme cs, OhmColors ohm) {
    if (_e == null && _disp == null && _ohmbox == null) return null;
    final entradasOk = _entradas.where((x) => x['dadaDeAlta'] == true).length;
    final salidasOk = _salidas.where((x) => x['dadaDeAlta'] == true).length;
    final camaras = _lista('camaras', 'lista');
    final total =
        _energizadores.length +
        entradasOk +
        salidasOk +
        (_sirena['sono'] == true ? 1 : 0) +
        _lista('rf', 'dispositivos').length +
        _lista('wifi', 'sensores').length +
        camaras.length;
    final falta = <String>[
      for (final x in _energizadores)
        if (x['enLinea'] != true) 'el energizador ${x['serie'] ?? ''} no tiene señal',
      for (final x in _entradas)
        if (x['dadaDeAlta'] != true && (x['prueba'] as Map?)?['fase'] == 'verificada') 'falta guardar la entrada ${x['index']}',
      if (_hayEnergizador && _e != null && _firmwareOk && _sirena['sono'] == null) 'falta probar la sirena',
      if (_sirena['sono'] == false) 'la sirena no sonó',
      for (final i in _salidaPorConfirmar) 'falta contestar si encendió la salida $i',
      for (final x in camaras)
        if (x['estado'] != 'online') 'la cámara «${x['nombre'] ?? ''}» no responde',
    ];
    final cuantos = total == 1 ? '1 dispositivo' : '$total dispositivos';
    final (IconData icono, Color color, String titulo, String texto) = total == 0 && falta.isEmpty
        ? (
            Icons.add_circle_outline_rounded,
            cs.onSurfaceVariant,
            'Todavía no hay dispositivos',
            'Agrega sólo lo que el cliente compró. Cada cosa se prueba en vivo y sólo se guarda si funciona.',
          )
        : falta.isEmpty
        ? (Icons.check_circle_rounded, ohm.success, '$cuantos, todo en orden', 'Agrega sólo lo que el cliente compró; cada cosa se prueba en vivo.')
        : (Icons.error_outline_rounded, ohm.warning, cuantos, '${falta.first[0].toUpperCase()}${falta.join(' · ').substring(1)}.');
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: TarjetaFlujo(
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Row(
            children: [
              Icon(icono, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final apoyo = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final neutro = cs.onSurfaceVariant;
    final resumen = _cargando ? null : _resumen(cs, ohm);
    // Cualquier salida (botón, gesto o atrás del sistema) cierra la ventana de control.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _regresar();
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
                  EncabezadoFlujo(titulo: 'Agregar dispositivos', subtitulo: _subtitulo, alVolver: _regresar),
                  Expanded(
                    child: _cargando
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: GrupoFilas(
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: neutro)),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text('Leyendo los dispositivos de la casa…', style: apoyo)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            physics: const BouncingScrollPhysics(),
                            children: _conEntrada([
                              if (_error != null)
                                MensajeFlujo(
                                  icono: Icons.error_outline_rounded,
                                  color: cs.error,
                                  titulo: 'No pudimos leer el energizador',
                                  texto: _error!,
                                  accion: BotonFila(etiqueta: 'Volver a intentar', icono: Icons.refresh_rounded, onPressed: _ocupado ? null : _recargarTodo),
                                ),
                              if (_disp == null && _errorDisp != null)
                                MensajeFlujo(
                                  icono: Icons.error_outline_rounded,
                                  color: cs.error,
                                  titulo: 'No pudimos leer los dispositivos de la casa',
                                  texto: 'Sin esa lista no puedes agregar sensores Wi‑Fi ni cámaras. Sal y vuelve a entrar; si sigue, avisa a soporte.',
                                ),
                              if (_e != null && !_firmwareOk)
                                MensajeFlujo(
                                  icono: Icons.system_update_alt_rounded,
                                  color: ohm.warning,
                                  titulo: 'Este energizador necesita actualizarse',
                                  texto:
                                      'Los sensores cableados, la sirena y las salidas piden la versión ${_equipo['firmwareMinimo'] ?? '2.10'} o más nueva. Lo demás sí lo puedes agregar.',
                                ),
                              if (_e != null && _firmwareOk && !_enLinea)
                                MensajeFlujo(
                                  icono: Icons.wifi_off_rounded,
                                  color: cs.error,
                                  titulo: 'El energizador no tiene señal',
                                  texto: 'Revisa que esté conectado a la corriente y con señal. Sin ella no puedes probar cableados, sirena ni salidas.',
                                ),
                              ?resumen,

                              // ---------------- Wi‑Fi de la casa (2026-10-22): se puede volver al paso desde aquí.
                              const EtiquetaSeccion(
                                'Wi‑Fi de la casa',
                                ayuda: [
                                  'La red que capturaste en el paso «Wi‑Fi de la casa». La usan los sensores y cámaras Wi‑Fi y el energizador como segunda conexión.',
                                  'La contraseña se queda sólo en este teléfono y se borra al terminar la instalación.',
                                ],
                              ),
                              // Zona de estado (propuesta A del lienzo, Carlos 2026-10-23): aquí es opcional, gris y no rojo.
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ZonaEstado(
                                  estado: _wifi != null ? EstadoZona.enOrden : EstadoZona.opcional,
                                  titulo: 'Wi‑Fi de la casa',
                                  detalle: _wifi != null
                                      ? '«${_wifi!.red}» · la usan los sensores y cámaras Wi‑Fi y el energizador.'
                                      : 'Agrégala si vas a instalar sensores o cámaras Wi‑Fi, o para el energizador.',
                                  accionEtiqueta: _wifi != null ? 'Cambiar red' : 'Agregar Wi‑Fi de la casa',
                                  accionIcono: Icons.wifi_rounded,
                                  alAccion: _ocupado ? null : _irWifiCasa,
                                ),
                              ),

                              // ---------------- Energizador: opcional desde la build 54 (Carlos, 2026-10-20).
                              EtiquetaSeccion(
                                'Energizador',
                                ayuda: [
                                  'Una casa puede llevar energizador o no: sin él se instalan sensores Wi‑Fi y cámaras.',
                                  'Con energizador se pueden agregar además sensores cableados, sirena, salidas y sensores inalámbricos.',
                                  if (_hayEnergizador)
                                    'Prueba la cerca frente al cliente con «Probar»; un segundo energizador en la misma casa se suma como complemento de su suscripción.',
                                  if (!_hayEnergizador) 'Si el cliente compró energizador, toca «Vincular»: se escanea su QR y luego se prueba la cerca.',
                                ],
                              ),
                              GrupoFilas(
                                pie: _hayEnergizador ? 'Un segundo energizador se suma como complemento de la suscripción.' : null,
                                children: [
                                  for (final x in _energizadores)
                                    _Fila(
                                      icono: Icons.bolt_rounded,
                                      tono: x['enLinea'] == true ? _Tono.naranja : _Tono.gris,
                                      titulo: (x['serie'] ?? '').toString(),
                                      estado: EstadoPunto(
                                        [x['enLinea'] == true ? 'En línea' : 'Sin señal', if (x['principal'] == true) 'principal'].join(' · '),
                                        color: x['enLinea'] == true ? ohm.success : cs.error,
                                      ),
                                    ),
                                  if (!_hayEnergizador)
                                    _Fila(
                                      icono: Icons.qr_code_scanner_rounded,
                                      titulo: 'Vincular energizador',
                                      estado: Text('Opcional · escanea su QR y vincúlalo a la casa', style: apoyo),
                                      trailing: BotonFila(etiqueta: 'Vincular', onPressed: _ocupado ? null : _vincularEnergizador),
                                    )
                                  else ...[
                                    _Fila(
                                      icono: Icons.power_settings_new_rounded,
                                      titulo: 'Prueba del energizador',
                                      estado: Text('Enciende y apaga la cerca frente al cliente', style: apoyo),
                                      trailing: BotonFila(etiqueta: 'Probar', onPressed: _ocupado ? null : _probarEnergizador),
                                    ),
                                    _filaSegundaConexion(apoyo, ohm),
                                    _FilaAgregar(texto: 'Agregar otro energizador', onTap: _ocupado || _ohmbox == null ? null : _agregarOhmbox),
                                  ],
                                ],
                              ),
                              ?_falla('energizador'),

                              // ---------------- Con energizador: cableados, sirena, salidas y sensores inalámbricos.
                              if (_hayEnergizador) ...[
                                if (_entradas.isNotEmpty) ...[
                                  const EtiquetaSeccion(
                                    'Sensores cableados',
                                    ayuda: [
                                      'Sensores de puerta conectados con cable a las entradas del energizador.',
                                      'Toca «Probar», cierra la puerta y espera; luego ábrela.',
                                      'Cuando el equipo ve las dos cosas, le pones nombre y se guarda.',
                                    ],
                                  ),
                                  GrupoFilas(children: [for (final x in _entradas) _filaEntrada(x, apoyo, cs, ohm)]),
                                  ?_falla('entradas'),
                                ],

                                // ---------------- Sirena
                                const EtiquetaSeccion(
                                  'Sirena',
                                  ayuda: [
                                    'Hazla sonar y apágala las veces que quieras para mostrársela al cliente. Avísale antes: es fuerte.',
                                    'Si la dejas sonando, se apaga sola a los 15 segundos.',
                                    'La primera vez, la fila te pregunta si la escuchaste (queda en el acta).',
                                  ],
                                ),
                                GrupoFilas(children: [_filaSirena(apoyo, cs, ohm)]),
                                ?_falla('sirena'),

                                // ---------------- Salidas
                                if (_salidas.isNotEmpty) ...[
                                  const EtiquetaSeccion(
                                    'Salidas de 12 V',
                                    ayuda: [
                                      'Son salidas de 12 V del energizador para un estrobo o una sirena extra.',
                                      'Al probarla se enciende 5 segundos.',
                                      'Si encendió, le pones nombre y eliges qué es.',
                                    ],
                                  ),
                                  GrupoFilas(children: [for (final x in _salidas) _filaSalida(x, apoyo, cs, ohm)]),
                                  ?_falla('salidas'),
                                ],

                                // ---------------- Sensores inalámbricos
                                const EtiquetaSeccion(
                                  'Sensores inalámbricos',
                                  ayuda: [
                                    'Puerta, movimiento, humo, botón de pánico o control remoto que se vinculan al energizador sin cables.',
                                    'El energizador los aprende en vivo: la app te dice qué hacer con el sensor.',
                                    'El energizador debe tener señal.',
                                  ],
                                ),
                                GrupoFilas(
                                  children: [
                                    for (final x in _lista('rf', 'dispositivos'))
                                      _Fila(
                                        icono: x['tipo'] == 'fob' ? Icons.settings_remote_rounded : Icons.sensors_rounded,
                                        titulo: (x['nombre'] ?? '').toString(),
                                        estado: EstadoPunto(_tipoRfTexto[x['tipo']] ?? 'Sensor inalámbrico', color: ohm.success),
                                      ),
                                    _FilaAgregar(
                                      texto: 'Agregar sensor o control',
                                      nota: !_rfSoportado
                                          ? 'Este energizador no los maneja'
                                          : (_enLinea ? null : 'El energizador necesita señal para aprenderlo'),
                                      onTap: _ocupado || _disp == null || !_rfSoportado || !_enLinea ? null : _agregarRf,
                                    ),
                                  ],
                                ),
                              ], // fin: con energizador
                              // ---------------- Sensores Wi‑Fi (apagados por ahora: ver _wifiHabilitado)
                              if (_wifiHabilitado || _emparejarTuya || _lista('wifi', 'sensores').isNotEmpty) ...[
                                const EtiquetaSeccion(
                                  'Sensores Wi‑Fi',
                                  ayuda: [
                                    'Se conectan al internet de la casa, no al energizador.',
                                    'Aquí registras su ID; el cliente termina de conectarlo desde su app.',
                                    'El ID viene en la etiqueta o en la app del sensor.',
                                  ],
                                ),
                                GrupoFilas(
                                  children: [
                                    // En el orden en que se registraron (el servidor los manda así), numerados.
                                    for (final (i, x) in _lista('wifi', 'sensores').indexed)
                                      _Fila(
                                        icono: Icons.sensors_rounded,
                                        titulo: '${i + 1}. ${x['nombre'] ?? ''}',
                                        estado: Text(
                                          '${_tipoWifiTexto[x['tipo']] ?? 'Sensor'} · ${_marca(x['proveedor'])} · ID ${x['externalId'] ?? ''}',
                                          style: apoyo,
                                        ),
                                      ),
                                    if (_emparejarTuya) _FilaAgregar(texto: 'Conectar sensor Wi‑Fi', onTap: _ocupado ? null : () => _conectarTuya('sensor')),
                                    if (_wifiHabilitado) _FilaAgregar(texto: 'Registrar sensor Wi‑Fi', onTap: _ocupado || _disp == null ? null : _agregarWifi),
                                  ],
                                ),
                                ?_falla('wifi'),
                              ],

                              // ---------------- Cámaras
                              EtiquetaSeccion(
                                'Cámaras',
                                ayuda: [
                                  if (MarcasCamara.tuya)
                                    'Cámara nueva: «Conectar cámara Wi‑Fi». El teléfono le pasa la red de la casa y la registra; la contraseña se escribe aquí y no se guarda.',
                                  if (MarcasCamara.ezviz)
                                    'Cámara nueva: «Conectar cámara a la Wi‑Fi». El teléfono le pasa la red de la casa y la registra; la contraseña se escribe aquí y no se guarda.',
                                  if (MarcasCamara.imou)
                                    'Cámara con serie: «Conectar cámara con su serie». Se registra con la serie y el código de su etiqueta.',
                                  if (MarcasCamara.registroPorSerie)
                                    'Cámara que ya está en internet (conectada con su app de origen): «Registrar cámara ya conectada», con la serie y el código de su etiqueta.',
                                  'Al guardarla, el cliente la ve en su app.',
                                ],
                              ),
                              GrupoFilas(
                                pie: 'Se conectan a la Wi‑Fi de la casa; el cliente las ve en su app.',
                                children: [
                                  // En el orden en que se registraron, sin importar el proveedor; numeradas.
                                  for (final (i, x) in _lista('camaras', 'lista').indexed) _filaCamara(i, x, ohm, cs),
                                  if (_emparejarEzviz) _FilaAgregar(texto: 'Conectar cámara a la Wi‑Fi', onTap: _ocupado ? null : _conectarCamaraWifi),
                                  if (_emparejarTuya) _FilaAgregar(texto: 'Conectar cámara Wi‑Fi', onTap: _ocupado ? null : () => _conectarTuya('camara')),
                                  if (MarcasCamara.imou && _camarasOn && _proveedores['imou'] == true)
                                    _FilaAgregar(texto: 'Conectar cámara con su serie', onTap: _ocupado ? null : _conectarImou),
                                  // Sólo con los otros proveedores encendidos: las de hoy se registran al conectarlas.
                                  if (MarcasCamara.registroPorSerie)
                                    _FilaAgregar(
                                      texto: 'Registrar cámara ya conectada',
                                      nota: _hayProveedor ? null : 'No disponible por ahora',
                                      onTap: _ocupado || !_hayProveedor ? null : _agregarCamara,
                                    ),
                                  if (_lista('camaras', 'lista').isEmpty && !_emparejarEzviz && !_emparejarTuya && !MarcasCamara.registroPorSerie)
                                    _Fila(
                                      icono: Icons.videocam_off_rounded,
                                      titulo: 'Sin cámaras',
                                      estado: Text('Conectar cámaras no está disponible en esta casa por ahora.', style: apoyo),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 4),
                              OhmGradientButton(
                                label: 'Listo, volver a los pasos',
                                loading: _saliendo,
                                loadingLabel: 'Cerrando las pruebas…',
                                onPressed: _ocupado ? null : _salir,
                              ),
                            ]),
                          ),
                  ),
                ],
              ),
            ),
            // La barra es un Positioned: va sobre el Stack, no dentro de la columna.
          ],
        ),
      ),
    );
  }

  /// Segunda conexión del energizador por la Wi‑Fi de la casa, como una fila más del grupo.
  Widget _filaSegundaConexion(TextStyle? apoyo, OhmColors ohm) {
    final red = _wifi?.red;
    if (_ohmboxWifiOk) {
      return _Fila(
        icono: Icons.router_rounded,
        titulo: 'Segunda conexión',
        estado: EstadoPunto('Wi‑Fi «${red ?? ''}», además de la red celular', color: ohm.success),
      );
    }
    if (_conectandoOhmboxWifi) {
      return _Fila(icono: Icons.router_rounded, titulo: 'Segunda conexión', estado: _Trabajando('Conectando el energizador a «${red ?? ''}»…'));
    }
    return _Fila(
      icono: Icons.router_rounded,
      titulo: 'Segunda conexión',
      estado: Text(
        red == null
            ? 'Opcional · agrega la Wi‑Fi de la casa para usarla además de la red celular'
            : 'Opcional · si la red celular falla, sigue reportando por «$red»',
        style: apoyo,
      ),
      trailing: red == null
          ? BotonFila(etiqueta: 'Agregar Wi‑Fi', onPressed: _ocupado ? null : _irWifiCasa)
          : BotonFila(etiqueta: 'Conectar', onPressed: _ocupado ? null : _conectarOhmboxWifi),
    );
  }

  Widget _filaEntrada(Map<String, dynamic> x, TextStyle? apoyo, ColorScheme cs, OhmColors ohm) {
    final index = (x['index'] as num).toInt();
    final nombre = (x['nombre'] ?? 'Entrada $index').toString();
    final alta = x['dadaDeAlta'] == true;
    final prueba = (x['prueba'] as Map?)?.cast<String, dynamic>();
    final fase = prueba?['fase']?.toString();
    final abierta = x['abierta'];
    final ahora = abierta == true ? 'abierta' : (abierta == false ? 'cerrada' : 'sin reporte');
    final titulo = alta && nombre != 'Entrada $index' ? nombre : 'Entrada $index';
    const icono = Icons.sensor_door_rounded;
    if (alta) {
      return _Fila(
        icono: icono,
        titulo: titulo,
        estado: EstadoPunto('En orden · entrada $index · $ahora', color: ohm.success),
      );
    }
    return switch (fase) {
      'cerrar' => _Fila(icono: icono, titulo: titulo, estado: const _Trabajando('1 de 2 · Cierra la puerta y espera 3 segundos')),
      'abrir' => _Fila(icono: icono, titulo: titulo, estado: const _Trabajando('2 de 2 · Ahora ábrela')),
      'verificada' => _Fila(
        icono: icono,
        titulo: titulo,
        estado: EstadoPunto('Funciona · ponle nombre para guardarla', color: ohm.success),
        trailing: BotonFila(etiqueta: 'Guardar', lleno: true, onPressed: _ocupado ? null : () => _registrarEntrada(index, nombre)),
      ),
      'expirada' => _Fila(
        icono: icono,
        tono: _Tono.rojo,
        titulo: titulo,
        estado: EstadoPunto('No vimos la puerta cerrar y abrir. Revisa el cable de la entrada $index', color: cs.error),
        trailing: BotonFila(etiqueta: 'Volver a probar', onPressed: _listo ? () => _probarEntrada(index) : null),
      ),
      _ => _Fila(
        icono: icono,
        titulo: titulo,
        estado: EstadoPunto('Sin probar · marca $ahora', color: cs.onSurfaceVariant),
        trailing: BotonFila(etiqueta: 'Probar', onPressed: _listo ? () => _probarEntrada(index) : null),
      ),
    };
  }

  Widget _filaSirena(TextStyle? apoyo, ColorScheme cs, OhmColors ohm) {
    final sono = _sirena['sono'];
    final Widget estado = _sirenaSonando
        ? EstadoPunto('Sonando…', color: cs.primary)
        : sono == true
        ? EstadoPunto('Sonó · puedes hacerla sonar otra vez', color: ohm.success)
        : sono == false
        ? EstadoPunto('No sonó · revisa el cable y vuelve a probar', color: cs.error)
        : _sirenaPorConfirmar
        ? EstadoPunto('Se apagó', color: cs.onSurfaceVariant)
        : EstadoPunto('Sin probar', color: cs.onSurfaceVariant);
    return _Fila(
      icono: Icons.campaign_rounded,
      tono: _sirenaSonando ? _Tono.naranja : (sono == false ? _Tono.rojo : _Tono.gris),
      titulo: 'Sirena',
      estado: estado,
      trailing: _sirenaSonando
          ? BotonFila(etiqueta: 'Apagar', icono: Icons.volume_off_rounded, onPressed: _ocupado ? null : _apagarSirena)
          : BotonFila(etiqueta: 'Sonar', icono: Icons.campaign_rounded, onPressed: _listo ? _encenderSirena : null),
      extra: _preguntarSirena
          ? _Pregunta(
              texto: '¿La escuchaste?',
              detalle: _sirenaSonando ? 'se apaga en $_sirenaRestante' : null,
              botones: [
                BotonFila(etiqueta: 'Sí, sonó', lleno: true, onPressed: _ocupado ? null : () => _contestarSirena(true)),
                BotonFila(etiqueta: 'No sonó', onPressed: _ocupado ? null : () => _contestarSirena(false)),
              ],
            )
          : null,
    );
  }

  Widget _filaSalida(Map<String, dynamic> s, TextStyle? apoyo, ColorScheme cs, OhmColors ohm) {
    final index = (s['index'] as num).toInt();
    const icono = Icons.flash_on_rounded;
    if (s['dadaDeAlta'] == true) {
      final tipo = s['tipo']?.toString();
      return _Fila(
        icono: icono,
        titulo: (s['nombre'] ?? 'Salida $index').toString(),
        estado: EstadoPunto(
          'Encendió · salida $index · ${_tipoSalidaTexto[tipo] ?? tipo ?? ''} · ${s['modo'] == 'pulso' ? 'pulso' : 'encendido/apagado'}',
          color: ohm.success,
        ),
      );
    }
    if (_salidaPorConfirmar.contains(index)) {
      return _Fila(
        icono: icono,
        tono: _Tono.naranja,
        titulo: 'Salida $index',
        estado: EstadoPunto('Se encendió 5 segundos', color: cs.primary),
        trailing: BotonFila(etiqueta: 'Probar', onPressed: _listo ? () => _probarSalida(index) : null),
        extra: _Pregunta(
          texto: '¿Encendió lo que está conectado?',
          botones: [
            BotonFila(etiqueta: 'Sí, encendió', lleno: true, onPressed: _ocupado ? null : () => _contestarSalida(index, encendio: true)),
            BotonFila(etiqueta: 'No encendió', onPressed: _ocupado ? null : () => _contestarSalida(index, encendio: false)),
          ],
        ),
      );
    }
    final noEncendio = _salidaNoEncendio.contains(index);
    return _Fila(
      icono: icono,
      tono: noEncendio ? _Tono.rojo : _Tono.gris,
      titulo: 'Salida $index',
      estado: noEncendio
          ? EstadoPunto('No encendió · quedó en el reporte. Revisa el cable y vuelve a probar', color: cs.error)
          : EstadoPunto('Sin probar', color: cs.onSurfaceVariant),
      trailing: BotonFila(etiqueta: noEncendio ? 'Volver a probar' : 'Probar', onPressed: _listo ? () => _probarSalida(index) : null),
    );
  }

  Widget _filaCamara(int i, Map<String, dynamic> x, OhmColors ohm, ColorScheme cs) {
    final enLinea = x['estado'] == 'online';
    final red = (x['red'] ?? '').toString();
    return _Fila(
      icono: Icons.videocam_rounded,
      titulo: '${i + 1}. ${x['nombre'] ?? ''}',
      estado: EstadoPunto(
        [enLinea ? 'En línea' : 'Sin respuesta', if (red.isNotEmpty) '${_marca(x['proveedor'])} «$red»' else 'serie ${x['serie'] ?? ''}'].join(' · '),
        color: enLinea ? ohm.success : cs.error,
      ),
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

enum _Tono { gris, naranja, rojo }

/// Fila de un dispositivo (v2, lienzo «V1 · Agregar dispositivos»): ícono en cuadrito, título, estado
/// debajo y acción a la derecha. [extra] es lo que pasa en la fila (una pregunta). Va dentro de un
/// [GrupoFilas], que pone el fondo blanco y la línea fina entre filas.
class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, this.estado, this.trailing, this.extra, this.tono = _Tono.gris});

  final IconData icono;
  final String titulo;
  final Widget? estado;
  final Widget? trailing;
  final Widget? extra;
  final _Tono tono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (Color fondo, Color tinta) = switch (tono) {
      _Tono.naranja => (cs.primaryContainer, cs.primary),
      _Tono.rojo => (cs.error.withValues(alpha: 0.10), cs.error),
      _Tono.gris => (cs.surfaceContainerHighest, cs.onSurface),
    };
    return AnimatedSize(
      duration: AppMotion.of(context, AppDurations.base),
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.of(context, AppDurations.base),
                    curve: AppCurves.standard,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(9)),
                    child: Icon(icono, size: 18, color: tinta),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: theme.textTheme.titleMedium),
                        if (estado != null) ...[
                          const SizedBox(height: 2),
                          CambioSuave(
                            alineacion: Alignment.centerLeft,
                            child: KeyedSubtree(key: ValueKey(estado.runtimeType), child: estado!),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                ],
              ),
              if (extra != null) Padding(padding: const EdgeInsets.only(left: 46, top: 8), child: extra),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila «+ Agregar …» (v2): «+» naranja en círculo naranja claro y el texto en tinta. Apagada, dice
/// por qué en [nota].
class _FilaAgregar extends StatelessWidget {
  const _FilaAgregar({required this.texto, required this.onTap, this.nota});

  final String texto;
  final VoidCallback? onTap;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activo = onTap != null;
    return Semantics(
      button: true,
      enabled: activo,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  AnimatedOpacity(
                    duration: AppMotion.of(context, AppDurations.base),
                    opacity: activo ? 1 : 0.4,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.add_rounded, size: 20, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(texto, style: theme.textTheme.titleMedium?.copyWith(color: activo ? cs.onSurface : cs.onSurfaceVariant)),
                        if (nota != null) Text(nota!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Esperando la señal…» dentro de la fila: ruedita chica y la frase de qué hacer.
class _Trabajando extends StatelessWidget {
  const _Trabajando(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
          const SizedBox(width: 8),
          Flexible(child: Text(texto, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Pregunta dentro de la fila (v2, «V2 · Momentos en la fila»): texto, un detalle gris (la cuenta
/// regresiva) y las respuestas como píldoras.
class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.texto, required this.botones, this.detalle});

  final String texto;
  final String? detalle;
  final List<Widget> botones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: texto,
              children: [
                if (detalle != null)
                  TextSpan(
                    text: ' · $detalle',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          // IntrinsicWidth: la píldora mide lo que su texto (dentro de Wrap se estiraba a todo lo ancho).
          Wrap(spacing: 8, children: [for (final b in botones) IntrinsicWidth(child: b)]),
        ],
      ),
    );
  }
}
