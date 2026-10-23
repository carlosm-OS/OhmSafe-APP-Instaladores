// =============================================================================
// OhmSafe · OhmGradientButton — botón primario premium (dirección "Faena")
// -----------------------------------------------------------------------------
// CTA principal con gradiente de marca y micro-interacción de press (escala).
// Mantiene las reglas de campo: alto contraste, 56px de alto, sin depender de
// sombra para leerse al sol. El gradiente da sensación premium sin sacrificar
// legibilidad. Respeta "reducir movimiento".
//
// Uso:
//   OhmGradientButton(
//     label: 'Entrar',
//     icon: Icons.login_rounded,       // opcional
//     onPressed: _submit,              // null => deshabilitado
//     loading: _isLoading,             // opcional: muestra spinner
//     loadingLabel: 'Entrando…',       // qué está pasando mientras carga (regla de oro)
//   )
// =============================================================================

import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';

class OhmGradientButton extends StatefulWidget {
  const OhmGradientButton({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.loadingLabel, this.height = AppTouch.primary});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Frase de lo que está pasando mientras [loading] (auditoría 2026-10-23: nunca un círculo mudo).
  /// Sin ella se deja la etiqueta junto al círculo.
  final String? loadingLabel;
  final double height;

  bool get _hasAction => onPressed != null;
  bool get _tappable => onPressed != null && !loading;

  @override
  State<OhmGradientButton> createState() => _OhmGradientButtonState();
}

class _OhmGradientButtonState extends State<OhmGradientButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    final hasAction = widget._hasAction; // pinta gradiente (incl. loading)
    final tappable = widget._tappable; // acepta toque

    final texto = widget.loading ? (widget.loadingLabel ?? widget.label) : widget.label;
    final child = widget.loading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary))),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary),
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: cs.onPrimary), const SizedBox(width: AppSpacing.sm)],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: tappable,
      liveRegion: widget.loading,
      label: texto,
      child: AnimatedScale(
        scale: _pressed && tappable ? 0.97 : 1.0,
        duration: AppMotion.duration(context, AppDurations.fast),
        curve: AppCurves.standard,
        child: GestureDetector(
          onTapDown: tappable ? (_) => _setPressed(true) : null,
          onTapUp: tappable ? (_) => _setPressed(false) : null,
          onTapCancel: tappable ? () => _setPressed(false) : null,
          onTap: tappable ? widget.onPressed : null,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: hasAction ? ohm.brandGradient : null,
              color: hasAction ? null : cs.onSurface.withValues(alpha: 0.12),
              borderRadius: AppRadius.brMd,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: hasAction ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.38)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
