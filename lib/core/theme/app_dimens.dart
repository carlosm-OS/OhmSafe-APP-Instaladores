// =============================================================================
// OhmSafe · Sistema de tema — Dimensiones (dirección "Faena")
// -----------------------------------------------------------------------------
// Tokens de espaciado, radios, bordes, elevación y áreas táctiles.
// Regla de exterior: alto contraste + touch grande + BORDES en vez de sombras
// (bajo sol directo las sombras se lavan y dejan de comunicar jerarquía).
// =============================================================================

import 'package:flutter/widgets.dart';

/// Escala de espaciado base-4 (densidad estándar 6/10). Usar SIEMPRE estos
/// valores en lugar de números mágicos para mantener el ritmo vertical.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // unidad base de layout
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios de esquina. Medios (sólidos pero amables) — la dirección "Faena"
/// evita tanto lo demasiado redondo (juguete) como lo cuadrado (brutalista).
abstract final class AppRadius {
  static const double xs = 8; // chips, badges
  static const double sm = 12; // inputs, chips grandes
  static const double md = 16; // tarjetas, botones
  static const double lg = 20; // contenedores destacados
  static const double xl = 28; // bottom sheets, diálogos
  static const double pill = 999; // FAB extendido, toggles

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);

  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
}

/// Grosores de borde. En "Faena" el borde reemplaza a la sombra como señal
/// de contención, porque sobrevive al sol directo.
abstract final class AppBorders {
  static const double hairline = 1; // separadores, tarjetas en reposo
  static const double regular = 1.5; // inputs
  static const double strong = 2; // foco, estado activo, seleccionado
}

/// Elevaciones. Deliberadamente bajas: el sistema comunica con borde y color,
/// no con sombra. Se conservan tokens por si se necesita profundidad puntual
/// (menús, sheets) en interiores.
abstract final class AppElevation {
  static const double none = 0;
  static const double raised = 1; // hover/pressed sutil
  static const double overlay = 3; // menús, tooltips
  static const double sheet = 8; // bottom sheets, diálogos
}

/// Áreas táctiles. Mínimo WCAG 48px; el botón primario sube a 56px para uso
/// con guantes al aire libre.
abstract final class AppTouch {
  static const double min = 48; // mínimo absoluto (iconos, chips)
  static const double primary = 56; // botón de acción principal
  static const double comfortable = 64; // filas de lista accionables
}
