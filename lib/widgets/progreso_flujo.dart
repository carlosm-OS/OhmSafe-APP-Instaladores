import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import 'ayuda.dart';

// =============================================================================
// Regla de oro (Carlos, 2026-10-22, tras el video de la cámara de Nahum): la
// pantalla SIEMPRE dice qué está pasando cuando se aprieta un botón, con frases
// que avanzan y sensación de progreso, y los procesos largos van en pasos
// consecutivos. Estas dos piezas lo hacen reutilizable en cualquier flujo:
//
//  - [IndicadorPasos]: «Paso 2 de 4 · Prepara la cámara» con barra segmentada.
//  - [LineaProgreso]: etapas hechas / en curso / pendientes / con error; la etapa
//    en curso rota frases cada pocos segundos y cuenta el tiempo transcurrido.
// =============================================================================

/// «Paso N de M · título» con una barra segmentada (los pasos hechos y el actual en naranja).
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.actual, required this.total, required this.titulo});

  /// Empieza en 1.
  final int actual;
  final int total;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dur = AppMotion.of(context, AppDurations.base);
    return Semantics(
      label: 'Paso $actual de $total: $titulo',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'PASO $actual DE $total',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: cs.primary),
                  ),
                  TextSpan(
                    text: '  ·  $titulo',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: dur,
                      curve: AppCurves.standard,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= actual ? cs.primary : cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum EstadoEtapa { pendiente, enCurso, hecha, error }

/// Una etapa de [LineaProgreso]. [frases] rota mientras está en curso; [detalle] se muestra fijo
/// (p. ej. el error o lo que hay que hacer) y [accion] va debajo (botones de esa etapa).
class EtapaProgreso {
  const EtapaProgreso({required this.titulo, required this.estado, this.frases = const [], this.detalle, this.accion});
  final String titulo;
  final EstadoEtapa estado;
  final List<String> frases;
  final String? detalle;
  final Widget? accion;
}

/// Lista vertical de etapas con su estado. La etapa en curso muestra una frase que cambia cada
/// [cadaFrase] y, si [desde] está, el tiempo transcurrido; con [hasta] además una barra de tiempo
/// (p. ej. lo que dura el permiso). Así nadie piensa que la app se trabó.
class LineaProgreso extends StatefulWidget {
  const LineaProgreso({super.key, required this.etapas, this.desde, this.hasta, this.cadaFrase = const Duration(seconds: 5), this.ahora = DateTime.now});

  final List<EtapaProgreso> etapas;
  final DateTime? desde;
  final DateTime? hasta;
  final Duration cadaFrase;

  /// Las pruebas fijan el reloj.
  final DateTime Function() ahora;

  @override
  State<LineaProgreso> createState() => _LineaProgresoState();
}

class _LineaProgresoState extends State<LineaProgreso> {
  Timer? _reloj;
  int _segundos = 0;

  bool get _hayEnCurso => widget.etapas.any((e) => e.estado == EstadoEtapa.enCurso);

  @override
  void initState() {
    super.initState();
    _ajustarReloj();
  }

  @override
  void didUpdateWidget(covariant LineaProgreso old) {
    super.didUpdateWidget(old);
    _ajustarReloj();
  }

  void _ajustarReloj() {
    if (_hayEnCurso && _reloj == null) {
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _segundos++);
      });
    } else if (!_hayEnCurso) {
      _reloj?.cancel();
      _reloj = null;
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etapas = widget.etapas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < etapas.length; i++)
          _FilaEtapa(
            etapa: etapas[i],
            ultima: i == etapas.length - 1,
            frase: _frase(etapas[i]),
            tiempo: etapas[i].estado == EstadoEtapa.enCurso ? _tiempo() : null,
            avance: etapas[i].estado == EstadoEtapa.enCurso ? _avance() : null,
          ),
      ],
    );
  }

  String? _frase(EtapaProgreso e) {
    if (e.estado != EstadoEtapa.enCurso || e.frases.isEmpty) return null;
    final cada = widget.cadaFrase.inSeconds.clamp(1, 60);
    return e.frases[(_segundos ~/ cada) % e.frases.length];
  }

  Duration? _transcurrido() {
    final d = widget.desde;
    if (d == null) return null;
    final t = widget.ahora().difference(d);
    return t.isNegative ? Duration.zero : t;
  }

  String? _tiempo() {
    final t = _transcurrido();
    if (t == null) return null;
    final h = widget.hasta;
    // Redondeado a 5 s: «de 5:00», no «de 4:59» (el permiso se pidió un instante después de tocar).
    final crudo = h != null && widget.desde != null ? h.difference(widget.desde!) : null;
    final total = crudo == null ? null : Duration(seconds: (crudo.inMilliseconds / 5000).round() * 5);
    final llevamos = 'Llevamos ${_mmss(t)}';
    if (total == null || total <= Duration.zero) return llevamos;
    return '$llevamos de ${_mmss(total)} como máximo';
  }

  double? _avance() {
    final t = _transcurrido();
    final h = widget.hasta;
    final d = widget.desde;
    if (t == null || h == null || d == null) return null;
    final total = h.difference(d).inMilliseconds;
    if (total <= 0) return null;
    return (t.inMilliseconds / total).clamp(0.0, 1.0);
  }

  static String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _FilaEtapa extends StatelessWidget {
  const _FilaEtapa({required this.etapa, required this.ultima, this.frase, this.tiempo, this.avance});
  final EtapaProgreso etapa;
  final bool ultima;
  final String? frase;
  final String? tiempo;
  final double? avance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final apagado = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55);
    final enCurso = etapa.estado == EstadoEtapa.enCurso;
    final color = switch (etapa.estado) {
      EstadoEtapa.hecha => ohm.success,
      EstadoEtapa.enCurso => cs.primary,
      EstadoEtapa.error => cs.error,
      EstadoEtapa.pendiente => cs.outlineVariant,
    };
    final estadoTexto = switch (etapa.estado) {
      EstadoEtapa.hecha => 'hecho',
      EstadoEtapa.enCurso => 'en curso',
      EstadoEtapa.error => 'con error',
      EstadoEtapa.pendiente => 'pendiente',
    };
    return Semantics(
      container: true,
      liveRegion: enCurso,
      label: '${etapa.titulo}, $estadoTexto${frase != null ? '. $frase' : ''}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  _Marca(estado: etapa.estado, color: color),
                  if (!ultima)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: etapa.estado == EstadoEtapa.hecha ? ohm.success.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: ultima ? 0 : 18, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      etapa.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: enCurso || etapa.estado == EstadoEtapa.error ? FontWeight.w800 : FontWeight.w600,
                        color: etapa.estado == EstadoEtapa.pendiente ? apagado : (etapa.estado == EstadoEtapa.error ? cs.error : theme.textTheme.bodyLarge?.color),
                      ),
                    ),
                    if (frase != null) ...[
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: AppMotion.of(context, AppDurations.spring),
                        switchInCurve: AppCurves.standard,
                        transitionBuilder: (hijo, a) => FadeTransition(opacity: a, child: hijo),
                        layoutBuilder: (actual, anteriores) => Stack(alignment: Alignment.topLeft, children: [...anteriores, ?actual]),
                        child: Text(
                          frase!,
                          key: ValueKey(frase),
                          style: TextStyle(fontSize: 13.5, height: 1.35, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                    if (etapa.detalle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        etapa.detalle!,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: etapa.estado == EstadoEtapa.error ? cs.error : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    if (enCurso && (tiempo != null || avance != null)) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: avance,
                          color: cs.primary,
                          backgroundColor: cs.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      if (tiempo != null) ...[
                        const SizedBox(height: 6),
                        Text(tiempo!, style: TextStyle(fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()], color: apagado)),
                      ],
                    ],
                    if (etapa.accion != null) ...[const SizedBox(height: 12), etapa.accion!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.estado, required this.color});
  final EstadoEtapa estado;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppDurations.base),
      child: SizedBox(
        key: ValueKey(estado),
        width: 24,
        height: 24,
        child: switch (estado) {
          EstadoEtapa.hecha => Icon(Icons.check_circle_rounded, color: color, size: 24),
          EstadoEtapa.error => Icon(Icons.error_rounded, color: color, size: 24),
          EstadoEtapa.enCurso => Padding(
            padding: const EdgeInsets.all(3),
            child: CircularProgressIndicator(strokeWidth: 2.6, color: color, backgroundColor: color.withValues(alpha: 0.15)),
          ),
          EstadoEtapa.pendiente => Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.outlineVariant, width: 2)),
          ),
        },
      ),
    );
  }
}

/// Tarjeta con el título grande de lo que está pasando ahora (p. ej. «Conectando la cámara») y la
/// [LineaProgreso] adentro.
class TarjetaProceso extends StatelessWidget {
  const TarjetaProceso({super.key, required this.titulo, required this.linea, this.subtitulo});
  final String titulo;
  final String? subtitulo;
  final Widget linea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TarjetaFlujo(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(subtitulo!, style: theme.textTheme.bodySmall?.copyWith(height: 1.35, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
          ],
          const SizedBox(height: 16),
          linea,
        ],
      ),
    );
  }
}
