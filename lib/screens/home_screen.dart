import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import 'instalaciones_screen.dart';
import 'reparaciones_screen.dart';
import 'profile_main_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/menu_item_tile.dart';


class HomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;

  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                            const Text("SAFE", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5A00))),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: onToggleTheme,
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: theme.iconTheme.color?.withOpacity(0.7)),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.notifications_none_rounded, color: theme.iconTheme.color?.withOpacity(0.7)),
                            ),
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
                          MaterialPageRoute(builder: (_) => const ProfileMainScreen()),
                        ),
                        child: AvatarHalo(
                          size: 112,
                          initials: "JM",
                          imagePath: state.customAvatarPath,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(state.installerName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(height: 2),
                      Text("${state.installerRole} ${state.installerId}", style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6))),
                    ],
                  ),
                ),

                // Main Options List Card
                 Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      MenuItemTile(
                        label: "Instalaciones",
                        count: state.instalacionesCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InstalacionesScreen()),
                        ),
                      ),
                      MenuItemTile(
                        label: "Reparaciones",
                        count: state.reparacionesCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReparacionesScreen()),
                        ),
                      ),
                      MenuItemTile(
                        label: "Mantenimientos",
                        count: state.mantenimientosCount,
                        onTap: () => _showComingSoon(context, "Mantenimientos"),
                      ),
                      MenuItemTile(
                        label: "Reemplazo de equipo",
                        count: state.reemplazoCount,
                        onTap: () => _showComingSoon(context, "Reemplazo de equipo"),
                      ),
                      MenuItemTile(
                        label: "Reportar incidencias",
                        count: state.incidenciasCount,
                        onTap: () => _showComingSoon(context, "Reportar incidencias"),
                      ),
                      const SizedBox(height: 100), // Extra space to scroll above the bottom nav
                    ],
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