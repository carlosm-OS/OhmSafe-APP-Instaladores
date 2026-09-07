import 'package:flutter/material.dart';
import '../core/di/injection_container.dart';
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
  static const orange = Color(0xFFFF5A00);

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
                onCompleted: () => Navigator.pushReplacement(
                  context,
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
                        const Text("SAFE", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: orange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "App de Instaladores",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
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
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        disabledBackgroundColor: theme.dividerColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text("Iniciar sesión", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
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
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF7E92A9),
      );

  InputDecoration _fieldDecoration(ThemeData theme, bool isDark, String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      );
}
