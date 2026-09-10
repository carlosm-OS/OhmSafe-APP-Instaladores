import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../controllers/app_state_provider.dart';
import '../core/error/failures.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';
import '../features/perfil/domain/entities/perfil.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'datos_generales_screen.dart';
import 'datos_bancarios_screen.dart';
import 'contrasenas_screen.dart';
import 'facturacion_screen.dart';
import 'login_screen.dart';

/// Formatea la imagen para que Odoo siempre la acepte: decodifica, redimensiona
/// a máx 1024px y re-codifica como JPEG. Corre en un isolate (compute) para no
/// congelar la UI. Devuelve null si la imagen no se pudo leer.
Uint8List? _formatearAvatar(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  final resized = (decoded.width > 1024 || decoded.height > 1024)
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1024 : null,
          height: decoded.height > decoded.width ? 1024 : null,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

class ProfileMainScreen extends StatefulWidget {
  /// Se propaga a [LoginScreen] al cerrar sesión (para conservar el toggle de
  /// tema). Opcional: el bottom nav abre esta pantalla sin el callback.
  final VoidCallback? onToggleTheme;
  const ProfileMainScreen({super.key, this.onToggleTheme});

  @override
  State<ProfileMainScreen> createState() => _ProfileMainScreenState();
}

class _ProfileMainScreenState extends State<ProfileMainScreen> {
  final ImagePicker _picker = ImagePicker();

  /// Perfil cargado desde Odoo (getPerfil). Aporta la foto persistida
  /// (fotoBase64) y el nombre para las iniciales, así la foto no depende de una
  /// selección local de esta sesión.
  Perfil? _perfil;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  /// Lee el perfil desde el repositorio y refresca la UI con la foto/nombre
  /// reales. Silencioso ante fallos: deja el último valor conocido.
  Future<void> _loadPerfil() async {
    final result = await sl.get<PerfilRepository>().getPerfil();
    if (!mounted) return;
    result.fold(
      (p) => setState(() => _perfil = p),
      (_) {},
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final state = AppStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;
    try {
      final XFile? selected = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024, // comprime en móvil (en macOS lo maneja el límite del backend)
        maxHeight: 1024,
      );
      if (selected != null) {
        state.updateAvatarPath(selected.path); // preview local inmediato
        // Formatea la imagen (redimensiona + JPEG) para que Odoo la acepte en
        // cualquier plataforma (macOS no comprime con image_picker).
        final raw = await selected.readAsBytes();
        final formateada = await compute(_formatearAvatar, raw);
        if (!mounted) return;
        if (formateada == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No pudimos leer esa imagen. Usa una foto JPG o PNG."),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
        final result = await sl
            .get<PerfilRepository>()
            .subirAvatar(contenidoBase64: base64Encode(formateada));
        if (!mounted) return;
        result.fold(
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Foto de perfil guardada", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: cs.primary,
              ),
            );
            // Re-lee el perfil para reflejar la foto ya persistida en Odoo
            // (no solo el preview local).
            _loadPerfil();
          },
          (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_mensajeErrorFoto(failure)), backgroundColor: Colors.redAccent),
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al acceder a la galería: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Traduce el fallo de subida a un mensaje claro para el instalador.
  String _mensajeErrorFoto(Failure f) {
    if (f is NetworkFailure) return "Sin conexión. Revisa tu internet e intenta de nuevo.";
    if (f is AuthFailure) return "Tu sesión expiró. Vuelve a iniciar sesión.";
    final m = f.message.toLowerCase();
    if (m.contains("large") || m.contains("payload") || m.contains("entity")) {
      return "La imagen es muy grande. Intenta con otra.";
    }
    if (m.contains("procesar") || m.contains("truncat") || m.contains("jpg") || m.contains("png") || m.contains("imagen")) {
      return "No se pudo procesar la imagen. Usa una foto JPG o PNG.";
    }
    return "No se pudo guardar la foto: ${f.message}";
  }

  /// Pide confirmación, cierra la sesión (limpia sesión + token) y vuelve al
  /// login borrando el stack de navegación.
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
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.notifications,
                                color: theme.iconTheme.color?.withValues(alpha: 0.7),
                              ),
                            ),
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
                        // Editable circular avatar
                        Center(
                          child: Stack(
                            children: [
                              AvatarHalo(
                                size: 112,
                                initials: initialsFromName(_perfil?.nombre),
                                imagePath: state.customAvatarPath,
                                imageBase64: _perfil?.fotoBase64,
                                placeholderIcon: Icons.engineering_rounded,
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _pickImage(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      color: cs.onPrimary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name / Role ID
                        Center(
                          child: Text(
                            "${state.installerRole} ${state.installerId}",
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Star Rating Row
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: cs.secondary, size: 24),
                              Icon(Icons.star_rounded, color: cs.secondary, size: 24),
                              Icon(Icons.star_rounded, color: cs.secondary, size: 24),
                              Icon(Icons.star_rounded, color: cs.secondary, size: 24),
                              Icon(Icons.star_half_rounded, color: cs.secondary, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                "4.7",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Unique Sales Code
                        Center(
                          child: Text(
                            "Código de ventas: OSJM01",
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Styled ListTile Menu Buttons
                        _buildMenuItem(
                          context,
                          label: "Datos Generales",
                          icon: Icons.person,
                          targetScreen: const DatosGeneralesScreen(),
                        ),
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
