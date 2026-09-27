// =============================================================================
// OhmSafe · Sistema de tema — Paleta primitiva (dirección "Faena")
// -----------------------------------------------------------------------------
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
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF1F3F6);
  static const Color surfaceContainerHigh = Color(0xFFE9EDF2);

  // Tinta (slate reforzado a casi negro para sol directo)
  static const Color onSurface = Color(0xFF14202E);
  static const Color onSurfaceVariant = Color(0xFF475569);

  // Bordes / líneas
  static const Color outline = Color(0xFFCBD5E1);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // Marca
  static const Color primary = OhmBrand.orange;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFE6D6);
  static const Color onPrimaryContainer = OhmBrand.orangeDeep;

  static const Color secondary = OhmBrand.orangeSoft;
  static const Color onSecondary = Color(0xFF3D1600);
  static const Color secondaryContainer = Color(0xFFFFEEDD);
  static const Color onSecondaryContainer = Color(0xFF5A2400);

  // Semánticos
  static const Color success = Color(0xFF166534);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF052E16);

  static const Color warning = Color(0xFFB45309);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF451A03);

  static const Color danger = Color(0xFFDC2626);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color dangerContainer = Color(0xFFFEE2E2);
  static const Color onDangerContainer = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF0369A1);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFE0F2FE);
  static const Color onInfoContainer = Color(0xFF0C4A6E);

  // Accent (púrpura) — categorías especiales (p.ej. "Reemplazo de equipo").
  static const Color accent = Color(0xFF7C3AED);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color(0xFFEDE9FE);
  static const Color onAccentContainer = Color(0xFF4C1D95);

  // Inverse — pill/segmento seleccionado (oscuro sobre claro).
  static const Color inverseSurface = Color(0xFF14202E);
  static const Color onInverseSurface = Color(0xFFF1F5F9);
}

/// Paleta modo oscuro — penumbra genuina (anochecer / interior).
abstract final class DarkPalette {
  static const Color background = Color(0xFF0B0F17);
  static const Color surface = Color(0xFF131926);
  static const Color surfaceContainer = Color(0xFF1A2130);
  static const Color surfaceContainerHigh = Color(0xFF222B3B);

  static const Color onSurface = Color(0xFFF1F5F9);
  static const Color onSurfaceVariant = Color(0xFF94A3B8);

  static const Color outline = Color(0xFF334155);
  static const Color outlineVariant = Color(0xFF26303F);

  static const Color primary = OhmBrand.orangeBright;
  static const Color onPrimary = Color(0xFF2A0E00);
  static const Color primaryContainer = Color(0xFF3D1600);
  static const Color onPrimaryContainer = Color(0xFFFFD9C2);

  static const Color secondary = OhmBrand.orangeSoft;
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
  static const Color inverseSurface = Color(0xFFE9EDF2);
  static const Color onInverseSurface = Color(0xFF14202E);
}
