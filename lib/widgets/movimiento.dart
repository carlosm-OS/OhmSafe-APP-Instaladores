import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// Piezas de movimiento traídas de la app del cliente (GO), 2026-10-20 (pedido de Carlos: «usa las
/// animaciones de easing y offset de GO»). Todas respetan «Reducir movimiento» (duración cero).
///
///  - [Presionable]: escala a 0.96 mientras se presiona (GO: `PPressable`).
///  - [CambioSuave]: cambio de contenido fundiendo + deslizando un 3 % desde la derecha, entra con
///    easeOutCubic y sale con easeInCubic (GO: `AnimatedSwitcher` de las casas).
///  - [EntradaSuave]: filas y tarjetas aparecen fundiendo y subiendo 8 px, escalonadas por índice.
///  - La transición entre pantallas vive en [OhmPageTransitionsBuilder] (tema).
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.child, this.activo = true, this.escala = AppOffsets.presion});
  final Widget child;
  final bool activo;
  final double escala;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: widget.activo ? (_) => setState(() => _abajo = true) : null,
      onPointerUp: (_) => setState(() => _abajo = false),
      onPointerCancel: (_) => setState(() => _abajo = false),
      child: AnimatedScale(scale: _abajo ? widget.escala : 1, duration: AppMotion.of(context, AppDurations.press), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// `AnimatedSwitcher` con la curva y el desplazamiento de GO. Dale a [child] una `Key` que cambie
/// cuando cambie el contenido (p. ej. `ValueKey(estado)`).
class CambioSuave extends StatelessWidget {
  const CambioSuave({super.key, required this.child, this.alineacion = Alignment.centerRight});
  final Widget child;
  final AlignmentGeometry alineacion;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppDurations.spring),
      switchInCurve: AppCurves.standard,
      switchOutCurve: AppCurves.exit,
      transitionBuilder: (hijo, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: AppOffsets.deslizaEntrada, end: Offset.zero).animate(anim),
          child: hijo,
        ),
      ),
      layoutBuilder: (actual, anteriores) => Stack(alignment: alineacion, children: [...anteriores, if (actual != null) actual]),
      child: child,
    );
  }
}

/// Entrada de una fila o tarjeta: fundido + sube [AppOffsets.subePx] px con easeOutCubic en 260 ms,
/// escalonada [paso] por índice. Sólo anima la primera vez que se construye.
class EntradaSuave extends StatefulWidget {
  const EntradaSuave({super.key, required this.child, this.index = 0, this.paso = const Duration(milliseconds: 40)});
  final Widget child;
  final int index;
  final Duration paso;

  @override
  State<EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<EntradaSuave> with SingleTickerProviderStateMixin {
  // El escalonado va DENTRO de la animación (Interval), sin Timer: no queda nada pendiente si la
  // pantalla se cierra antes de que entre la fila (las pruebas lo verifican).
  late final Duration _espera = widget.paso * widget.index.clamp(0, 12);
  late final AnimationController _c = AnimationController(vsync: this, duration: AppDurations.page + _espera);
  late final Animation<double> _curva = CurvedAnimation(
    parent: _c,
    curve: Interval(_espera.inMilliseconds / (AppDurations.page + _espera).inMilliseconds, 1, curve: AppCurves.standard),
  );
  bool _arrancada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancada) return;
    _arrancada = true;
    if (AppMotion.reducido(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      builder: (_, hijo) => Opacity(
        opacity: _curva.value,
        child: Transform.translate(offset: Offset(0, AppOffsets.subePx * (1 - _curva.value)), child: hijo),
      ),
      child: widget.child,
    );
  }
}
