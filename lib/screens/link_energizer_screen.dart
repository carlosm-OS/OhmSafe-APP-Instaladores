import 'escanear_serie_screen.dart';
import '../core/utils/serie_formato.dart';
import '../core/error/failures.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../core/utils/destino_equipo.dart';
import '../widgets/destino_equipo_confirmacion.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cancellation_flow.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/ayuda.dart';
import '../core/di/injection_container.dart';
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

  // Validation indicators state
  /// Declaración explícita del técnico de que hizo la tierra física conforme
  /// al procedimiento. NO es una prueba: no hay telemetría que la valide, por
  /// eso dejó de pintarse como "Pendiente" junto a las que sí se miden — eso
  /// daba a entender que el sistema la comprobaría.
  bool _tierraConfirmada = false;
  String _redLteStatus = 'Gris';
  String _retornoStatus = 'Gris';

  // Banner toast states
  bool _showBanner = false;
  bool _bannerIsSuccess = false;
  String _bannerText = '';

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  // MAC real del equipo, detectada por el diagnóstico (se guarda en Odoo).
  String _macDetectada = '';

  /// Equipo NUEVO (2026-10-06): no existe aún en el dashboard pero su lote de Odoo
  /// trae la MAC. Nadie lo da de alta a mano: al vincular se crea con serie+MAC
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
    final serie = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanearSerieScreen()),
    );
    if (!mounted || serie == null || serie.isEmpty) return;
    _macController.text = serie;
    await _startValidation(serie);
  }

  /// Mensaje del backend tal cual cuando es sobre la serie (ya instalada o
  /// apartada en otra instalación); si no, con contexto.
  String _mensajeError(Failure f, String contexto) =>
      f is ServerFailure && f.code.startsWith('SERIE_') ? f.message : '$contexto: ${f.message}';

  /// Diagnóstico REAL por número de serie: lee la telemetría del equipo y pinta
  /// cada prueba. La tierra física no tiene telemetría → la confirma el instalador.
  Future<void> _startValidation(String serie) async {
    final s = normalizarSerie(serie);
    if (s.isNotEmpty && s != _macController.text) _macController.text = s;
    if (s.isEmpty) {
      setState(() => _currentState = LinkState.input);
      _triggerBanner(false, "Escanea el QR o escribe el número de serie.");
      return;
    }
    setState(() {
      _currentState = LinkState.validating;
      _isLoading = true;
      _showBanner = false;
      _redLteStatus = 'Gris'; // batería auxiliar
      _retornoStatus = 'Gris'; // conexión a línea
    });

    final ordenId = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    // Con la orden, el backend también revisa la serie contra el inventario de
    // Odoo (ya instalada con otro cliente o apartada en otra instalación).
    final result = await sl.get<OrdenesRepository>().diagnosticoEnergizador(s, ordenId: ordenId);
    if (!mounted) return;
    result.fold((d) {
      setState(() {
        _isLoading = false;
        if (d['encontrado'] != true) {
          if (d['motivo'] == 'NUEVO' && (d['mac'] ?? '').toString().isNotEmpty) {
            // Equipo nuevo con MAC en su lote: se puede vincular (eso lo da de alta).
            _diag = Map<String, dynamic>.from(d);
            _macDetectada = (d['mac'] ?? '').toString();
            _equipoNuevo = true;
            _redLteStatus = 'Gris';
            _retornoStatus = 'Gris';
            _triggerBanner(true, "Equipo nuevo: se da de alta al vincularlo.");
            return;
          }
          // De vuelta al input: sin equipo no hay nada que diagnosticar. Antes
          // el estado se quedaba en `validating` y el panel de pruebas (con su
          // título de éxito) seguía en pantalla junto al banner de error.
          _diag = null;
          _macDetectada = '';
          _currentState = LinkState.input;
          _triggerBanner(
              false,
              d['motivo'] == 'SIN_ALTA'
                  ? "Al equipo $s le falta un dato en almacén (su MAC). Pide a almacén que lo capture y vuelve a escanear."
                  : "No encontramos el equipo $s. Revisa el número o escanea el QR.");
          return;
        }
        _diag = Map<String, dynamic>.from(d);
        _macDetectada = (d['mac'] ?? '').toString();
        _equipoNuevo = false;
        // Telemetría real -> estado de cada prueba.
        _retornoStatus = d['conexionLinea'] == true ? 'Verde' : 'Rojo'; // energía de la calle
        _redLteStatus = d['bateria'] == 'ok'
            ? 'Verde'
            : (d['bateria'] == 'baja' ? 'Rojo' : 'Gris');
        // La prueba de alto voltaje (cerca energizada) se retiró por ahora: los equipos
        // todavía no traen ese sensor en la telemetría (Carlos, 2026-10-06). El estado de
        // la cerca sigue visible como dato informativo más abajo.
        _showBanner = false; // la ficha ya dice «¿Es este el equipo?»
      });
    }, (f) {
      setState(() {
        _isLoading = false;
        _currentState = LinkState.input;
        _triggerBanner(false, _mensajeError(f, "No pudimos leer el equipo"));
      });
    });
  }

  void _toggleTierra() {
    setState(() => _tierraConfirmada = !_tierraConfirmada);
  }

  void _triggerBanner(bool isSuccess, String text) {
    setState(() {
      _showBanner = true;
      _bannerIsSuccess = isSuccess;
      _bannerText = text;
    });
  }

  bool _isSending = false;

  /// Vincula el energizador a la orden en el backend (marca `x_estado_vinculacion`
  /// y guarda la MAC en Odoo) y, solo si tiene éxito, regresa 'device_linked'.
  Future<void> _vincularEnergizador() async {
    if (_isSending) return;
    setState(() => _isSending = true);
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
    final result = await repo.vincularEnergizador(
          id,
          codigo: _macDetectada.isNotEmpty ? _macDetectada : serie,
          serie: serie,
        );
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
              actions: [BotonesDialogo(primario: 'Entendido', onPrimario: () => Navigator.pop(ctx))],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text([
            casa != null ? "Energizador vinculado a «$casa»" : "Energizador vinculado",
            if (suscripcion != null && suscripcion.isNotEmpty) suscripcion,
          ].join('\n')),
          duration: const Duration(seconds: 5),
        ));
        Navigator.pop(context, 'device_linked');
      },
      (failure) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mensajeError(failure, "No pudimos vincular el energizador"))),
        );
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
  String get _ctaLabel => _vinculado
      ? "Continuar"
      : (_equipoNuevo ? "Dar de alta y vincular" : "Vincular energizador");
  // Mientras envía, el botón sigue naranja con su spinner (loading ya ignora los toques).
  bool get _ctaHabilitado => _diag != null;
  void _onCta() {
    if (_vinculado) {
      Navigator.pop(context, 'device_linked');
      return;
    }
    _vincularEnergizador();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoFlujo(
                  titulo: "Vincular energizador",
                  alVolver: () {
                    if (_currentState == LinkState.validating && !_vinculado) {
                      setState(() {
                        _currentState = LinkState.input;
                        _showBanner = false;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                Expanded(child: _buildStateContent(context)),
              ],
            ),
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final muted = TextStyle(fontSize: 14, height: 1.4, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6));

    switch (_currentState) {
      case LinkState.input:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 96, color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8)),
                      const SizedBox(height: 12),
                      Text("Escanea el QR de la etiqueta", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(height: 4),
                      Text("El energizador debe estar encendido.", style: muted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OhmGradientButton(label: "Escanear QR", icon: Icons.qr_code_scanner_rounded, onPressed: _startScanning),
            const SizedBox(height: 28),

            const EtiquetaSeccion(
              "O ESCRIBE LA SERIE",
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
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: "Número de serie (ej. 26)",
                filled: true,
                fillColor: ohm.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(
                  key: const Key('vincular-buscar'),
                  tooltip: 'Buscar',
                  icon: Icon(Icons.arrow_forward_rounded, color: cs.primary),
                  onPressed: () => _startValidation(_macController.text),
                ),
              ),
            ),
            const SizedBox(height: 32),
            BotonSecundario(etiqueta: "Cancelar instalación", onPressed: () => showCancellationFlow(context, widget.ticket)),
          ],
        );

      case LinkState.validating:
        final enLinea = _diag?['enLinea'] == true;
        final cerca = _diag?['cercaActiva'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(cs.primary)),
                    const SizedBox(height: 16),
                    Text("Buscando el equipo…", style: muted),
                  ],
                ),
              )
            else ...[
              if (_showBanner) _avisoBusqueda(),
              TarjetaFlujo(
                child: Column(
                  children: [
                    DatoFlujo(etiqueta: "Serie", valor: _diag?['serie']?.toString() ?? '—'),
                    DatoFlujo(etiqueta: "Conexión", valor: enLinea ? "En línea" : "Sin señal reciente", color: enLinea ? ohm.success : cs.error),
                    DatoFlujo(etiqueta: "Cerca", valor: cerca ? "Encendida" : "Apagada"),
                    DatoFlujo(etiqueta: "Último reporte", valor: _formatUltimoReporte(_diag?['ultimoReporte'])),
                    const SizedBox(height: 8),
                    Text(
                      "MAC ${_diag?['mac'] ?? '—'}  ·  Firmware ${_diag?['firmware'] ?? '—'}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _vinculado
                    ? "Ya quedó ligado a esta instalación."
                    : (enLinea
                        ? "Revisa que la serie coincida con la etiqueta."
                        : "Puedes vincularlo sin señal. Para la prueba del siguiente paso sí necesita corriente y señal."),
                textAlign: TextAlign.center,
                style: muted,
              ),
              const SizedBox(height: 24),
              OhmGradientButton(
                label: _ctaLabel,
                loading: _isSending,
                onPressed: _ctaHabilitado ? _onCta : null,
              ),
              const SizedBox(height: 12),
              if (!_vinculado) ...[
                BotonSecundario(
                  etiqueta: "Buscar otro equipo",
                  onPressed: _isSending
                      ? null
                      : () => setState(() {
                            _currentState = LinkState.input;
                            _showBanner = false;
                            _diag = null;
                          }),
                ),
                const SizedBox(height: 12),
              ],
              BotonSecundario(etiqueta: "Reportar incidencias (opcional)", onPressed: () => showCancellationFlow(context, widget.ticket)),
            ],
          ],
        );
    }
  }

  /// Resultado de la búsqueda, dentro de la pantalla (antes un cartel flotante tapaba el encabezado).
  Widget _avisoBusqueda() {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    return MensajeFlujo(
      icono: _bannerIsSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
      color: _bannerIsSuccess ? ohm.success : cs.error,
      titulo: _bannerText,
    );
  }

  /// Casilla explícita de la tierra física. Va aparte de las pruebas del
  /// sistema justamente porque no se mide: es una declaración del técnico, con
  /// su responsabilidad, que control de calidad verifica después.
  Widget _buildTierraCheckbox() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _tierraConfirmada ? cs.primary.withValues(alpha: 0.08) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _tierraConfirmada ? cs.primary : theme.dividerColor.withValues(alpha: 0.6),
          width: _tierraConfirmada ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: _toggleTierra,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _tierraConfirmada,
                onChanged: (_) => _toggleTierra(),
                activeColor: cs.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Confirmo que instalé la tierra física conforme al procedimiento",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Obligatorio para cerrar. Queda registrado a tu nombre y control de calidad lo verifica en sitio.",
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestIndicatorRow(String title, String status, {String? errorSubtitle}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;

    Color cardBg;
    Color badgeBg;
    Color badgeTextColor;
    String badgeText;

    switch (status) {
      case 'Verde':
        cardBg = ohm.successContainer;
        badgeBg = ohm.success.withValues(alpha: 0.20);
        badgeTextColor = ohm.success;
        badgeText = 'Completa';
        break;
      case 'Rojo':
        cardBg = cs.errorContainer;
        badgeBg = cs.error.withValues(alpha: 0.20);
        badgeTextColor = isDark ? cs.error : cs.onErrorContainer;
        badgeText = 'Error';
        break;
      case 'Gris':
      default:
        cardBg = isDark ? cs.surface.withValues(alpha: 0.5) : cs.surface;
        badgeBg = isDark ? cs.outline : cs.outlineVariant;
        badgeTextColor = isDark ? Colors.white70 : cs.onSurfaceVariant;
        badgeText = 'Pendiente';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: status == 'Rojo'
                  ? cs.error.withValues(alpha: 0.4)
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorSubtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 12),
            child: Text(
              errorSubtitle,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// "dd/MM/yyyy HH:mm" a partir del ISO del backend; "Nunca" si no hay reporte.
  String _formatUltimoReporte(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return "Nunca";
    return FechasOdoo.fechaHora(iso.toString());
  }
}
