import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';

// =============================================================================
// Botones de las ventanas emergentes (diálogos y hojas). Carlos, 2026-10-15:
// «pon botones primarios y secundarios; el No debe tener forma de botón
// secundario». Los dos a todo lo ancho, uno sobre otro: arriba el primario
// (naranja lleno: «Guardar», «Sí») y abajo el secundario (contorno naranja:
// «Cancelar», «No»). Ajuste del mismo día: primero el primario y el contorno
// en el naranja de OhmSafe (antes iba negro y abajo). Antes de todo esto el
// «No» / «Cancelar» era sólo texto naranja suelto. Lienzo de Carlos (mismo día,
// más tarde): el secundario pasa a borde gris con texto oscuro, igual que
// «Cancelar instalación», para que el naranja quede sólo en la acción principal.
// =============================================================================

/// Botón secundario de las ventanas emergentes: borde gris y texto oscuro, mismo alto y radio que el
/// primario (el naranja queda sólo en la acción principal).
class BotonContornoSecundario extends StatelessWidget {
  const BotonContornoSecundario({super.key, required this.etiqueta, required this.onPressed, this.peligro = false});

  final String etiqueta;
  final VoidCallback? onPressed;

  /// Salir pierde trabajo: el texto va en rojo (hoja de decisión, 2026-10-23).
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: peligro ? cs.error : cs.onSurface,
        minimumSize: const Size.fromHeight(AppTouch.primary),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: onPressed == null ? 0.5 : 1), width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        // Sin `textStyle` propio: hereda el del tema de botones, igual que el primario. Tomarlo de
        // `theme.textTheme` le ponía la familia Inter (variable), que en el teléfono no engrosa y se
        // veía delgado junto al primario.
      ),
      child: Text(etiqueta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}

/// Par de botones de una ventana emergente: [primario] arriba (naranja lleno) y [secundario]
/// abajo (contorno naranja). Sin [secundario], sólo el primario (p. ej. «Entendido»).
/// Va en `AlertDialog.actions` o al final de una hoja.
class BotonesDialogo extends StatelessWidget {
  const BotonesDialogo({
    super.key,
    required this.primario,
    required this.onPrimario,
    this.secundario,
    this.onSecundario,
    this.primarioCargando = false,
    this.primarioCargandoTexto,
    this.secundarioPeligro = false,
  });

  final String primario;
  final VoidCallback? onPrimario;
  final String? secundario;
  final VoidCallback? onSecundario;

  /// Muestra un indicador en el primario y lo deja sin efecto (p. ej. «Guardar» mientras guarda).
  final bool primarioCargando;

  /// Qué está pasando mientras [primarioCargando] («Guardando el sensor…»). Sin ella, la etiqueta.
  final String? primarioCargandoTexto;

  /// El secundario pierde trabajo («Salir sin conectar»): texto en rojo.
  final bool secundarioPeligro;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      // Dentro de `AlertDialog.actions` las restricciones son holgadas: así toman todo el ancho.
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: primarioCargando ? () {} : onPrimario,
            child: primarioCargando
                ? Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary)),
                        const SizedBox(width: 10),
                        Flexible(child: Text(primarioCargandoTexto ?? primario, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )
                : Text(primario),
          ),
          if (secundario != null) ...[
            const SizedBox(height: 12),
            BotonContornoSecundario(etiqueta: secundario!, onPressed: onSecundario, peligro: secundarioPeligro),
          ],
        ],
      ),
    );
  }
}
