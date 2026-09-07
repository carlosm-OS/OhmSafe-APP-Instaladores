import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';

class MenuItemTile extends StatefulWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const MenuItemTile({
    super.key,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  State<MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<MenuItemTile> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.02,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    _scale = 1.0 - _pressController.value;

    // Soft background and icon configuration matching the screenshot
    late Color iconBgColor;
    late Color iconColor;
    late IconData iconData;

    switch (widget.label) {
      case "Instalaciones":
        iconBgColor = cs.primaryContainer;
        iconColor = cs.primary;
        iconData = Icons.construction_rounded;
        break;
      case "Reparaciones":
        iconBgColor = ohm.infoContainer;
        iconColor = ohm.info;
        iconData = Icons.build_outlined;
        break;
      case "Mantenimientos":
        iconBgColor = ohm.successContainer;
        iconColor = ohm.success;
        iconData = Icons.settings_suggest_rounded;
        break;
      case "Reemplazo de equipo":
        // Sin token de púrpura en la paleta "Faena": se mantiene el color.
        iconBgColor = isDark ? const Color(0xFF281E35) : const Color(0xFFFAF5FF);
        iconColor = const Color(0xFF9333EA);
        iconData = Icons.cached_rounded;
        break;
      case "Reportar incidencias":
        iconBgColor = cs.errorContainer;
        iconColor = cs.error;
        iconData = Icons.warning_amber_rounded;
        break;
      default:
        iconBgColor = ohm.surfaceContainer;
        iconColor = cs.onSurfaceVariant;
        iconData = Icons.arrow_right_alt_rounded;
    }

    return Transform.scale(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
              color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              // Colored icon background container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Title label
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                  ),
                ),
              ),

              // Badge & Chevron Right
              Row(
                children: [
                  if (widget.count > 0) ...[
                    _AnimatedBadge(count: widget.count),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  late AnimationController _badgePopController;
  late Animation<double> _popAnimation;

  @override
  void initState() {
    super.initState();
    _badgePopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    _popAnimation = CurvedAnimation(
      parent: _badgePopController,
      curve: Curves.elasticOut,
    );

    _badgePopController.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _badgePopController.reset();
      _badgePopController.forward();
    }
  }

  @override
  void dispose() {
    _badgePopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentOrange = Theme.of(context).colorScheme.primary;

    return ScaleTransition(
      scale: _popAnimation,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: accentOrange,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentOrange.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          "${widget.count}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
