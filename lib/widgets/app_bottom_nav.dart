import 'dart:ui';

import '../core/teclado/teclado.dart';
import 'package:flutter/material.dart';
import '../screens/help_screen.dart';
import '../screens/profile_main_screen.dart';
import '../screens/historial_screen.dart';

/// Barra de pestañas v2 (2026-10-23): translúcida, pegada abajo y a todo lo ancho, como en iPhone (antes
/// una barra negra flotante). Sólo vive en las pantallas raíz; dentro del flujo de instalación no hay
/// barra, para que «Home» no saque al técnico a media prueba o firma.
class AppBottomNav extends StatelessWidget {
  final String currentTab;
  const AppBottomNav({super.key, this.currentTab = "Home"});

  @override
  Widget build(BuildContext context) {
    // Con el teclado abierto se oculta: no se navega a media captura y el campo queda a la vista. Ojo:
    // dentro del Scaffold `MediaQuery.viewInsets` llega en 0; por eso se pregunta a TecladoScope.
    if (TecladoScope.abiertoEn(context)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.86),
              border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    _item(context, Icons.person_outline_rounded, Icons.person_rounded, "Mi cuenta", currentTab == "Perfil"),
                    _item(context, Icons.home_outlined, Icons.home_rounded, "Home", currentTab == "Home"),
                    _item(context, Icons.history_rounded, Icons.history_rounded, "Historial", currentTab == "Historial"),
                    _item(context, Icons.help_outline_rounded, Icons.help_rounded, "Ayuda", currentTab == "Ayuda"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _ir(BuildContext context, String label) {
    if (label == "Ayuda" && currentTab != "Ayuda") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
    } else if (label == "Home" && currentTab != "Home") {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (label == "Historial" && currentTab != "Historial") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialScreen()));
    } else if (label == "Mi cuenta" && currentTab != "Perfil") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileMainScreen()));
    }
  }

  Widget _item(BuildContext context, IconData icono, IconData iconoActivo, String label, bool activo) {
    final cs = Theme.of(context).colorScheme;
    final color = activo ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: activo,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => _ir(context, label),
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(activo ? iconoActivo : icono, color: color, size: 26),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
