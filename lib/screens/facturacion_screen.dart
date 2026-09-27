import 'package:flutter/material.dart';
import '../widgets/notification_bell.dart';
import 'dart:ui';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';

class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({super.key});

  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  bool _stateLoaded = false;

  final TextEditingController _rfcController = TextEditingController();
  bool _savingRfc = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_stateLoaded) {
      _stateLoaded = true;
      _cargarPerfil(); // espejo Odoo→app: RFC actual de Odoo
    }
  }

  @override
  void dispose() {
    _rfcController.dispose();
    super.dispose();
  }

  /// Lee el perfil de Odoo para reflejar el RFC.
  Future<void> _cargarPerfil() async {
    final result = await sl.get<PerfilRepository>().getPerfil();
    if (!mounted) return;
    result.fold((perfil) {
      setState(() {
        _rfcController.text = perfil.rfc;
      });
    }, (_) {});
  }

  /// Guarda el RFC en Odoo (campo fiscal nativo `vat`).
  Future<void> _guardarRfc() async {
    if (_savingRfc) return;
    setState(() => _savingRfc = true);
    final result = await sl.get<PerfilRepository>().updatePerfil(rfc: _rfcController.text.trim());
    if (!mounted) return;
    setState(() => _savingRfc = false);
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("RFC guardado"), backgroundColor: Theme.of(context).colorScheme.primary),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo guardar el RFC: ${failure.message}"), backgroundColor: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    // Color system
    final labelColor = cs.onSurfaceVariant;
    final fillColor = ohm.surfaceContainer;

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
      color: labelColor,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Logo and Notification Bell
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
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            const NotificationBell(),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            "Facturación",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
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

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtitle: Facturación
                        Center(
                          child: Text(
                            "Facturación",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // RFC — campo fiscal (se guarda en Odoo como `vat`)
                        Text("RFC", style: labelStyle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(14)),
                                child: TextField(
                                  controller: _rfcController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    hintText: "Tu RFC",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // El tamaño se fija con `minimumSize`, NO envolviendo
                            // el botón en un SizedBox: dentro de un Row los hijos
                            // sin flex reciben ancho infinito para medirse, el
                            // SizedBox se lo pasaba al ElevatedButton y este no
                            // admite ancho infinito. Esa excepción tumbaba el
                            // layout de TODA la pantalla y la dejaba en blanco.
                            ElevatedButton(
                              onPressed: _savingRfc ? null : _guardarRfc,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(112, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _savingRfc
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar overlay
          const AppBottomNav(currentTab: "Perfil"),
        ],
      ),
    );
  }
}
