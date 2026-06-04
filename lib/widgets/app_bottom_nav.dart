import 'package:flutter/material.dart';
import '../screens/help_screen.dart';

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
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, Icons.person_outline_rounded, "Perfil", currentTab == "Perfil"),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(context, Icons.home_filled, "Home", currentTab == "Home"),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(context, Icons.help_outline_rounded, "Ayuda", currentTab == "Ayuda"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected) {
    final color = isSelected ? const Color(0xFFFF5A00) : Colors.white;
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
        } else if (label == "Perfil" && currentTab != "Perfil") {
          // El perfil es parte de la pantalla de Home
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}