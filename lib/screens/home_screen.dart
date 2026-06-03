import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import 'instalaciones_screen.dart';
import '../widgets/app_bottom_nav.dart';

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
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                          border: Border.all(color: theme.dividerColor, width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/assets/avatar.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.network(
                              'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=150&auto=format&fit=crop&q=60',
                              fit: BoxFit.cover,
                            ),
                          ),
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
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: Column(
                          children: [
                            _buildMenuTile(context, label: "Instalaciones", count: state.instalacionesCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstalacionesScreen())), showDivider: true),
                            _buildMenuTile(context, label: "Reparaciones", count: state.reparacionesCount, onTap: () => _showComingSoon(context, "Reparaciones"), showDivider: true),
                            _buildMenuTile(context, label: "Mantenimientos", count: state.mantenimientosCount, onTap: () => _showComingSoon(context, "Mantenimientos"), showDivider: true),
                            _buildMenuTile(context, label: "Reemplazo de equipo", count: state.reemplazoCount, onTap: () => _showComingSoon(context, "Reemplazo de equipo"), showDivider: false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        child: _buildMenuTile(context, label: "Reportar incidencias", count: state.incidenciasCount, onTap: () => _showComingSoon(context, "Reportar incidencias"), showDivider: false),
                      ),
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

  Widget _buildMenuTile(BuildContext context, {required String label, required int count, required VoidCallback onTap, required bool showDivider}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8))),
                Row(
                  children: [
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                        child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(width: 12),
                    Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.5), size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: theme.dividerColor, indent: 24, endIndent: 24)
      ],
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Navegando a: $title"), duration: const Duration(seconds: 1)));
  }
}