import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ayuda.dart';
import '../widgets/hoja_decision.dart';
import '../widgets/menu_item_tile.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'datos_bancarios_screen.dart';
import 'contrasenas_screen.dart';
import 'login_screen.dart';
import 'notificaciones_screen.dart';
import 'seguridad_screen.dart';
import 'pagos_screen.dart';

/// Mi cuenta (v2, 2026-10-23; lienzo «11 · Perfil»): raíz de pestaña con el encabezado de todos, sin
/// logo ni punto azul falso sobre la campana. Quién eres, tus datos (sólo lectura) y dos grupos:
/// «Cuenta» y «Actividad». «Cerrar sesión» al final, en gris con texto rojo.
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
    result.fold((p) => AppStateProvider.of(context).aplicarPerfil(p), (_) {});
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
    Widget fila(String etiqueta, String valor) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(etiqueta, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
            Expanded(child: SelectableText(valor.isNotEmpty ? valor : '—', style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EtiquetaSeccion('Datos generales'),
        GrupoFilas(
          pie: 'Si algún dato está mal, escríbenos desde Ayuda: sólo el equipo de OhmSafe puede corregirlo.',
          children: [
            fila('Nombre(s)', nombres),
            fila('Apellidos', apellidos),
            fila('Teléfono', state.installerPhone),
            fila('Correo', state.installerEmail),
            fila('CURP', state.installerCurp),
            // RFC de sólo lectura aquí (Carlos, 2026-10-20): antes se capturaba en «Facturación».
            fila('RFC', state.installerRfc),
            // Código de venta real (Odoo x_codigo_venta). Se oculta mientras no se conozca, en vez de
            // mostrar uno falso.
            if (state.codigoVenta.isNotEmpty) fila('Código de ventas', state.codigoVenta),
          ],
        ),
      ],
    );
  }

  /// Calificación real: promedio de las encuestas de satisfacción que contestan los clientes al
  /// cerrar cada servicio.
  Widget _calificacionRow(double? calificacion, int respuestas) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (calificacion == null) {
      return Text('Sin calificaciones aún', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    final llenas = calificacion.floor();
    final media = calificacion - llenas >= 0.5;
    return Semantics(
      label: 'Calificación ${calificacion.toStringAsFixed(1)} de 5, $respuestas respuestas',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < llenas ? Icons.star_rounded : (i == llenas && media ? Icons.star_half_rounded : Icons.star_outline_rounded),
              color: context.ohm.warning,
              size: 22,
            ),
          const SizedBox(width: 8),
          Text(calificacion.toStringAsFixed(1), style: theme.textTheme.titleSmall),
          const SizedBox(width: 4),
          Text('($respuestas)', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// Pide confirmación (hoja desde abajo), cierra la sesión (limpia sesión + token) y vuelve al
  /// login borrando el stack de navegación.
  Future<void> _cerrarSesion() async {
    final eleccion = await mostrarHojaDecision(
      context,
      titulo: '¿Cerrar sesión?',
      texto: 'Para volver a entrar en este teléfono necesitarás tu correo y tu contraseña.',
      seguir: 'Seguir en mi cuenta',
      salir: 'Cerrar sesión',
      pierde: true,
    );
    if (eleccion != false || !mounted) return;

    await sl.get<AuthRepository>().logout();
    if (!mounted) return;
    AppStateProvider.of(context).updateAvatarPath(""); // limpia avatar local
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen(onToggleTheme: widget.onToggleTheme ?? () {})), (route) => false);
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
    if (mounted) AppStateProvider.of(context).refreshNotificaciones();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
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
                const EncabezadoFlujo(titulo: 'Mi cuenta', volver: false),
                Expanded(
                  // SingleChildScrollView (no ListView): la página es corta y todo queda construido.
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Foto de perfil: sólo lectura. La sube el equipo de OhmSafe en Odoo. Misma
                        // fuente que el home (AppState): se pinta al instante desde la caché.
                        Center(
                          child: AvatarHalo(
                            size: 96,
                            initials: initialsFromName(state.installerName),
                            imagePath: state.customAvatarPath,
                            imageBase64: state.fotoBase64,
                            placeholderIcon: Icons.engineering_rounded,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(state.installerName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text(
                          "${state.installerRole} #${state.numeroVisible}",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Center(child: _calificacionRow(state.calificacion, state.respuestasEncuesta)),
                        const SizedBox(height: 24),

                        // Datos generales: sólo lectura, como texto (los carga OhmSafe en Odoo).
                        _datosGenerales(context),

                        const EtiquetaSeccion('Cuenta'),
                        GrupoFilas(
                          children: [
                            _fila(
                              'Datos bancarios',
                              subtitulo: 'Donde recibes tus pagos',
                              icono: Icons.account_balance_rounded,
                              color: ohm.success,
                              destino: const DatosBancariosScreen(),
                            ),
                            _fila('Contraseña', icono: Icons.lock_rounded, color: cs.onSurfaceVariant, destino: const ContrasenasScreen()),
                            _fila(
                              'Seguridad',
                              subtitulo: 'Entrar con Face ID o huella',
                              icono: Icons.fingerprint_rounded,
                              color: ohm.info,
                              destino: const SeguridadScreen(),
                            ),
                          ],
                        ),

                        const EtiquetaSeccion('Actividad'),
                        GrupoFilas(
                          children: [
                            _fila('Mis pagos', icono: Icons.payments_rounded, color: ohm.success, destino: const PagosScreen()),
                            _fila('Notificaciones', icono: Icons.notifications_none_rounded, color: cs.primary, alTocar: _abrirNotificaciones),
                          ],
                        ),

                        BotonSecundario(etiqueta: 'Cerrar sesión', icono: Icons.logout_rounded, peligro: true, onPressed: _cerrarSesion),
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

  Widget _fila(String titulo, {String? subtitulo, required IconData icono, required Color color, Widget? destino, VoidCallback? alTocar}) {
    return FilaFlujo(
      titulo: titulo,
      subtitulo: subtitulo,
      leading: MosaicoIcono(icono: icono, color: color),
      trailing: Icon(Icons.chevron_right_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: alTocar ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => destino!)),
    );
  }
}
