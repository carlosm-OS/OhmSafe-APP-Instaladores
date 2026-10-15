import 'escanear_serie_screen.dart';
import '../core/utils/serie_formato.dart';
import '../core/error/failures.dart';
import 'dart:async';
import '../widgets/notification_bell.dart';
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
              title: const Text('Vinculado, pero falta la cuenta del cliente'),
              content: Text(aviso),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
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
      : (_equipoNuevo ? "Dar de alta y vincular" : "Vincular a esta instalación");
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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Logo centrado, iconos derecha)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "OHM",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              Text(
                                "SAFE",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: const NotificationBell(),
                        ),
                      ],
                    ),
                  ),

                // Back chevron and Centered Title Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              "Vincular energizador",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () {
                                if (_currentState == LinkState.validating) {
                                  setState(() {
                                    _currentState = LinkState.input;
                                  });
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(6),
                                shape: const CircleBorder(),
                              ),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                                color: theme.iconTheme.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const PasoDeInstalacion(paso: 4),
                const SizedBox(height: 4),
                // State Content
                Expanded(
                  child: _buildStateContent(context),
                ),
              ],
            ),
          ),


          // Shared bottom navigation bar
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4);

    switch (_currentState) {
      case LinkState.input:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            Text("Busca el energizador", textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text("Debe estar encendido. Escanea el QR de su etiqueta.", textAlign: TextAlign.center, style: muted),
            const SizedBox(height: 20),
            if (_showBanner) ...[_avisoBusqueda(), const SizedBox(height: 16)],

            // Acción principal: escanear (lo más rápido en sitio).
            Material(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                key: const Key('vincular-escanear'),
                onTap: _startScanning,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 56, color: cs.primary),
                      const SizedBox(height: 10),
                      Text("Escanear QR", style: theme.textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text("Abre la cámara", style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("o escribe la serie", style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: 16),

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
                labelText: "Número de serie",
                hintText: "Ej. 26 u OS-OBV01-0026",
                helperText: "Basta con el número final.",
                filled: true,
                fillColor: ohm.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: const InfoAyuda(
                  titulo: '¿Dónde está la serie?',
                  puntos: [
                    'En la etiqueta del energizador, junto al código QR.',
                    'Empieza con OS-OBV01 (por ejemplo OS-OBV01-0026).',
                    'Puedes escribir sólo el número final: 26. Los guiones se ponen solos.',
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _startValidation(_macController.text),
                icon: const Icon(Icons.search_rounded),
                label: const Text("Buscar equipo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: () => showCancellationFlow(context, widget.ticket),
              icon: const Icon(Icons.report_gmailerrorred_rounded, size: 20),
              label: const Text("¿Algo salió mal? Reportar o cancelar"),
              style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            ),
          ],
        );

      case LinkState.validating:
        final enLinea = _diag?['enLinea'] == true;
        final cerca = _diag?['cercaActiva'] == true;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            Text(
              _isLoading ? "Buscando el equipo…" : (_vinculado ? "Equipo vinculado" : "¿Es este el equipo?"),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _isLoading
                  ? "Leyendo los datos del energizador."
                  : (_vinculado ? "Ya quedó ligado a esta instalación." : "Revisa que la serie coincida con la etiqueta y vincúlalo."),
              textAlign: TextAlign.center,
              style: muted,
            ),
            const SizedBox(height: 20),
            if (_showBanner && !_isLoading) ...[_avisoBusqueda(), const SizedBox(height: 16)],

            if (_isLoading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else ...[
              // Ficha: lo que importa arriba; lo técnico, plegado.
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Column(
                        children: [
                          _buildDetailRow("Serie", _diag?['serie']?.toString() ?? '—', fuerte: true),
                          const SizedBox(height: 12),
                          _buildDetailRow("Conexión", enLinea ? "En línea" : "Sin señal reciente", punto: enLinea ? ohm.success : cs.error),
                          const SizedBox(height: 12),
                          _buildDetailRow("Cerca", cerca ? "Encendida" : "Apagada", punto: cerca ? cs.primary : cs.outline),
                          const SizedBox(height: 12),
                          _buildDetailRow("Último reporte", _formatUltimoReporte(_diag?['ultimoReporte'])),
                        ],
                      ),
                    ),
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        title: Text("Datos técnicos", style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        children: [
                          _buildDetailRow("MAC", _diag?['mac']?.toString() ?? '—'),
                          const SizedBox(height: 10),
                          _buildDetailRow("Firmware", _diag?['firmware']?.toString() ?? '—'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!enLinea && !_vinculado) ...[
                const SizedBox(height: 12),
                AvisoEnLinea(
                  icono: Icons.wifi_off_rounded,
                  color: cs.tertiary,
                  titulo: "Puedes vincularlo aunque no tenga señal",
                  texto: "Para la prueba del siguiente paso sí necesita estar conectado a la corriente y con señal.",
                ),
              ],
              const SizedBox(height: 28),
              OhmGradientButton(
                label: _ctaLabel,
                icon: _vinculado ? Icons.arrow_forward_rounded : Icons.link_rounded,
                loading: _isSending,
                onPressed: _ctaHabilitado ? _onCta : null,
              ),
              if (!_vinculado) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSending
                      ? null
                      : () => setState(() {
                            _currentState = LinkState.input;
                            _showBanner = false;
                            _diag = null;
                          }),
                  child: const Text("No es este, buscar otro"),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => showCancellationFlow(context, widget.ticket),
                icon: const Icon(Icons.report_gmailerrorred_rounded, size: 20),
                label: const Text("¿Algo salió mal? Reportar o cancelar"),
                style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
    }
  }

  /// Resultado de la búsqueda, en su lugar (antes era un cartel flotante que tapaba el encabezado
  /// y nunca se iba).
  Widget _avisoBusqueda() {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    return AvisoEnLinea(
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

  Widget _buildDetailRow(String key, String value, {Color? punto, bool fuerte = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (punto != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: punto, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: (fuerte ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
