import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';

// =============================================================================
// Botones de las ventanas emergentes (diálogos y hojas). Carlos, 2026-10-15:
// «pon botones primarios y secundarios; el No debe tener forma de botón
// secundario, con contorno negro». Los dos a todo lo ancho, uno sobre otro:
// arriba el secundario (contorno oscuro) y abajo el primario (naranja lleno),
// donde cae el pulgar. Antes el «No» / «Cancelar» era sólo texto naranja.
// =============================================================================

/// Botón secundario de las ventanas emergentes: contorno oscuro de 2 px y texto oscuro
/// (en modo oscuro, claro), mismo alto y radio que el primario.
class BotonContornoOscuro extends StatelessWidget {
  const BotonContornoOscuro({super.key, required this.etiqueta, required this.onPressed});

  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        minimumSize: const Size.fromHeight(AppTouch.primary),
        side: BorderSide(color: onPressed == null ? cs.onSurface.withValues(alpha: 0.3) : cs.onSurface, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        // Mismo peso que el primario (el tema le da al lleno su negrita).
        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Text(etiqueta),
    );
  }
}

/// Par de botones de una ventana emergente: [secundario] arriba (contorno oscuro) y [primario]
/// abajo (naranja). Sin [secundario], sólo el primario (p. ej. «Entendido»).
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
          if (secundario != null) ...[
            BotonContornoOscuro(etiqueta: secundario!, onPressed: onSecundario),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: primarioCargando ? () {} : onPrimario,
            child: primarioCargando
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary))
                : Text(primario),
          ),
        ],
      ),
    );
  }
}
