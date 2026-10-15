import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';

// =============================================================================
// Botones de las ventanas emergentes (diálogos y hojas). Carlos, 2026-10-15:
// «pon botones primarios y secundarios; el No debe tener forma de botón
// secundario». Los dos a todo lo ancho, uno sobre otro: arriba el primario
// (naranja lleno: «Guardar», «Sí») y abajo el secundario (contorno naranja:
// «Cancelar», «No»). Ajuste del mismo día: primero el primario y el contorno
// en el naranja de OhmSafe (antes iba negro y abajo). Antes de todo esto el
// «No» / «Cancelar» era sólo texto naranja suelto.
// =============================================================================

/// Botón secundario de las ventanas emergentes: contorno de 2 px y texto en el naranja de OhmSafe,
/// mismo alto y radio que el primario.
class BotonContornoSecundario extends StatelessWidget {
  const BotonContornoSecundario({super.key, required this.etiqueta, required this.onPressed});

  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size.fromHeight(AppTouch.primary),
        side: BorderSide(color: onPressed == null ? cs.primary.withValues(alpha: 0.3) : cs.primary, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        textStyle: theme.textTheme.labelLarge,
      ),
      // La negrita va en el Text: desde `textStyle` no llegaba (se veía delgado junto al primario).
      child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
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
  });

  final String primario;
  final VoidCallback? onPrimario;
  final String? secundario;
  final VoidCallback? onSecundario;

  /// Muestra un indicador en el primario y lo deja sin efecto (p. ej. «Guardar» mientras guarda).
  final bool primarioCargando;

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
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary))
                : Text(primario),
          ),
          if (secundario != null) ...[
            const SizedBox(height: 12),
            BotonContornoSecundario(etiqueta: secundario!, onPressed: onSecundario),
          ],
        ],
      ),
    );
  }
}
