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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration press = Duration(milliseconds: 100); // escala al presionar (GO: PPressable)
  static const Duration fast = Duration(milliseconds: 120); // feedback táctil
  static const Duration base = Duration(milliseconds: 200); // transición estándar / cambio de estado
  static const Duration spring = Duration(milliseconds: 220); // cambio de contenido (GO: AnimatedSwitcher)
  static const Duration page = Duration(milliseconds: 260); // entrada de pantalla / deslizamientos (GO)
  static const Duration slow = Duration(milliseconds: 320); // cambios de pantalla
  static const Duration deliberate = Duration(milliseconds: 450); // confirmaciones
}

/// Desplazamientos del movimiento (2026-10-20, traídos de la app del cliente GO).
abstract final class AppOffsets {
  /// Entrada de contenido: un 3 % del ancho desde la derecha (la dirección de avanzar).
  static const Offset deslizaEntrada = Offset(.03, 0);

  /// Entrada de filas y tarjetas: suben 8 px mientras aparecen.
  static const double subePx = 8;

  /// Escala al presionar una fila o botón.
  static const double presion = .96;
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
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false ? Duration.zero : d;
  }

  /// Alias con el nombre que usa GO (`AppMotion.of(context, …)`).
  static Duration of(BuildContext context, Duration d) => duration(context, d);

  static bool reducido(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Transición entre pantallas como en GO (2026-10-20): la pantalla nueva entra fundiendo y
/// deslizándose un 3 % desde la derecha con easeOutCubic; al regresar sale con easeInCubic.
/// Se registra en `ThemeData.pageTransitionsTheme`, así aplica a todos los `MaterialPageRoute`.
class OhmPageTransitionsBuilder extends PageTransitionsBuilder {
  const OhmPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppDurations.page;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curva = CurvedAnimation(parent: animation, curve: AppCurves.standard, reverseCurve: AppCurves.exit);
    // Con «Reducir movimiento» sólo funde, sin deslizar (auditoría 2026-10-23).
    if (AppMotion.reducido(context)) return FadeTransition(opacity: curva, child: child);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(begin: AppOffsets.deslizaEntrada, end: Offset.zero).animate(curva),
        child: child,
      ),
    );
  }
}

/// iPhone: la transición nativa de iOS, que trae el gesto de deslizar desde el borde para regresar
/// (auditoría 2026-10-23: al usar la de GO en iOS se había perdido). Con «Reducir movimiento», funde.
class OhmIosPageTransitionsBuilder extends PageTransitionsBuilder {
  const OhmIosPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (AppMotion.reducido(context)) return FadeTransition(opacity: animation, child: child);
    return const CupertinoPageTransitionsBuilder().buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}
