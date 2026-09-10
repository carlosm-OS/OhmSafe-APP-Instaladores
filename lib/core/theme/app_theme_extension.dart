// =============================================================================
// OhmSafe · Sistema de tema — ThemeExtension de color semántico
// -----------------------------------------------------------------------------
// ColorScheme de Material 3 no tiene ranuras para success/warning/info ni para
// los tiers de superficie que usa "Faena". Este ThemeExtension los expone de
// forma tipada y con lerp() para animar el cambio light<->dark.
//
// Uso en widgets:
//   final ohm = Theme.of(context).extension<OhmColors>()!;
//   Container(color: ohm.success, ...)
//   // atajo:  context.ohm.success
// =============================================================================

import 'package:flutter/material.dart';

import 'app_palette.dart';

@immutable
class OhmColors extends ThemeExtension<OhmColors> {
  const OhmColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.brandGradient,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Acento púrpura para categorías especiales (no es color de marca).
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  /// Tiers de superficie por encima de [ColorScheme.surface] (tarjetas, fills).
  final Color surfaceContainer;
  final Color surfaceContainerHigh;

  /// Gradiente de marca (naranja) para acentos hero / FAB extendido.
  final Gradient brandGradient;

  static const OhmColors light = OhmColors(
    success: LightPalette.success,
    onSuccess: LightPalette.onSuccess,
    successContainer: LightPalette.successContainer,
    onSuccessContainer: LightPalette.onSuccessContainer,
    warning: LightPalette.warning,
    onWarning: LightPalette.onWarning,
    warningContainer: LightPalette.warningContainer,
    onWarningContainer: LightPalette.onWarningContainer,
    info: LightPalette.info,
    onInfo: LightPalette.onInfo,
    infoContainer: LightPalette.infoContainer,
    onInfoContainer: LightPalette.onInfoContainer,
    accent: LightPalette.accent,
    onAccent: LightPalette.onAccent,
    accentContainer: LightPalette.accentContainer,
    onAccentContainer: LightPalette.onAccentContainer,
    surfaceContainer: LightPalette.surfaceContainer,
    surfaceContainerHigh: LightPalette.surfaceContainerHigh,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [OhmBrand.orange, OhmBrand.orangeSoft],
    ),
  );

  static const OhmColors dark = OhmColors(
    success: DarkPalette.success,
    onSuccess: DarkPalette.onSuccess,
    successContainer: DarkPalette.successContainer,
    onSuccessContainer: DarkPalette.onSuccessContainer,
    warning: DarkPalette.warning,
    onWarning: DarkPalette.onWarning,
    warningContainer: DarkPalette.warningContainer,
    onWarningContainer: DarkPalette.onWarningContainer,
    info: DarkPalette.info,
    onInfo: DarkPalette.onInfo,
    infoContainer: DarkPalette.infoContainer,
    onInfoContainer: DarkPalette.onInfoContainer,
    accent: DarkPalette.accent,
    onAccent: DarkPalette.onAccent,
    accentContainer: DarkPalette.accentContainer,
    onAccentContainer: DarkPalette.onAccentContainer,
    surfaceContainer: DarkPalette.surfaceContainer,
    surfaceContainerHigh: DarkPalette.surfaceContainerHigh,
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [OhmBrand.orangeBright, OhmBrand.orangeSoft],
    ),
  );

  @override
  OhmColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Gradient? brandGradient,
  }) {
    return OhmColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  OhmColors lerp(ThemeExtension<OhmColors>? other, double t) {
    if (other is! OhmColors) return this;
    return OhmColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer: Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
    );
  }
}

/// Atajo ergonómico: `context.ohm.success`.
extension OhmColorsX on BuildContext {
  OhmColors get ohm => Theme.of(this).extension<OhmColors>()!;
}
