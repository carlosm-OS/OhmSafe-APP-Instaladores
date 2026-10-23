// =============================================================================
// OhmSafe · Sistema de tema — Paleta primitiva (dirección "Faena")
// -----------------------------------------------------------------------------
// Sistema v2 (2026-10-23, lienzo «Sistema v2 · minimalista»): grupos blancos sobre gris claro,
// tinta casi negra, gris de apoyo con 5:1, un solo naranja y sin segundo naranja suelto.
// Valores crudos (tokens primitivos). NO usar directamente en widgets: se
// consumen a través de ColorScheme y de OhmColors (app_theme_extension.dart).
// Contraste verificado para exterior: la tinta principal sobre fondo supera
// ~13:1; texto sobre naranja usa peso bold (≥3:1, AA para texto grande).
// =============================================================================

import 'dart:ui';

/// Marca OhmSafe — naranja. Constante en ambos modos (identidad).
abstract final class OhmBrand {
  static const Color orange = Color(0xFFFF5A00); // primario
  static const Color orangeBright = Color(0xFFFF6B1A); // primario en dark (glow)
  static const Color orangeSoft = Color(0xFFFF8D28); // secundario
  static const Color orangeDeep = Color(0xFF7A2A00); // texto sobre container claro
}

/// Paleta modo claro — el "workhorse" de exterior.
abstract final class LightPalette {
  // Superficies (frías, casi blancas, para máxima reflectancia legible)
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFEEEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE5E5EA);

  // Tinta (slate reforzado a casi negro para sol directo)
  static const Color onSurface = Color(0xFF1D1D1F);
  static const Color onSurfaceVariant = Color(0xFF6E6E73);

  // Bordes / líneas
  static const Color outline = Color(0xFF8E8E93);
  static const Color outlineVariant = Color(0xFFE3E3E8);

  // Marca
  static const Color primary = OhmBrand.orange;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFF1E8);
  static const Color onPrimaryContainer = Color(0xFF9A3412); // texto sobre naranja claro (7:1)

  static const Color secondary = OhmBrand.orange; // v2: un solo naranja
  static const Color onSecondary = Color(0xFF3D1600);
  static const Color secondaryContainer = Color(0xFFFFEEDD);
  static const Color onSecondaryContainer = Color(0xFF5A2400);

  // Semánticos
  static const Color success = Color(0xFF15803D);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFE8F7EE);
  static const Color onSuccessContainer = Color(0xFF14532D);

  static const Color warning = Color(0xFFB45309);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF451A03);

  static const Color danger = Color(0xFFDC2626);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color dangerContainer = Color(0xFFFEE2E2);
  static const Color onDangerContainer = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF2563EB);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFEAF1FE);
  static const Color onInfoContainer = Color(0xFF1E3A8A);

  // Accent (púrpura) — categorías especiales (p.ej. "Reemplazo de equipo").
  static const Color accent = Color(0xFF7C3AED);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color(0xFFEDE9FE);
  static const Color onAccentContainer = Color(0xFF4C1D95);

  // Inverse — pill/segmento seleccionado (oscuro sobre claro).
  static const Color inverseSurface = Color(0xFF1D1D1F);
  static const Color onInverseSurface = Color(0xFFF5F5F7);
}

/// Paleta modo oscuro — penumbra genuina (anochecer / interior).
abstract final class DarkPalette {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceContainer = Color(0xFF2C2C2E);
  static const Color surfaceContainerHigh = Color(0xFF3A3A3C);

  static const Color onSurface = Color(0xFFF5F5F7);
  static const Color onSurfaceVariant = Color(0xFFA1A1A6);

  static const Color outline = Color(0xFF7C7C82);
  static const Color outlineVariant = Color(0xFF38383A);

  static const Color primary = OhmBrand.orangeBright;
  static const Color onPrimary = Color(0xFF2A0E00);
  static const Color primaryContainer = Color(0xFF3D1600);
  static const Color onPrimaryContainer = Color(0xFFFFD9C2);

  static const Color secondary = OhmBrand.orangeBright; // v2: un solo naranja
  static const Color onSecondary = Color(0xFF3D1600);
  static const Color secondaryContainer = Color(0xFF5A2400);
  static const Color onSecondaryContainer = Color(0xFFFFE0C7);

  static const Color success = Color(0xFF22C55E);
  static const Color onSuccess = Color(0xFF052E16);
  static const Color successContainer = Color(0xFF14532D);
  static const Color onSuccessContainer = Color(0xFFBBF7D0);

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Color(0xFF3D1D00);
  static const Color warningContainer = Color(0xFF713F12);
  static const Color onWarningContainer = Color(0xFFFDE68A);

  static const Color danger = Color(0xFFF87171);
  static const Color onDanger = Color(0xFF450A0A);
  static const Color dangerContainer = Color(0xFF7F1D1D);
  static const Color onDangerContainer = Color(0xFFFECACA);

  static const Color info = Color(0xFF38BDF8);
  static const Color onInfo = Color(0xFF042F49);
  static const Color infoContainer = Color(0xFF075985);
  static const Color onInfoContainer = Color(0xFFBAE6FD);

  // Accent (púrpura) — categorías especiales (p.ej. "Reemplazo de equipo").
  static const Color accent = Color(0xFFA78BFA);
  static const Color onAccent = Color(0xFF2E1065);
  static const Color accentContainer = Color(0xFF4C1D95);
  static const Color onAccentContainer = Color(0xFFEDE9FE);

  // Inverse — pill/segmento seleccionado (claro sobre oscuro).
  static const Color inverseSurface = Color(0xFFF5F5F7);
  static const Color onInverseSurface = Color(0xFF1D1D1F);
}
