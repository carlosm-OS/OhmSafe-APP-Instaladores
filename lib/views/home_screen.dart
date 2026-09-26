import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/menu_item_tile.dart';
import 'instalaciones_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;

  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orangeAccent = const Color(0xFFFF5A00);
    final state = AppStateProvider.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Centered Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Centered Logo Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "OHM",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: theme.textTheme.bodyLarge?.color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                "SAFE",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: orangeAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right Side Bell Action
                        Positioned(
                          right: 0,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: onToggleTheme,
                                icon: Icon(
                                  isDark ? Icons.light_mode : Icons.dark_mode,
                                  size: 20,
                                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Buzón de notificaciones de OhmSafe"),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.notifications,
                                  size: 24,
                                  color: const Color(0xFF475569).withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // SERVICIO TÉCNICO Centered Subtitle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      "SERVICIO TÉCNICO",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8).withOpacity(0.9),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),

                // Center Installer Profile Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 28),
                    child: Column(
                      children: [
                        const AvatarHalo(
                          size: 112,
                          initials: "JM",
                        ),
                        const SizedBox(height: 14),
                        Text(
                          state.installerName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.bodyLarge?.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${state.installerRole} ${state.numeroVisible}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Standalone Category Cards List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      MenuItemTile(
                        label: "Instalaciones",
                        count: state.instalacionesCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InstalacionesScreen(),
                            ),
                          );
                        },
                      ),
                      MenuItemTile(
                        label: "Reparaciones",
                        count: state.reparacionesCount,
                        onTap: () => _showComingSoon(context, "Reparaciones"),
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
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),

          // Custom Premium Bottom Bar exactly matching the layout of the screenshot
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 76,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Perfil Tab
                  _buildNavItem(Icons.person, "Perfil", false),
                  _buildVerticalDivider(),
                  // Home Tab (Active Orange)
                  _buildNavItem(Icons.home_filled, "Home", true),
                  _buildVerticalDivider(),
                  // Ayuda Tab
                  _buildNavItem(Icons.help_outline_rounded, "Ayuda", false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Navegando a: $moduleName (Modulo prototipado)"),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final orangeAccent = const Color(0xFFFF5A00);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? orangeAccent : Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? orangeAccent : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white24,
    );
  }
}
