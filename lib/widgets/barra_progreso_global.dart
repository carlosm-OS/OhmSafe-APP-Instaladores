import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/network/actividad.dart';
import '../core/theme/app_motion.dart';

/// Barra de progreso de toda la app (se monta en `MaterialApp.builder`, encima de pantallas, hojas y
/// diálogos). Responde a [Actividad.pendientes]:
///
/// * Sólo aparece si la espera pasa de [retraso]: una respuesta rápida no parpadea.
/// * Avanza sola hacia ~90 % mientras se espera y llega a 100 % al terminar, luego se desvanece.
/// * Si la espera pasa de [aviso], muestra «Sigue cargando…» para que no parezca trabada con mala señal.
/// * No captura toques ([IgnorePointer]).
class BarraProgresoGlobal extends StatefulWidget {
  const BarraProgresoGlobal({super.key, required this.child, this.retraso = const Duration(milliseconds: 250), this.aviso = const Duration(seconds: 6)});

  final Widget child;
  final Duration retraso;
  final Duration aviso;

  static const alto = 3.0;

  @override
  State<BarraProgresoGlobal> createState() => _BarraProgresoGlobalState();
}

class _BarraProgresoGlobalState extends State<BarraProgresoGlobal> {
  bool _visible = false;
  bool _lento = false;
  double _progreso = 0;
  Timer? _espera;
  Timer? _goteo;
  Timer? _avisoTimer;
  Timer? _ocultar;

  @override
  void initState() {
    super.initState();
    Actividad.pendientes.addListener(_alCambiar);
    if (Actividad.pendientes.value > 0) _alCambiar();
  }

  @override
  void dispose() {
    Actividad.pendientes.removeListener(_alCambiar);
    for (final t in [_espera, _goteo, _avisoTimer, _ocultar]) {
      t?.cancel();
    }
    super.dispose();
  }

  /// Las peticiones pueden arrancar a media construcción de un frame: el setState se difiere.
  void _alCambiar() {
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.persistentCallbacks || fase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _aplicar());
    } else {
      _aplicar();
    }
  }

  void _aplicar() {
    if (!mounted) return;
    if (Actividad.pendientes.value > 0) {
      _ocultar?.cancel();
      _ocultar = null;
      if (_visible && _progreso >= 1) {
        _mostrar(); // terminaba y llegó otra espera: retoma sin esperar el retraso
      } else if (!_visible) {
        _espera ??= Timer(widget.retraso, _mostrar);
      }
    } else {
      _espera?.cancel();
      _espera = null;
      if (_visible) _terminar();
    }
  }

  void _mostrar() {
    _espera = null;
    if (!mounted || Actividad.pendientes.value == 0) return;
    setState(() {
      _visible = true;
      _progreso = _progreso >= 1 ? 0.15 : (_progreso < 0.15 ? 0.15 : _progreso);
    });
    _goteo?.cancel();
    _goteo = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      setState(() => _progreso += (0.9 - _progreso) * 0.08);
    });
    _avisoTimer?.cancel();
    _avisoTimer = Timer(widget.aviso, () {
      if (mounted && _visible && _progreso < 1) setState(() => _lento = true);
    });
  }

  void _terminar() {
    _goteo?.cancel();
    _avisoTimer?.cancel();
    setState(() {
      _progreso = 1;
      _lento = false;
    });
    _ocultar = Timer(AppDurations.slow, () {
      if (!mounted) return;
      setState(() => _visible = false);
      _ocultar = Timer(AppDurations.slow, () {
        if (mounted && !_visible) setState(() => _progreso = 0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final arriba = MediaQuery.paddingOf(context).top;
    // El aviso de señal lenta va abajo, sobre la barra de navegación (como los avisos de la app):
    // arriba tapaba el logo y el título.
    final abajo = MediaQuery.paddingOf(context).bottom + 104;
    final dur = AppMotion.duration(context, AppDurations.base);
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: arriba,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Semantics(
              liveRegion: _visible,
              label: _visible ? 'Cargando' : null,
              child: AnimatedOpacity(
                key: const Key('barra-progreso-global'),
                opacity: _visible ? 1 : 0,
                duration: dur,
                curve: _visible ? AppCurves.standard : AppCurves.exit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: BarraProgresoGlobal.alto,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _progreso),
                        duration: _visible ? dur : Duration.zero,
                        curve: AppCurves.standard,
                        builder: (_, v, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: v.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: DecoratedBox(decoration: BoxDecoration(color: cs.primary)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: abajo,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: dur,
              child: !_lento
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const Key('barra-progreso-lento'),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Material(
                          color: cs.inverseSurface,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onInverseSurface)),
                                const SizedBox(width: 10),
                                Text(
                                  'Sigue cargando… la señal está lenta',
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onInverseSurface, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
