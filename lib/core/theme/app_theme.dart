// =============================================================================
// OhmSafe · Sistema de tema — AppTheme (dirección "Faena", Material 3)
// -----------------------------------------------------------------------------
// Punto de entrada del tema. En main.dart:
//     MaterialApp(
//       theme: AppTheme.light,
//       darkTheme: AppTheme.dark,
//       themeMode: _themeMode,
//     )
//
// Tipografía (sistema v2, 2026-10-23): Inter 4.0 estática por peso + InterDisplay para títulos,
// empaquetadas en assets/fonts (sin red). Ver README del tema.
// =============================================================================

import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'package:flutter/services.dart';

import 'app_dimens.dart';
import 'app_palette.dart';
import 'app_theme_extension.dart';

/// Familias tipográficas (sistema v2, 2026-10-23): Inter estática por peso; InterDisplay para
/// títulos grandes. Espaciado por tamaño: lo grande se aprieta, lo chico se abre.
abstract final class AppTypography {
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? displayFamily = 'InterDisplay';
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? bodyFamily = 'Inter';
}

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: _lightScheme,
        ohm: OhmColors.light,
        scaffold: LightPalette.background,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: _darkScheme,
        ohm: OhmColors.dark,
        scaffold: DarkPalette.background,
      );

  // ---------------------------------------------------------------------------
  // ColorSchemes (construidos a mano para respetar el naranja de marca exacto)
  // ---------------------------------------------------------------------------
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: LightPalette.primary,
    onPrimary: LightPalette.onPrimary,
    primaryContainer: LightPalette.primaryContainer,
    onPrimaryContainer: LightPalette.onPrimaryContainer,
    secondary: LightPalette.secondary,
    onSecondary: LightPalette.onSecondary,
    secondaryContainer: LightPalette.secondaryContainer,
    onSecondaryContainer: LightPalette.onSecondaryContainer,
    error: LightPalette.danger,
    onError: LightPalette.onDanger,
    errorContainer: LightPalette.dangerContainer,
    onErrorContainer: LightPalette.onDangerContainer,
    surface: LightPalette.surface,
    onSurface: LightPalette.onSurface,
    surfaceContainerHighest: LightPalette.surfaceContainerHigh,
    onSurfaceVariant: LightPalette.onSurfaceVariant,
    outline: LightPalette.outline,
    outlineVariant: LightPalette.outlineVariant,
    inverseSurface: LightPalette.inverseSurface,
    onInverseSurface: LightPalette.onInverseSurface,
    inversePrimary: LightPalette.primaryContainer,
    surfaceTint: Colors.transparent, // sin tinte M3: superficies planas
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: DarkPalette.primary,
    onPrimary: DarkPalette.onPrimary,
    primaryContainer: DarkPalette.primaryContainer,
    onPrimaryContainer: DarkPalette.onPrimaryContainer,
    secondary: DarkPalette.secondary,
    onSecondary: DarkPalette.onSecondary,
    secondaryContainer: DarkPalette.secondaryContainer,
    onSecondaryContainer: DarkPalette.onSecondaryContainer,
    error: DarkPalette.danger,
    onError: DarkPalette.onDanger,
    errorContainer: DarkPalette.dangerContainer,
    onErrorContainer: DarkPalette.onDangerContainer,
    surface: DarkPalette.surface,
    onSurface: DarkPalette.onSurface,
    surfaceContainerHighest: DarkPalette.surfaceContainerHigh,
    onSurfaceVariant: DarkPalette.onSurfaceVariant,
    outline: DarkPalette.outline,
    outlineVariant: DarkPalette.outlineVariant,
    inverseSurface: DarkPalette.inverseSurface,
    onInverseSurface: DarkPalette.onInverseSurface,
    inversePrimary: DarkPalette.primaryContainer,
    surfaceTint: Colors.transparent,
  );

  // ---------------------------------------------------------------------------
  // Constructor común
  // ---------------------------------------------------------------------------
  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required OhmColors ohm,
    required Color scaffold,
  }) {
    final textTheme = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: AppTypography.bodyFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[ohm],
      // Entre pantallas: fundido + 3 % desde la derecha, como GO (2026-10-20); en iPhone la nativa con
      // su gesto de regresar desde el borde (2026-10-23).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.iOS: OhmIosPageTransitionsBuilder(), TargetPlatform.android: OhmPageTransitionsBuilder(), TargetPlatform.macOS: OhmPageTransitionsBuilder()},
      ),

      // --- AppBar: superficie plana, borde inferior en scroll -----------------
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.raised,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge,
      ),

      // --- Botón primario: 56px, sin sombra, radio md, texto bold -------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: AppElevation.none,
          minimumSize: const Size.fromHeight(AppTouch.primary),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(AppTouch.primary),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // --- Botón secundario: contorno 2px, área táctil grande -----------------
      // v2: el secundario es gris relleno con tinta, sin borde (lienzo «Sistema v2», opción C).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: ohm.surfaceContainer,
          minimumSize: const Size.fromHeight(AppTouch.primary),
          side: BorderSide.none,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // --- Inputs: relleno, borde 1.5px, foco 2px naranja ---------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.primary, width: AppBorders.strong),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.error, width: AppBorders.regular),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: scheme.error, width: AppBorders.strong),
        ),
      ),

      // --- Tarjetas: SIN sombra, borde 1px (sobrevive al sol). En oscuro se
      //     usa un tier de superficie más alto para dar profundidad sutil.
      // v2: grupos blancos sobre gris, sin borde ni sombra.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      // --- Navegación inferior (≤5 destinos) ----------------------------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: AppElevation.none,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),

      // --- Chips --------------------------------------------------------------
      chipTheme: ChipThemeData(
        backgroundColor: ohm.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant, width: AppBorders.hairline),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      // --- Snackbar / toast ---------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: OhmBrand.orangeSoft,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      // --- Diálogos / bottom sheets ------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: AppElevation.sheet,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        // Lienzo de Carlos (2026-10-15): títulos de diálogo en 16 bold, sin Lexend (como el resto de
        // la pantalla). Estilo propio, no de `textTheme`: la Inter variable no engrosa en iOS desde ahí.
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        elevation: AppElevation.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadius.rXl),
        ),
        showDragHandle: true,
      ),

      // --- FAB: gradiente lo aplica el widget; base plana redonda -------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: AppElevation.raised,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        minVerticalPadding: AppSpacing.md,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: AppBorders.hairline,
        space: AppSpacing.lg,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s
                .contains(WidgetState.selected)
            ? scheme.primary
            : ohm.surfaceContainerHigh),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: ohm.surfaceContainer,
        circularTrackColor: ohm.surfaceContainer,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Escala tipográfica — base 16px, jerarquía fuerte para lectura exterior.
  // Tracking negativo en displays; labels con peso 700 para botones.
  // ---------------------------------------------------------------------------
  static TextTheme _textTheme(Color ink, Color muted) {
    const display = AppTypography.displayFamily;
    // Escala v2 (lienzo «Sistema v2»): 34/28/22 títulos, 17 cuerpo y filas, 15 apoyo, 13 notas.
    return TextTheme(
      displayLarge: TextStyle(fontFamily: display, fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.85, color: ink),
      displayMedium: TextStyle(fontFamily: display, fontSize: 30, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.75, color: ink),
      displaySmall: TextStyle(fontFamily: display, fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: ink),
      headlineLarge: TextStyle(fontFamily: display, fontSize: 26, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: ink),
      headlineMedium: TextStyle(fontFamily: display, fontSize: 22, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: ink),
      headlineSmall: TextStyle(fontFamily: display, fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: ink),
      titleLarge: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.25, color: ink),
      titleMedium: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: -0.25, color: ink),
      titleSmall: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: ink),
      bodyLarge: TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w400, letterSpacing: -0.2, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w400, letterSpacing: -0.1, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: muted),
      labelLarge: TextStyle(fontSize: 17, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: ink),
      labelMedium: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: ink),
      labelSmall: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w500, color: muted),
    );
  }
}
