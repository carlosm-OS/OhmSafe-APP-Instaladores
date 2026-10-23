import 'escanear_serie_screen.dart';
import '../core/utils/serie_formato.dart';
import '../core/error/failures.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../core/utils/destino_equipo.dart';
import '../widgets/destino_equipo_confirmacion.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/cancellation_flow.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import '../core/di/injection_container.dart';
import '../core/network/actividad.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/utils/fechas_odoo.dart';
import '../core/utils/ligado_cliente.dart';
import '../widgets/botones_dialogo.dart';

enum LinkState { input, validating }

class LinkEnergizerScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const LinkEnergizerScreen({super.key, required this.ticket});

  @override
  State<LinkEnergizerScreen> createState() => _LinkEnergizerScreenState();
}

class _LinkEnergizerScreenState extends State<LinkEnergizerScreen> {
  LinkState _currentState = LinkState.input;
  final TextEditingController _macController = TextEditingController();
  bool _isLoading = false;

  // Resultado de la búsqueda, dentro de la pantalla (v2: título + qué hacer + acción).
  bool _showBanner = false;
  bool _bannerIsSuccess = false;
  String _bannerText = '';
  String? _bannerDetalle;
  ({String etiqueta, VoidCallback alTocar})? _bannerAccion;

  /// Error al vincular, junto al botón (v2: antes salía en un SnackBar).
  ({String titulo, String texto})? _errorVincular;

  @override
  void dispose() {
    _sondeoSenal?.cancel();
    _macController.dispose();
    super.dispose();
  }

  /// Equipo ya dado de alta pero sin señal: se vuelve a consultar cada 5 s, en silencio, hasta que
  /// aparezca en línea o pasen 3 minutos (2026-10-15). Recién encendido tarda en reportar; antes la
  /// ficha se quedaba en «Sin señal reciente» y el instalador se ponía a revisar cables.
  Timer? _sondeoSenal;
  DateTime? _esperandoDesde;
  static const _esperaMaxima = Duration(minutes: 3);
  bool get _esperandoSenal => _sondeoSenal != null;

  void _vigilarSenal(String serie) {
    _sondeoSenal?.cancel();
    _sondeoSenal = null;
    if (_diag == null || _diag?['enLinea'] == true || _equipoNuevo) return;
    _esperandoDesde = DateTime.now();
    _sondeoSenal = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (DateTime.now().difference(_esperandoDesde!) > _esperaMaxima) {
        setState(() {
          _sondeoSenal?.cancel();
          _sondeoSenal = null;
        });
        return;
      }
      await Actividad.enSilencio(() => _refrescarFicha(serie));
      if (mounted && _diag?['enLinea'] == true) {
        setState(() {
          _sondeoSenal?.cancel();
          _sondeoSenal = null;
        });
      }
    });
  }

  void _dejarDeVigilar() {
    _sondeoSenal?.cancel();
    _sondeoSenal = null;
  }

  // MAC real del equipo, detectada por el diagnóstico (se guarda en Odoo; no se muestra).
  String _macDetectada = '';

  /// Equipo NUEVO (2026-10-06): no existe aún en el dashboard pero su lote de Odoo
  /// trae la MAC. Nadie lo registra a mano: al vincular se crea con serie+MAC
  /// y se liga al cliente del ticket; la telemetría se verifica después.
  bool _equipoNuevo = false;

  /// Ya quedó vinculado a la intervención (y dado de alta si era nuevo): el
  /// botón pasa a «Continuar» y sólo falta que las pruebas den verde.
  bool _vinculado = false;

  /// Diagnóstico real devuelto por el backend (serie, MAC, en línea, cerca,
  /// firmware, último reporte). null hasta que se encuentre el equipo.
  Map<String, dynamic>? _diag;

  /// Cámara real: lee el QR del energizador, pone la serie en el campo y
  /// arranca el diagnóstico con ella.
  Future<void> _startScanning() async {
    final serie = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const EscanearSerieScreen()));
    if (!mounted || serie == null || serie.isEmpty) return;
    _macController.text = serie;
    await _startValidation(serie);
  }

  /// Problema con la serie (ya instalada o apartada en otra instalación): el backend ya dice qué
  /// pasó y qué hacer. v2 (2026-10-23): sin «contexto: mensaje» pegados; el título dice qué falló.
  bool _esDeSerie(Failure f) => f is ServerFailure && f.code.startsWith('SERIE_');

  /// Diagnóstico REAL por número de serie: lee la telemetría del equipo y pinta
  /// cada prueba. La tierra física no tiene telemetría → la confirma el instalador.
  Future<void> _startValidation(String serie) async {
    _dejarDeVigilar();
    final s = normalizarSerie(serie);
    if (s.isNotEmpty && s != _macController.text) _macController.text = s;
    if (s.isEmpty) {
      setState(() => _currentState = LinkState.input);
      _triggerBanner(false, "Falta la serie", detalle: "Escanea el QR o escribe el número de serie.");
      return;
    }
    setState(() {
      _currentState = LinkState.validating;
      _isLoading = true;
      _showBanner = false;
      _errorVincular = null;
    });

    final ordenId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    // Con la orden, el backend también revisa la serie contra el inventario de
    // Odoo (ya instalada con otro cliente o apartada en otra instalación).
    final result = await sl.get<OrdenesRepository>().diagnosticoEnergizador(s, ordenId: ordenId);
    if (!mounted) return;
    result.fold(
      (d) {
        setState(() {
          _isLoading = false;
          if (d['encontrado'] != true) {
            if (d['motivo'] == 'NUEVO' && (d['mac'] ?? '').toString().isNotEmpty) {
              // Equipo nuevo con MAC en su lote: se puede vincular (eso lo da de alta).
              _diag = Map<String, dynamic>.from(d);
              _macDetectada = (d['mac'] ?? '').toString();
              _equipoNuevo = true;
              _triggerBanner(true, "Equipo nuevo: se registra al vincularlo");
              return;
            }
            // De vuelta al input: sin equipo no hay nada que diagnosticar. Antes
            // el estado se quedaba en `validating` y el panel de pruebas (con su
            // título de éxito) seguía en pantalla junto al banner de error.
            _diag = null;
            _macDetectada = '';
            _currentState = LinkState.input;
            if (d['motivo'] == 'SIN_ALTA') {
              _triggerBanner(false, "Al equipo $s le falta un dato en almacén", detalle: "Pide a almacén que lo complete y vuelve a escanear.");
            } else {
              _triggerBanner(
                false,
                "No encontramos el equipo $s",
                detalle: "Revisa el número o escanea el QR.",
                accion: (etiqueta: "Escanear otra vez", alTocar: _startScanning),
              );
            }
            return;
          }
          _diag = Map<String, dynamic>.from(d);
          _macDetectada = (d['mac'] ?? '').toString();
          _equipoNuevo = false;
          // La prueba de alto voltaje (cerca energizada) se retiró por ahora: los equipos
          // todavía no traen ese sensor en la telemetría (Carlos, 2026-10-06). El estado de
          // la cerca sigue visible como dato informativo más abajo.
          _showBanner = false; // la ficha ya dice «¿Es este el equipo?»
        });
        _vigilarSenal(s);
      },
      (f) {
        setState(() {
          _isLoading = false;
          _currentState = LinkState.input;
          if (_esDeSerie(f)) {
            _triggerBanner(false, "Esta serie no se puede vincular", detalle: f.message, accion: (etiqueta: "Escanear otra vez", alTocar: _startScanning));
          } else {
            _triggerBanner(
              false,
              "No pudimos leer el equipo",
              detalle: f.message,
              accion: (etiqueta: "Volver a intentar", alTocar: () => _startValidation(_macController.text)),
            );
          }
        });
      },
    );
  }

  void _triggerBanner(bool isSuccess, String text, {String? detalle, ({String etiqueta, VoidCallback alTocar})? accion}) {
    setState(() {
      _showBanner = true;
      _bannerIsSuccess = isSuccess;
      _bannerText = text;
      _bannerDetalle = detalle;
      _bannerAccion = accion;
    });
  }

  bool _isSending = false;

  /// Vincula el energizador a la orden en el backend (marca `x_estado_vinculacion`
  /// y guarda la MAC en Odoo) y, solo si tiene éxito, regresa 'device_linked'.
  Future<void> _vincularEnergizador() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _errorVincular = null;
    });
    final id = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final serie = _macController.text.trim();
    // A dónde va el equipo lo decide la venta (2026-10-14, una vivienda = una suscripción):
    // la app sólo lo muestra para confirmar. Si la consulta falla o el backend es anterior,
    // se vincula sin confirmar y el backend decide igual: nunca bloquea por la red.
    final repo = sl.get<OrdenesRepository>();
    final casas = await repo.casasParaVincular(id);
    if (!mounted) return;
    DestinoDecidido? destino;
    casas.fold((d) => destino = DestinoDecidido.fromCasas(d), (_) {});
    if (destino != null && destino!.tipo != 'sin_cuenta') {
      final ok = await confirmarDestinoEquipo(context, destino!);
      if (!mounted) return;
      if (!ok) {
        setState(() => _isSending = false); // canceló o la venta no dice a qué casa va
        return;
      }
    }
    final result = await repo.vincularEnergizador(id, codigo: _macDetectada.isNotEmpty ? _macDetectada : serie, serie: serie);
    if (!mounted) return;
    result.fold(
      (dashboard) async {
        // El equipo quedó vinculado a la intervención, pero puede no haber
        // llegado a la cuenta del cliente: se dice la verdad antes de seguir.
        final aviso = avisoLigadoCliente(dashboard);
        if (aviso != null) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              // Con el teclado abierto el contenido se desplaza en vez de desbordarse (franja amarilla).
              scrollable: true,
              title: const Text('Vinculado, pero falta la cuenta del cliente'),
              content: Text(aviso),
              actions: [BotonesDialogo(primario: 'Entendido, seguir', onPrimario: () => Navigator.pop(ctx))],
            ),
          );
          if (!mounted) return;
        }
        // Vinculado: la app avanza sola al cierre (Carlos, 2026-10-09; hasta la build 36 se
        // quedaba aquí con el botón «Continuar» y parecía que no había pasado nada). El
        // resultado se muestra en un aviso sobre la pantalla de pasos.
        final casaMap = (dashboard['casa'] as Map?)?.cast<String, dynamic>();
        final casa = casaMap?['nombre']?.toString();
        // Qué pasó con la suscripción de la venta (plan nuevo): se dice tal cual.
        final suscripcion = (casaMap?['suscripcion'] as Map?)?['detalle']?.toString();
        setState(() {
          _vinculado = true;
          _equipoNuevo = false;
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              [
                casa != null ? "Energizador vinculado a «$casa»" : "Energizador vinculado",
                if (suscripcion != null && suscripcion.isNotEmpty) suscripcion,
              ].join('\n'),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, 'device_linked');
      },
      (failure) {
        setState(() {
          _isSending = false;
          _errorVincular = (titulo: _esDeSerie(failure) ? "Esta serie no se puede vincular" : "No pudimos vincular el energizador", texto: failure.message);
        });
      },
    );
  }

  Future<void> _refrescarFicha(String serie) async {
    final ordenId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final result = await sl.get<OrdenesRepository>().diagnosticoEnergizador(serie.trim(), ordenId: ordenId);
    if (!mounted) return;
    result.fold((d) {
      if (d['encontrado'] == true) setState(() => _diag = Map<String, dynamic>.from(d));
    }, (_) {});
  }

  /// Botón principal: «Vincular» (si el equipo es nuevo, eso lo da de alta). Al vincular la
  /// pantalla se cierra sola; «Continuar» sólo queda por si se regresa a ella ya vinculado.
  String get _ctaLabel => _vinculado ? "Continuar" : (_equipoNuevo ? "Registrar y vincular" : "Vincular energizador");
  // Mientras envía, el botón sigue naranja con su spinner (loading ya ignora los toques).
  bool get _ctaHabilitado => _diag != null;
  void _onCta() {
    if (_vinculado) {
      Navigator.pop(context, 'device_linked');
      return;
    }
    _vincularEnergizador();
  }

  /// La flecha y el atrás del teléfono hacen lo mismo (auditoría 2026-10-23: el del teléfono salía de
  /// la pantalla aunque se estuviera validando).
  void _regresar() {
    if (_isSending) return;
    if (_currentState == LinkState.validating && !_vinculado) {
      _dejarDeVigilar();
      setState(() {
        _currentState = LinkState.input;
        _showBanner = false;
        _errorVincular = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  EncabezadoFlujo(titulo: "Vincular energizador", alVolver: _regresar),
                  Expanded(child: _buildStateContent(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final apoyo = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    switch (_currentState) {
      case LinkState.input:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            if (_showBanner) _avisoBusqueda(),
            // La tarjeta del QR abre la cámara: es lo más rápido en sitio.
            Semantics(
              button: true,
              label: 'Escanear el QR del energizador',
              child: GestureDetector(
                key: const Key('vincular-escanear'),
                onTap: _startScanning,
                child: TarjetaFlujo(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 96, color: cs.onSurface),
                      const SizedBox(height: 12),
                      Text(
                        "Escanea el QR de la etiqueta",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text("El energizador debe estar encendido.", textAlign: TextAlign.center, style: apoyo),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OhmGradientButton(label: "Escanear QR", icon: Icons.qr_code_scanner_rounded, onPressed: _startScanning),
            const SizedBox(height: 28),

            const EtiquetaSeccion(
              "O escribe la serie",
              tituloAyuda: '¿Dónde está la serie?',
              ayuda: [
                'En la etiqueta del energizador, junto al código QR. Empieza con OS-OBV01.',
                'Basta con el número final (por ejemplo 26). Los guiones se ponen solos.',
              ],
            ),
            TextField(
              controller: _macController,
              textCapitalization: TextCapitalization.characters,
              // Los guiones se ponen solos (OSOBV010026 → OS-OBV01-0026); basta el número (26).
              inputFormatters: [SerieInputFormatter()],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _startValidation(v),
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: "Número de serie (ej. OS-OBV01-0026)",
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: IconButton(
                  key: const Key('vincular-buscar'),
                  tooltip: 'Buscar',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.arrow_forward_rounded, color: cs.primary),
                  onPressed: () => _startValidation(_macController.text),
                ),
              ),
            ),
            const SizedBox(height: 32),
            BotonSecundario(etiqueta: "Cancelar instalación", peligro: true, onPressed: () => showCancellationFlow(context, widget.ticket)),
          ],
        );

      case LinkState.validating:
        final enLinea = _diag?['enLinea'] == true;
        final cerca = _diag?['cercaActiva'] == true;
        final version = (_diag?['firmware'] ?? '').toString();
        final conexion = enLinea ? "En línea" : (_equipoNuevo ? "Se ve al vincularlo" : (_esperandoSenal ? "Esperando señal…" : "Sin señal reciente"));
        // Rojo sólo cuando ya se esperó: equipo nuevo o en espera van en gris.
        final colorConexion = enLinea ? ohm.success : (_equipoNuevo || _esperandoSenal ? cs.onSurfaceVariant : cs.error);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            if (_isLoading)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(cs.primary)),
                      const SizedBox(height: 16),
                      Text("Buscando el equipo…", style: apoyo),
                    ],
                  ),
                ),
              )
            else ...[
              if (_showBanner) _avisoBusqueda(),
              // v2 (2026-10-23, lienzo «7 · Vincular»): la ficha es un grupo blanco; sin MAC ni firmware.
              GrupoFilas(
                children: [
                  FilaFlujo(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(9)),
                      child: Icon(Icons.bolt_rounded, size: 18, color: cs.primary),
                    ),
                    titulo: _diag?['serie']?.toString() ?? '—',
                    subtitulo: version.isEmpty ? "Energizador" : "Energizador · versión $version",
                  ),
                  FilaFlujo(
                    titulo: "Conexión",
                    trailing: EstadoPunto(conexion, color: colorConexion),
                  ),
                  FilaFlujo(
                    titulo: "Cerca",
                    trailing: EstadoPunto(cerca ? "Encendida" : "Apagada", color: cerca ? ohm.success : cs.onSurfaceVariant),
                  ),
                  FilaFlujo(
                    titulo: "Último reporte",
                    trailing: Text(_formatUltimoReporte(_diag?['ultimoReporte']), style: apoyo),
                  ),
                ],
              ),
              if (!_vinculado && !enLinea && _esperandoSenal) const EsperandoSenal(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _vinculado
                      ? "Ya quedó vinculado a esta instalación."
                      : (enLinea
                            ? "Revisa que la serie coincida con la etiqueta."
                            : _equipoNuevo
                            ? "Es un equipo nuevo: su conexión se ve después de vincularlo y puede tardar 1 o 2 minutos en aparecer en línea. Ya puedes vincularlo."
                            : "Puedes vincularlo sin señal. Para la prueba del siguiente paso sí necesita corriente y señal."),
                  style: apoyo,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorVincular != null)
                MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: _errorVincular!.titulo, texto: _errorVincular!.texto),
              OhmGradientButton(label: _ctaLabel, loading: _isSending, loadingLabel: 'Vinculando el energizador…', onPressed: _ctaHabilitado ? _onCta : null),
              const SizedBox(height: 12),
              if (!_vinculado) ...[
                BotonSecundario(
                  etiqueta: "Buscar otro equipo",
                  onPressed: _isSending
                      ? null
                      : () => setState(() {
                          _dejarDeVigilar();
                          _currentState = LinkState.input;
                          _showBanner = false;
                          _errorVincular = null;
                          _diag = null;
                        }),
                ),
                const SizedBox(height: 12),
              ],
              // Antes decía «Reportar incidencias (opcional)» y abría la hoja de cancelar (auditoría 2026-10-23).
              BotonSecundario(etiqueta: "Cancelar instalación", peligro: true, onPressed: () => showCancellationFlow(context, widget.ticket)),
            ],
          ],
        );
    }
  }

  /// Resultado de la búsqueda, dentro de la pantalla (antes un cartel flotante tapaba el encabezado).
  Widget _avisoBusqueda() {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    final accion = _bannerAccion;
    return MensajeFlujo(
      icono: _bannerIsSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      color: _bannerIsSuccess ? ohm.success : cs.error,
      titulo: _bannerText,
      texto: _bannerDetalle,
      accion: accion == null ? null : BotonFila(etiqueta: accion.etiqueta, onPressed: accion.alTocar),
    );
  }

  /// "dd/MM/yyyy HH:mm" a partir del ISO del backend; "Nunca" si no hay reporte.
  String _formatUltimoReporte(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return "Nunca";
    return FechasOdoo.fechaHora(iso.toString());
  }
}
