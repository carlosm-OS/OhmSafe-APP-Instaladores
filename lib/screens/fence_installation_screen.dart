import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/cancellation_flow.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

class FenceInstallationScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const FenceInstallationScreen({super.key, required this.ticket});

  @override
  State<FenceInstallationScreen> createState() => _FenceInstallationScreenState();
}

class _FenceInstallationScreenState extends State<FenceInstallationScreen> {
  // Counters for materials with default initial values matching the mock image (5, 5, 5, 5, 1, 3)
  final Map<String, int> _materials = {
    'Postes esquina': 5,
    'Postes de paso': 5,
    'Líneas': 5,
    'Abanicos': 5,
    'Letrero Ohmsafe': 1,
    'Letrero Precaución': 3,
  };

  void _increment(String material) {
    setState(() {
      _materials[material] = (_materials[material] ?? 0) + 1;
    });
  }

  void _decrement(String material) {
    setState(() {
      final current = _materials[material] ?? 0;
      if (current > 0) {
        _materials[material] = current - 1;
      }
    });
  }

  bool _isSending = false;

  /// Envía el registro de instalación al backend: los conteos con columna propia
  /// en Odoo (postes/abanicos) más el desglose completo de materiales. Solo si
  /// tiene éxito regresa 'installation_completed' para avanzar el flujo.
  Future<void> _guardarInstalacion() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    final registro = <String, dynamic>{
      'postesEsquina': _materials['Postes esquina'],
      'postesPaso': _materials['Postes de paso'],
      'abanicos': _materials['Abanicos'],
      'materiales': _materials,
    };
    final id = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    final result = await sl.get<OrdenesRepository>().guardarInstalacion(id, registro);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'installation_completed'),
      (failure) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la instalación: ${failure.message}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final details = widget.ticket["details"] as Map<String, String>;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Logo centrado, icono notificaciones derecha)
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

                // Back arrow and Centered Title
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
                            "Instalación de cerca eléctrica",
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
                            onPressed: () => Navigator.pop(context),
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

                // Main scrollable list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Client info card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Cliente:  ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.ticket["user"] ?? "Cliente",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Metros a instalar:  ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Text(
                                  details["metraje"] ?? "0m",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Title
                      Text(
                        "CONTEO DE MATERIALES",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Materials Counter Cards
                      ..._materials.keys.map((material) {
                        final val = _materials[material] ?? 0;
                        return _buildMaterialRow(material, val);
                      }),

                      const SizedBox(height: 32),

                      // Submit: Completar instalación
                      OhmGradientButton(
                        label: "Completar instalación",
                        icon: Icons.arrow_forward,
                        onPressed: _isSending ? null : _guardarInstalacion,
                      ),
                      const SizedBox(height: 12),

                      // Cancel button calling shared sheet
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildMaterialRow(String name, int value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? cs.surface.withValues(alpha: 0.5) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Name
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Custom premium segmented counter
            Container(
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus Button
                  GestureDetector(
                    onTap: value > 0 ? () => _decrement(name) : null,
                    child: Container(
                      width: 32,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: ohm.surfaceContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "-",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: value > 0
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white30 : Colors.black26),
                        ),
                      ),
                    ),
                  ),
                  // Value
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      "$value",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  // Plus Button
                  GestureDetector(
                    onTap: () => _increment(name),
                    child: Container(
                      width: 32,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "+",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
