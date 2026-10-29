import 'package:flutter/material.dart';

import '../controllers/app_state_provider.dart';
import '../screens/notificaciones_screen.dart';

/// Campana del encabezado con el contador de no leídas. Widget compartido:
/// antes cada pantalla dibujaba su propia campana sin acción.
/// v2 (2026-10-23): campana en tinta y contador naranja sin borde de color suelto.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final noLeidas = AppStateProvider.of(context).notificacionesNoLeidas;

    return IconButton(
      tooltip: noLeidas > 0 ? 'Notificaciones, $noLeidas sin leer' : 'Notificaciones',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
        if (context.mounted) {
          AppStateProvider.of(context).refreshNotificaciones();
        }
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, size: 26, color: cs.onSurface),
          if (noLeidas > 0)
            Positioned(
              right: -4,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                ),
                child: Text(
                  noLeidas > 99 ? '99+' : '$noLeidas',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
