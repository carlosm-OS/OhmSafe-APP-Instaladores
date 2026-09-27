import 'package:flutter/material.dart';

import '../controllers/app_state_provider.dart';
import '../screens/notificaciones_screen.dart';

/// Campana del encabezado con el contador de no leídas. Widget compartido:
/// antes cada pantalla dibujaba su propia campana sin acción.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noLeidas = AppStateProvider.of(context).notificacionesNoLeidas;

    return Semantics(
      button: true,
      label: noLeidas > 0 ? 'Notificaciones, $noLeidas sin leer' : 'Notificaciones',
      child: IconButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
          );
          if (context.mounted) {
            AppStateProvider.of(context).refreshNotificaciones();
          }
        },
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded,
                color: theme.iconTheme.color?.withValues(alpha: 0.7)),
            if (noLeidas > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                  ),
                  child: Text(
                    noLeidas > 99 ? '99+' : '$noLeidas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
