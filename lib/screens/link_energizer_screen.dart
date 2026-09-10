import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cancellation_flow.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

enum LinkState { input, scanning, validating }

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
  String _tierraStatus = 'Gris'; // Gris, Verde, Rojo
  String _bateriaStatus = 'Gris';
  String _redLteStatus = 'Gris';
  String _retornoStatus = 'Gris';

  // Banner toast states
  bool _showBanner = false;
  bool _bannerIsSuccess = false;
  String _bannerText = '';

  Timer? _simulationTimer;

  @override
  void dispose() {
    _macController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // MAC real del equipo, detectada por el diagnóstico (se guarda en Odoo).
  String _macDetectada = '';

  void _startScanning() {
    setState(() {
      _currentState = LinkState.scanning;
    });
    // Simula el enfoque de cámara; al "leer el QR" valida el número de serie que
    // el instalador escribió/escaneó. El QR del equipo codifica la serie.
    _simulationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _currentState == LinkState.scanning) {
        _startValidation(_macController.text.trim());
      }
    });
  }

  /// Diagnóstico REAL por número de serie: lee la telemetría del equipo y pinta
  /// cada prueba. La tierra física no tiene telemetría → la confirma el instalador.
  Future<void> _startValidation(String serie) async {
    _simulationTimer?.cancel();
    final s = serie.trim();
    if (s.isEmpty) {
      setState(() => _currentState = LinkState.input);
      _triggerBanner(false, "Ingresa o escanea el número de serie del equipo");
      return;
    }
    setState(() {
      _currentState = LinkState.validating;
      _isLoading = true;
      _showBanner = false;
      _bateriaStatus = 'Gris'; // alto voltaje / cerca
      _redLteStatus = 'Gris'; // batería auxiliar
      _retornoStatus = 'Gris'; // conexión a línea
    });

    final result = await sl.get<OrdenesRepository>().diagnosticoEnergizador(s);
    if (!mounted) return;
    result.fold((d) {
      setState(() {
        _isLoading = false;
        if (d['encontrado'] != true) {
          _retornoStatus = 'Rojo';
          _triggerBanner(false, "No se encontró un equipo con la serie \"$s\"");
          return;
        }
        _macDetectada = (d['mac'] ?? '').toString();
        // Telemetría real -> estado de cada prueba.
        _retornoStatus = d['conexionLinea'] == true ? 'Verde' : 'Rojo'; // energía de la calle
        _redLteStatus = d['bateria'] == 'ok'
            ? 'Verde'
            : (d['bateria'] == 'baja' ? 'Rojo' : 'Gris');
        _bateriaStatus = d['cercaActiva'] == true ? 'Verde' : 'Rojo'; // cerca energizada
        final ok = _retornoStatus == 'Verde' &&
            _redLteStatus == 'Verde' &&
            _bateriaStatus == 'Verde';
        _triggerBanner(ok, ok ? "Diagnóstico del equipo exitoso" : "Hay pruebas en rojo, revisa el equipo");
      });
    }, (f) {
      setState(() {
        _isLoading = false;
        _triggerBanner(false, "No se pudo leer el equipo: ${f.message}");
      });
    });
  }

  /// Tierra física: confirmación manual del instalador (sin telemetría).
  void _toggleTierra() {
    setState(() => _tierraStatus = _tierraStatus == 'Verde' ? 'Gris' : 'Verde');
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
    final result = await sl.get<OrdenesRepository>().vincularEnergizador(
          id,
          codigo: _macDetectada.isNotEmpty ? _macDetectada : serie,
          serie: serie,
        );
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'device_linked'),
      (failure) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo vincular el energizador: ${failure.message}")),
        );
      },
    );
  }

  bool get _allCompleted =>
      _tierraStatus == 'Verde' &&
      _bateriaStatus == 'Verde' &&
      _redLteStatus == 'Verde' &&
      _retornoStatus == 'Verde';

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
                if (_currentState != LinkState.scanning)
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
                          child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              color: theme.iconTheme.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Back chevron and Centered Title Row
                if (_currentState != LinkState.scanning)
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
                              _currentState == LinkState.input ? "Vincular energizador" : "Vincular energizador",
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

                // State Content
                Expanded(
                  child: _buildStateContent(context),
                ),
              ],
            ),
          ),

          // Banner notification at the top (under SafeArea)
          if (_currentState != LinkState.scanning) _buildNotificationBanner(),

          // Shared bottom navigation bar
          if (_currentState != LinkState.scanning) const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStateContent(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;

    switch (_currentState) {
      case LinkState.input:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            Text(
              "Escanear QR",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Escanea el QR que se encuentra en el energizador ohmsafe",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),

            // QR Illustration Box with horizontal scan line
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mock QR Image/Icon
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 130,
                      color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                    ),
                    // Red/Orange Scan Line moving vertically or static
                    Positioned(
                      left: 15,
                      right: 15,
                      child: Container(
                        height: 2,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              "Asegúrate de que el energizador esté encendido y mantente cerca del equipo para iniciar la vinculación",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),

            // Input número de serie del equipo
            TextField(
              controller: _macController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: "Número de serie del equipo",
                labelStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                hintText: "Ej: OHM-XXXX-XXXX (o escanéalo del QR)",
                filled: true,
                fillColor: ohm.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Actions: Scan QR or Cancel
            OhmGradientButton(
              label: "Escanear QR",
              onPressed: _startScanning,
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => showCancellationFlow(context, widget.ticket),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Cancelar instalación",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );

      case LinkState.scanning:
        // Simulated viewfinder camera interface
        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark camera background representing viewfinder
            Container(
              color: Colors.black,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mock physical energizer image outline
                    Icon(
                      Icons.settings_input_component_rounded,
                      size: 200,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    // Tap to scan text
                    Positioned(
                      bottom: 40,
                      child: Text(
                        "Pulsar pantalla para simular escaneo",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Camera Viewfinder Controls
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.flash_off_rounded, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                  const Text(
                    "Cámara",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _currentState = LinkState.input;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Zoom indicator
            Positioned(
              bottom: 120,
              left: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "2x",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Flash bottom trigger
            Positioned(
              bottom: 110,
              right: 30,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ),

            // Circular shutter button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _startValidation("MAC-99:A1:B2:C3:FF"),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Simulated Dialog Overlay: Camera Permissions
            Positioned(
              top: 100,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Permisos de cámara",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Se han concedido los permisos correctamente.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case LinkState.validating:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            Text(
              "¡Vinculación exitosa!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "El Sistema OhmSafe ha sido vinculado",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Section: Pruebas del sistema
            Text(
              "PRUEBAS DEL SISTEMA",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // 4 Indicators
            // Tierra física: sin telemetría en esta versión → check manual
            // obligatorio del instalador; control de calidad lo valida después.
            GestureDetector(
              onTap: _toggleTierra,
              behavior: HitTestBehavior.opaque,
              child: _buildTestIndicatorRow(
                "Instalación de tierra física",
                _tierraStatus,
                errorSubtitle: _tierraStatus != 'Verde'
                    ? "Toca para confirmar que la realizaste (control de calidad la validará)"
                    : null,
              ),
            ),
            _buildTestIndicatorRow("Prueba de alto voltaje exitosa", _bateriaStatus),
            _buildTestIndicatorRow("Conexión de batería auxiliar", _redLteStatus),
            _buildTestIndicatorRow(
              "Verificación de conexión a línea",
              _retornoStatus,
              errorSubtitle: _retornoStatus == 'Rojo'
                  ? "El equipo no recibe energía de la línea eléctrica"
                  : null,
            ),
            const SizedBox(height: 16),

            // Energizer Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow("Estado de la cerca", "Activa"),
                  const SizedBox(height: 8),
                  _buildDetailRow("Conexión Wi-Fi", "En línea"),
                  const SizedBox(height: 8),
                  _buildDetailRow("Red de soporte SIM", "Activa"),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Main CTA Button
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              )
            else ...[
              OhmGradientButton(
                label: "Continuar con cierre de instalación",
                onPressed: (_allCompleted && !_isSending) ? _vincularEnergizador : null,
              ),
              const SizedBox(height: 12),

              // Retry Button (shown if one fails)
              if (_retornoStatus == 'Rojo') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startValidation(_macController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Reintentar validación",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Report Incidences / Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showCancellationFlow(context, widget.ticket),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyLarge?.color,
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Reportar incidencias (opcional)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        );
    }
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

  Widget _buildDetailRow(String key, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$key:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBanner() {
    if (!_showBanner) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    final bannerBg = _bannerIsSuccess
        ? (isDark ? cs.surface : ohm.successContainer)
        : (isDark ? cs.surface : cs.errorContainer);
    final bannerBorder = _bannerIsSuccess
        ? ohm.success
        : (isDark ? cs.onErrorContainer : cs.error);
    final bannerTextColor = _bannerIsSuccess
        ? (isDark ? Colors.white : ohm.onSuccessContainer)
        : (isDark ? Colors.white : cs.onErrorContainer);

    return Positioned(
      top: 64,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bannerBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _bannerIsSuccess ? ohm.success : cs.error,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _bannerIsSuccess ? Icons.check : Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _bannerText,
                style: TextStyle(
                  color: bannerTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
