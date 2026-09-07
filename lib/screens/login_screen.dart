import 'package:flutter/material.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ohm_gradient_button.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import 'home_screen.dart';
import 'contrasenas_screen.dart';

/// Pantalla de inicio de sesión del instalador (credenciales de Odoo vía API).
/// En modo mock acepta cualquier correo/contraseña no vacíos.
class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const LoginScreen({super.key, required this.onToggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late final AuthRepository _auth;

  @override
  void initState() {
    super.initState();
    _auth = sl.get<AuthRepository>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    result.fold(
      (sesion) {
        // Onboarding: si entró con contraseña temporal, primero crea la suya
        // (pantalla forzada, sin poder saltarla) y de ahí al home.
        if (sesion.debeCambiarPassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ContrasenasScreen(
                onboarding: true,
                currentPassword: _passwordController.text,
                onCompleted: (ctx) => Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme, promptFoto: true)),
                ),
              ),
            ),
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)),
        );
      },
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("OHM", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color)),
                        Text("SAFE", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: cs.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "App de Instaladores",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 36),

                  Text("Correo", style: _labelStyle(theme, isDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: _fieldDecoration(theme, isDark, "tucorreo@ohmsafe.com", Icons.mail_outline_rounded),
                  ),
                  const SizedBox(height: 16),

                  Text("Contraseña", style: _labelStyle(theme, isDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onSubmitted: (_) => _loading ? null : _login(),
                    decoration: _fieldDecoration(theme, isDark, "••••••••", Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 28),
                  OhmGradientButton(
                    label: "Iniciar sesión",
                    icon: Icons.login_rounded,
                    loading: _loading,
                    onPressed: _login,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(ThemeData theme, bool isDark) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
      );

  InputDecoration _fieldDecoration(ThemeData theme, bool isDark, String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: theme.extension<OhmColors>()!.surfaceContainer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      );
}
