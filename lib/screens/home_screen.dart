import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import 'instalaciones_screen.dart';
import '../widgets/reportar_o_cancelar_sheet.dart';
// import 'cotizaciones_screen.dart'; // Fase 2: «Cotizar venta» oculto (2026-10-07)
// import 'reparaciones_screen.dart'; // oculto en el MVP, ver tiles comentados abajo
import 'profile_main_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ayuda.dart';
import '../widgets/notification_bell.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/menu_item_tile.dart';

/// Inicio (v2, 2026-10-23): la única pantalla con el logo. Debajo, quién eres y el menú como lista
/// agrupada de iPhone (filas con ícono en mosaico, sin tarjetas ni sombras).
class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  /// true justo tras el onboarding: muestra un aviso para subir la foto de perfil.
  final bool promptFoto;

  const HomeScreen({super.key, required this.onToggleTheme, this.promptFoto = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // (La invitación «Sube tu foto de perfil» se retiró: la foto la sube OhmSafe en Odoo.)
    // Sincroniza los badges con las asignaciones reales del backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateProvider.of(context).refreshBadges();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado: logo a la izquierda; modo claro/oscuro y campana a la derecha.
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      Image.asset(
                        isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                        height: 26,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("OHM", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              "SAFE",
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: widget.onToggleTheme,
                        icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: cs.onSurfaceVariant),
                      ),
                      const NotificationBell(),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                Expanded(
                  // Jalar hacia abajo vuelve a pedir los contadores al backend.
                  // Sin esto, un ticket que cambia en Odoo no se refleja hasta
                  // cerrar y reabrir la app.
                  child: RefreshIndicator(
                    onRefresh: () => AppStateProvider.of(context).refreshBadges(),
                    color: cs.primary,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // AlwaysScrollable: el gesto debe funcionar aunque la lista
                      // no llegue a desbordar la pantalla.
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      children: [
                        // Quién eres: tocar la foto abre Mi cuenta.
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 20),
                          child: Column(
                            children: [
                              Semantics(
                                button: true,
                                label: 'Abrir Mi cuenta',
                                child: GestureDetector(
                                  onTap: () =>
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileMainScreen(onToggleTheme: widget.onToggleTheme))),
                                  child: AvatarHalo(
                                    size: 104,
                                    initials: initialsFromName(state.installerName),
                                    imagePath: state.customAvatarPath,
                                    imageBase64: state.fotoBase64,
                                    placeholderIcon: Icons.engineering_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(state.installerName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                              const SizedBox(height: 2),
                              Text(
                                "${state.installerRole} #${state.numeroVisible}",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),

                        const EtiquetaSeccion('Servicio'),
                        GrupoFilas(
                          children: [
                            MenuItemTile(
                              label: "Instalaciones",
                              count: state.instalacionesCount,
                              // Al volver (p. ej. tras cerrar una instalación) se recuentan los badges.
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstalacionesScreen())).then((_) {
                                if (context.mounted) AppStateProvider.of(context).refreshBadges();
                              }),
                            ),
                            // MVP (2026-09-18): solo Instalaciones y Reportar incidencias.
                            // Reparaciones, Mantenimientos y Reemplazo de equipo quedan
                            // ocultos hasta la siguiente version; se construyen uno a uno.
                            // Para reactivar un modulo basta descomentar su tile (y el
                            // import de reparaciones_screen.dart). Ver
                            // docs/ESTADO-INSTALADORES.md > "Pendientes priorizados".
                            // MenuItemTile(
                            //   label: "Reparaciones",
                            //   count: state.reparacionesCount,
                            //   onTap: () => Navigator.push(
                            //     context,
                            //     MaterialPageRoute(builder: (_) => const ReparacionesScreen()),
                            //   ),
                            // ),
                            // Fase 4 (2026-09-25): los mantenimientos son intervenciones de
                            // Planificación con producto de mantenimiento; misma lista, otro filtro.
                            // FASE 2 (Carlos, 2026-10-07): oculto por ahora; para reactivarlo basta
                            // descomentar el tile.
                            // MenuItemTile(
                            //   label: "Mantenimientos",
                            //   count: state.mantenimientosCount,
                            //   onTap: () => Navigator.push(
                            //     context,
                            //     MaterialPageRoute(builder: (_) => const InstalacionesScreen(tipo: 'mantenimiento', titulo: 'Mantenimientos')),
                            //   ),
                            // ),
                            // Pregunta primero si es una incidencia o una cancelación en sitio
                            // (reportar NO reagenda; cancelar sí). Carlos, 2026-10-07.
                            MenuItemTile(label: "Reportar incidencias", count: state.incidenciasCount, onTap: () => mostrarReportarOCancelar(context)),
                            // Fase 5 (2026-09-25): el instalador cotiza en campo; la venta
                            // nace en Odoo atribuida a él y el cliente paga en el portal.
                            // FASE 2 (Carlos, 2026-10-07): oculto por ahora (la pantalla y el backend
                            // siguen; descomentar el tile y el import de cotizaciones_screen.dart).
                            // MenuItemTile(
                            //   label: "Cotizar venta",
                            //   count: 0,
                            //   onTap: () => Navigator.push(
                            //     context,
                            //     MaterialPageRoute(builder: (_) => const CotizacionesScreen()),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 100), // espacio para que la barra inferior no tape la lista
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const AppBottomNav(),
        ],
      ),
    );
  }
}
