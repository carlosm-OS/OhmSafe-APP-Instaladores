import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import 'instalaciones_screen.dart';
import 'incidencias_screen.dart';
import 'cotizaciones_screen.dart';
// import 'reparaciones_screen.dart'; // oculto en el MVP, ver tiles comentados abajo
import 'profile_main_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/menu_item_tile.dart';


class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  /// true justo tras el onboarding: muestra un aviso para subir la foto de perfil.
  final bool promptFoto;

  const HomeScreen({super.key, required this.onToggleTheme, this.promptFoto = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    // (La invitación «Sube tu foto de perfil» se retiró: la foto la sube OhmSafe en Odoo.)
    // Sincroniza los badges con las asignaciones reales del backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateProvider.of(context).refreshBadges();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar (Logo Centrado, Iconos Derecha)
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
                            Text("OHM", style: TextStyle(fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color)),
                            Text("SAFE", style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: widget.onToggleTheme,
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
                            ),
                            const NotificationBell(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Centered Screen Title Section
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    "SERVICIO",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
                
                // Profile Block
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProfileMainScreen(onToggleTheme: widget.onToggleTheme)),
                        ),
                        child: AvatarHalo(
                          size: 112,
                          initials: initialsFromName(state.installerName),
                          imagePath: state.customAvatarPath,
                          imageBase64: state.fotoBase64,
                          placeholderIcon: Icons.engineering_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(state.installerName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(height: 2),
                      Text("${state.installerRole} #${state.numeroVisible}", style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                    ],
                  ),
                ),

                // Main Options List Card
                 Expanded(
                  // Jalar hacia abajo vuelve a pedir los contadores al backend.
                  // Sin esto, un ticket que cambia en Odoo no se refleja hasta
                  // cerrar y reabrir la app.
                  child: RefreshIndicator(
                    onRefresh: () => AppStateProvider.of(context).refreshBadges(),
                    color: cs.primary,
                    child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    // AlwaysScrollable: el gesto debe funcionar aunque la lista
                    // no llegue a desbordar la pantalla.
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      MenuItemTile(
                        label: "Instalaciones",
                        count: state.instalacionesCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InstalacionesScreen()),
                        ),
                      ),
                      // MVP (2026-09-18): solo Instalaciones y Reportar incidencias.
                      // Reparaciones, Mantenimientos y Reemplazo de equipo quedan
                      // ocultos hasta la siguiente version; se construyen uno a uno.
                      // Para reactivar un modulo basta descomentar su tile (y el
                      // import de reparaciones_screen.dart). Ver
                      // docs/ESTADO-INSTALADORES.md > "Pendientes priorizados".
                      // MenuItemTile(
                      //   label: "Reparaciones",
                      //   count: state.reparacionesCount,
                      //   onTap: () => Navigator.push(
                      //     context,
                      //     MaterialPageRoute(builder: (_) => const ReparacionesScreen()),
                      //   ),
                      // ),
                      // Fase 4 (2026-09-25): los mantenimientos son intervenciones de
                      // Planificación con producto de mantenimiento; misma lista, otro filtro.
                      MenuItemTile(
                        label: "Mantenimientos",
                        count: state.mantenimientosCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InstalacionesScreen(tipo: 'mantenimiento', titulo: 'Mantenimientos')),
                        ),
                      ),
                      // MenuItemTile(
                      //   label: "Reemplazo de equipo",
                      //   count: state.reemplazoCount,
                      //   onTap: () => _showComingSoon(context, "Reemplazo de equipo"),
                      // ),
                      MenuItemTile(
                        label: "Reportar incidencias",
                        count: state.incidenciasCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const IncidenciasScreen()),
                        ),
                      ),
                      // Fase 5 (2026-09-25): el instalador cotiza en campo; la venta
                      // nace en Odoo atribuida a él y el cliente paga en el portal.
                      MenuItemTile(
                        label: "Cotizar venta",
                        count: 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CotizacionesScreen()),
                        ),
                      ),
                      const SizedBox(height: 100), // Extra space to scroll above the bottom nav
                    ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Navigation Bar
          const AppBottomNav(), 
        ], // <--- ESTE CORCHETE CIERRA EL CHILDREN DEL STACK
      ), // <--- ESTE CIERRA EL STACK
    ); // <--- ESTE CIERRA EL SCAFFOLD
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Navegando a: $title"), duration: const Duration(seconds: 1)));
  }
}