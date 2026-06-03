import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

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
            _buildNavItem(Icons.person_outline_rounded, "Perfil", false),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(Icons.home_filled, "Home", true),
            const VerticalDivider(width: 1, color: Colors.white12, indent: 15, endIndent: 15),
            _buildNavItem(Icons.help_outline_rounded, "Ayuda", false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    final color = isSelected ? const Color(0xFFFF5A00) : Colors.white;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}