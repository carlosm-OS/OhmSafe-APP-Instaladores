import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import 'botones_dialogo.dart';

/// Toda decisión es una hoja desde abajo (Carlos, 2026-10-23; lienzo «Ajustes de diseño», S5):
/// título = la pregunta, texto = qué pasa con lo que llevas, arriba la acción para seguir (naranja) y
/// abajo la de salir. Si salir pierde trabajo, [pierde] la pinta en rojo.
///
/// Con [alSeguir] la acción corre dentro de la hoja: el botón dice [cargandoTexto], no se puede tocar
/// dos veces ni cerrar la hoja mientras trabaja, y si falla el error se queda en la hoja. Devuelve
/// `true` si siguió (y [alSeguir] terminó bien), `false` si eligió salir y `null` si la cerró.
Future<bool?> mostrarHojaDecision(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String seguir,
  required String salir,
  bool pierde = false,
  Future<String?> Function()? alSeguir,
  String? cargandoTexto,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HojaDecision(titulo: titulo, texto: texto, seguir: seguir, salir: salir, pierde: pierde, alSeguir: alSeguir, cargandoTexto: cargandoTexto),
  );
}

class _HojaDecision extends StatefulWidget {
  const _HojaDecision({
    required this.titulo,
    required this.texto,
    required this.seguir,
    required this.salir,
    required this.pierde,
    this.alSeguir,
    this.cargandoTexto,
  });

  final String titulo;
  final String texto;
  final String seguir;
  final String salir;
  final bool pierde;

  /// Devuelve `null` si salió bien o el mensaje de error para mostrar en la hoja.
  final Future<String?> Function()? alSeguir;
  final String? cargandoTexto;

  @override
  State<_HojaDecision> createState() => _HojaDecisionState();
}

class _HojaDecisionState extends State<_HojaDecision> {
  bool _trabajando = false;
  String? _error;

  Future<void> _seguir() async {
    final accion = widget.alSeguir;
    if (accion == null) {
      Navigator.pop(context, true);
      return;
    }
    if (_trabajando) return;
    setState(() {
      _trabajando = true;
      _error = null;
    });
    final error = await accion();
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _trabajando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PopScope(
      canPop: !_trabajando,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
            ),
            const SizedBox(height: 8),
            Text(widget.texto, style: TextStyle(fontSize: 15, height: 1.45, color: cs.onSurfaceVariant)),
            AnimatedSize(
              duration: AppMotion.of(context, AppDurations.base),
              curve: AppCurves.standard,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 20, color: cs.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(fontSize: 14, height: 1.4, color: cs.error, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            BotonesDialogo(
              primario: _error == null ? widget.seguir : 'Volver a intentar',
              onPrimario: _seguir,
              primarioCargando: _trabajando,
              primarioCargandoTexto: widget.cargandoTexto,
              secundario: widget.salir,
              onSecundario: _trabajando ? null : () => Navigator.pop(context, false),
              secundarioPeligro: widget.pierde,
            ),
          ],
        ),
      ),
    );
  }
}
