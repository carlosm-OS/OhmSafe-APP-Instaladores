// =============================================================================
// OhmSafe · Sistema de tema — Motion (dirección "Faena")
// -----------------------------------------------------------------------------
// Propuesta de movimiento: FUNCIONAL, no decorativo. En campo el movimiento
// debe confirmar acciones y orientar, nunca entretener ni retrasar.
//   · Transiciones base 200ms con easeOutCubic (entra rápido, asienta suave).
//   · Confirmaciones (guardar, éxito) con un overshoot corto easeOutBack.
//   · Respeta reduce-motion: usar AppMotion.duration(context, ...) que colapsa
//     a Duration.zero cuando el usuario pidió menos animación.
// =============================================================================

import 'package:flutter/widgets.dart';

abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 120); // feedback táctil
  static const Duration base = Duration(milliseconds: 200); // transición estándar
  static const Duration slow = Duration(milliseconds: 320); // cambios de pantalla
  static const Duration deliberate = Duration(milliseconds: 450); // confirmaciones
}

abstract final class AppCurves {
  /// Entrada estándar: rápida al iniciar, asienta suave. Uso general.
  static const Curve standard = Curves.easeOutCubic;

  /// Movimiento simétrico enfatizado (Material 3) para elementos que crecen.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Overshoot corto para confirmaciones positivas (toast de guardado, check).
  static const Curve confirm = Curves.easeOutBack;

  /// Salidas: más rápidas que las entradas (regla de motion).
  static const Curve exit = Curves.easeInCubic;
}

abstract final class AppMotion {
  /// Devuelve [d], o [Duration.zero] si el usuario activó "reducir movimiento".
  /// Usar en cada animación no esencial para cumplir accesibilidad.
  static Duration duration(BuildContext context, Duration d) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : d;
  }
}
