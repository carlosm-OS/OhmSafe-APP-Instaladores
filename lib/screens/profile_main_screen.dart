import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/app_state_provider.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'datos_generales_screen.dart';
import 'datos_bancarios_screen.dart';
import 'contrasenas_screen.dart';
import 'facturacion_screen.dart';
import 'login_screen.dart';

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

  Future<void> _pickImage(BuildContext context) async {
    final state = AppStateProvider.of(context);
    try {
      final XFile? selected = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024, // comprime en móvil (en macOS lo maneja el límite del backend)
        maxHeight: 1024,
      );
      if (selected != null) {
        state.updateAvatarPath(selected.path); // muestra la foto de inmediato
        // Sube la imagen a Odoo (foto del contacto del instalador).
        final bytes = await selected.readAsBytes();
        final result = await sl
            .get<PerfilRepository>()
            .subirAvatar(contenidoBase64: base64Encode(bytes));
        if (!mounted) return;
        result.fold(
          (_) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Foto de perfil guardada", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Color(0xFFFF5A00),
            ),
          ),
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Foto lista localmente; no se guardó en el servidor: ${failure.message}"),
              backgroundColor: Colors.redAccent,
            ),
          ),
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

  /// Pide confirmación, cierra la sesión (limpia sesión + token) y vuelve al
  /// login borrando el stack de navegación.
  Future<void> _cerrarSesion(BuildContext context) async {
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5A00)),
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
                            const Text(
                              "SAFE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5A00),
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
                                color: theme.iconTheme.color?.withOpacity(0.7),
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
                                initials: "JM",
                                imagePath: state.customAvatarPath,
                                placeholderIcon: Icons.engineering_rounded,
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _pickImage(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5A00),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
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
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Star Rating Row
                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFFF8D28), size: 24),
                              Icon(Icons.star_rounded, color: Color(0xFFFF8D28), size: 24),
                              Icon(Icons.star_rounded, color: Color(0xFFFF8D28), size: 24),
                              Icon(Icons.star_rounded, color: Color(0xFFFF8D28), size: 24),
                              Icon(Icons.star_half_rounded, color: Color(0xFFFF8D28), size: 24),
                              SizedBox(width: 8),
                              Text(
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
                        const Center(
                          child: Text(
                            "Código de ventas: OSJM01",
                            style: TextStyle(
                              color: Color(0xFFFF5A00),
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
                            foregroundColor: const Color(0xFFFF5A00),
                            side: const BorderSide(color: Color(0xFFFF5A00), width: 1.5),
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
    final isDark = theme.brightness == Brightness.dark;

    // El color de fondo va en el Material (no en un Container decorado), para
    // que el ListTile pinte su fondo/ripple directamente sobre él. Así se evita
    // la aserción de Flutter "ListTile background color or ink splashes may be
    // invisible" que ocurre cuando un DecoratedBox con color se interpone.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6F8),
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
                  ? const Color(0xFF334155).withOpacity(0.5)
                  : const Color(0xFFE2E8F0).withOpacity(0.4),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(
            icon,
            color: const Color(0xFFFF5A00),
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.85),
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
