import '../widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'datos_bancarios_screen.dart';
import 'contrasenas_screen.dart';
import 'facturacion_screen.dart';
import 'login_screen.dart';
import 'seguridad_screen.dart';
import 'pagos_screen.dart';

class ProfileMainScreen extends StatefulWidget {
  /// Se propaga a [LoginScreen] al cerrar sesión (para conservar el toggle de
  /// tema). Opcional: el bottom nav abre esta pantalla sin el callback.
  final VoidCallback? onToggleTheme;
  const ProfileMainScreen({super.key, this.onToggleTheme});

  @override
  State<ProfileMainScreen> createState() => _ProfileMainScreenState();
}

class _ProfileMainScreenState extends State<ProfileMainScreen> {

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  /// Refresca el perfil desde Odoo. No guarda copia local a propósito: la
  /// única fuente de verdad de foto/nombre es AppState, que ya lo comparte con
  /// el home y lo persiste en caché. Silencioso ante fallos: se queda con lo
  /// último conocido (que gracias a la caché nunca es vacío).
  Future<void> _loadPerfil() async {
    final result = await sl.get<PerfilRepository>().getPerfil();
    if (!mounted) return;
    result.fold(
      (p) => AppStateProvider.of(context).aplicarPerfil(p),
      (_) {},
    );
  }

  /// Datos generales del instalador como texto de sólo lectura (sin campos de captura).
  /// Por seguridad sólo el equipo de OhmSafe los corrige en Odoo.
  Widget _datosGenerales(BuildContext context) {
    final state = AppStateProvider.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final partes = state.installerName.trim().split(RegExp(r'\s+'));
    final nombres = partes.isNotEmpty ? partes.first : '';
    final apellidos = partes.length > 1 ? partes.sublist(1).join(' ') : '';
    Widget fila(String etiqueta, String valor, {bool ultima = false}) => Padding(
          padding: EdgeInsets.only(bottom: ultima ? 0 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(etiqueta, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: SelectableText(
                  valor.isNotEmpty ? valor : '—',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATOS GENERALES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        fila('Nombre(s)', nombres),
        fila('Apellidos', apellidos),
        fila('Teléfono', state.installerPhone),
        fila('Correo', state.installerEmail),
        fila('CURP', state.installerCurp, ultima: true),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Si algún dato está mal, escríbenos desde Ayuda: sólo el equipo de OhmSafe puede corregirlo.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pide confirmación, cierra la sesión (limpia sesión + token) y vuelve al
  /// login borrando el stack de navegación.
  Widget _calificacionRow(double? calificacion, int respuestas, ColorScheme cs) {
    if (calificacion == null) {
      return Text('Sin calificaciones aún', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500));
    }
    final llenas = calificacion.floor();
    final media = calificacion - llenas >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < llenas ? Icons.star_rounded : (i == llenas && media ? Icons.star_half_rounded : Icons.star_outline_rounded),
            color: cs.secondary,
            size: 24,
          ),
        const SizedBox(width: 8),
        Text(calificacion.toStringAsFixed(1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('($respuestas)', style: TextStyle(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Seguro que quieres cerrar sesión?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    await sl.get<AuthRepository>().logout();
    if (!mounted) return;
    AppStateProvider.of(context).updateAvatarPath(""); // limpia avatar local
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme ?? () {})),
      (route) => false,
    );
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
                // Top Header: Logo and Notification Bell
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "OHM",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              "SAFE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            const NotificationBell(),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Back chevron and Centered Title Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Text(
                            "Perfil",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(6),
                              shape: const CircleBorder(),
                            ),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: theme.iconTheme.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Foto de perfil: sólo lectura. La sube el equipo de OhmSafe en Odoo.
                        Center(
                          child: Stack(
                            children: [
                              // Misma fuente que el home (AppState): la foto se
                              // pinta al instante desde la cache, en vez de
                              // esperar a /perfil y quedar vacia si falla.
                              AvatarHalo(
                                size: 112,
                                initials: initialsFromName(state.installerName),
                                imagePath: state.customAvatarPath,
                                imageBase64: state.fotoBase64,
                                placeholderIcon: Icons.engineering_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name / Role ID
                        Center(
                          child: Text(
                            "${state.installerRole} ${state.numeroVisible}",
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Calificación real: promedio de las encuestas de satisfacción
                        // que contestan los clientes al cerrar cada servicio.
                        Center(child: _calificacionRow(state.calificacion, state.respuestasEncuesta, cs)),
                        const SizedBox(height: 20),

                        // Código de venta real (Odoo x_codigo_venta). Se oculta
                        // mientras no se conozca, en vez de mostrar uno falso.
                        if (state.codigoVenta.isNotEmpty) ...[
                          Center(
                            child: Text(
                              "Código de ventas: ${state.codigoVenta}",
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ] else
                          const SizedBox(height: 12),

                        // Datos generales: sólo lectura, como texto (los carga OhmSafe en Odoo).
                        _datosGenerales(context),
                        const SizedBox(height: 24),

                        // Styled ListTile Menu Buttons
                        _buildMenuItem(
                          context,
                          label: "Datos bancarios",
                          icon: Icons.settings,
                          targetScreen: const DatosBancariosScreen(),
                        ),
                        _buildMenuItem(
                          context,
                          label: "Contraseñas",
                          icon: Icons.settings,
                          targetScreen: const ContrasenasScreen(),
                        ),
                        _buildMenuItem(
                          context,
                          label: "Seguridad",
                          icon: Icons.fingerprint,
                          targetScreen: const SeguridadScreen(),
                        ),
                        _buildMenuItem(
                          context,
                          label: "Mis pagos",
                          icon: Icons.payments_outlined,
                          targetScreen: const PagosScreen(),
                        ),
                        _buildMenuItem(
                          context,
                          label: "Facturación",
                          icon: Icons.settings,
                          targetScreen: const FacturacionScreen(),
                        ),
                        const SizedBox(height: 32),

                        // Orange outline Logout button
                        OutlinedButton(
                          onPressed: () => _cerrarSesion(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(color: cs.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Cerrar sesión",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Shared bottom navigation bar overlay
          const AppBottomNav(currentTab: "Perfil"),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget targetScreen,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;

    // El color de fondo va en el Material (no en un Container decorado), para
    // que el ListTile pinte su fondo/ripple directamente sobre él. Así se evita
    // la aserción de Flutter "ListTile background color or ink splashes may be
    // invisible" que ocurre cuando un DecoratedBox con color se interpone.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ohm.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(
            icon,
            color: cs.primary,
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade400,
            size: 22,
          ),
        ),
      ),
    );
  }
}
