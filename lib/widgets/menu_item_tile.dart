import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import 'ayuda.dart';

/// Fila del menú de Home (v2, 2026-10-23): ícono en mosaico de 32 a color suave, título, contador
/// naranja y chevron. Va dentro de un [GrupoFilas]; sin sombra ni tarjeta propia.
class MenuItemTile extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const MenuItemTile({super.key, required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;

    final (Color color, IconData icono) = switch (label) {
      'Instalaciones' => (cs.primary, Icons.construction_rounded),
      'Reparaciones' => (ohm.info, Icons.build_rounded),
      'Mantenimientos' => (ohm.success, Icons.settings_suggest_rounded),
      'Reemplazo de equipo' => (ohm.info, Icons.cached_rounded),
      'Reportar incidencias' => (cs.error, Icons.warning_amber_rounded),
      _ => (cs.onSurfaceVariant, Icons.arrow_right_alt_rounded),
    };

    return FilaFlujo(
      titulo: label,
      onTap: onTap,
      leading: MosaicoIcono(icono: icono, color: color),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) ...[_AnimatedBadge(count: count), const SizedBox(width: 8)],
          Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Ícono en mosaico de 32 con el color al 12 % de fondo (v2: filas de lista agrupada).
class MosaicoIcono extends StatelessWidget {
  const MosaicoIcono({super.key, required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
      child: Icon(icono, size: 18, color: color),
    );
  }
}

class _AnimatedBadge extends StatefulWidget {
  final int count;

  const _AnimatedBadge({required this.count});

  @override
  State<_AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _badgePopController = AnimationController(vsync: this, duration: AppDurations.base);

  // v2: sin rebote elástico; entra con un leve sobrepaso y con «Reducir movimiento» aparece sin animar.
  late final Animation<double> _popAnimation = CurvedAnimation(parent: _badgePopController, curve: AppCurves.confirm);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _badgePopController.duration = AppMotion.of(context, AppDurations.base);
    if (_badgePopController.value == 0) _badgePopController.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _badgePopController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _badgePopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ScaleTransition(
      scale: _popAnimation,
      child: Container(
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(13)),
        alignment: Alignment.center,
        child: Text(
          '${widget.count}',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700, height: 1.1),
        ),
      ),
    );
  }
}
