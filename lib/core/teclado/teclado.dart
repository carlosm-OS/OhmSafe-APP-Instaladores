import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manejo del teclado para toda la app (se monta en `MaterialApp.builder`):
///
/// * **Barra «Listo» sobre el teclado (iOS).** El teclado numérico de iPhone no
///   trae Enter: sin esto el instalador no puede cerrarlo tras escribir el
///   metraje. La barra reserva su alto (se suma al inset del teclado) para no
///   tapar el campo.
/// * **Tocar fuera cierra el teclado.**
/// * **[TecladoScope]** avisa si el teclado está abierto. Dentro de un Scaffold
///   `MediaQuery.viewInsets` llega en 0 (el Scaffold ya lo descontó), por eso la
///   barra de navegación inferior no se enteraba y subía encima del contenido.
class TecladoGlobal extends StatelessWidget {
  final Widget child;
  const TecladoGlobal({super.key, required this.child});

  static const altoBarra = 44.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = mq.viewInsets.bottom;
    final abierto = inset > 0;
    final conBarra = abierto && defaultTargetPlatform == TargetPlatform.iOS;
    final contenido = conBarra
        ? MediaQuery(data: mq.copyWith(viewInsets: mq.viewInsets.copyWith(bottom: inset + altoBarra)), child: child)
        : child;
    return TecladoScope(
      abierto: abierto,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: cerrarTeclado,
        child: Stack(
          children: [
            Positioned.fill(child: contenido),
            if (conBarra) Positioned(left: 0, right: 0, bottom: inset, height: altoBarra, child: const _BarraListo()),
          ],
        ),
      ),
    );
  }
}

void cerrarTeclado() => FocusManager.instance.primaryFocus?.unfocus();

class _BarraListo extends StatelessWidget {
  const _BarraListo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('teclado-listo'),
            onPressed: cerrarTeclado,
            child: const Text('Listo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// Si el teclado está abierto, visible desde cualquier pantalla (aunque esté
/// dentro de un Scaffold que ya descontó el inset).
class TecladoScope extends InheritedWidget {
  final bool abierto;
  const TecladoScope({super.key, required this.abierto, required super.child});

  static bool abiertoEn(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TecladoScope>();
    return scope?.abierto ?? MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  @override
  bool updateShouldNotify(TecladoScope old) => old.abierto != abierto;
}

/// Al cambiar de pantalla se cierra el teclado: no se queda abierto encima de
/// la siguiente.
class CerrarTecladoAlNavegar extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => cerrarTeclado();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => cerrarTeclado();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => cerrarTeclado();
}
