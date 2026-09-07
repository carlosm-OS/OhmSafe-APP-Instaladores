import 'package:flutter/material.dart';
import '../screens/help_screen.dart';
import '../screens/profile_main_screen.dart';
import '../screens/historial_screen.dart';

class AppBottomNav extends StatelessWidget {
  final String currentTab;
  const AppBottomNav({super.key, this.currentTab = "Home"});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 20,
      right: 20,
      child: Container(
        height: 70, // Un poco más alto para acomodar el texto
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, Icons.person_outline_rounded, "Mi cuenta", currentTab == "Perfil"),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(context, Icons.home_filled, "Home", currentTab == "Home"),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(context, Icons.history_rounded, "Historial", currentTab == "Historial"),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(context, Icons.help_outline_rounded, "Ayuda", currentTab == "Ayuda"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected) {
    final cs = Theme.of(context).colorScheme;
    final color = isSelected ? cs.primary : Colors.white;
    return GestureDetector(
      onTap: () {
        if (label == "Ayuda" && currentTab != "Ayuda") {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HelpScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        } else if (label == "Home" && currentTab != "Home") {
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (label == "Historial" && currentTab != "Historial") {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HistorialScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        } else if (label == "Mi cuenta" && currentTab != "Perfil") {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ProfileMainScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}