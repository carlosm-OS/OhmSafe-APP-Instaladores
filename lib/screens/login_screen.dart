import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_state_provider.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/push/push_service.dart';
import '../widgets/ohm_gradient_button.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../core/auth/flujo_sesion.dart';
import 'contrasenas_screen.dart';
import 'acceso_instalador_screens.dart';

/// Inicio de sesión del instalador en dos pasos (2026-09-26):
/// 1) correo → el backend dice si ya tiene contraseña;
/// 2a) sí: pide la contraseña (y ofrece «¿Olvidaste tu contraseña?»);
/// 2b) no: primer ingreso → código al correo → bienvenida → crea su contraseña.
/// En modo mock acepta cualquier correo/contraseña no vacíos.
class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  /// Mensaje de contexto al llegar aquí desde una sesión vencida o sin red.
  final String? aviso;
  const LoginScreen({super.key, required this.onToggleTheme, this.aviso});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  /// Paso 2: el correo ya tiene contraseña y se muestra el campo.
  bool _pidePassword = false;

  late final AuthRepository _auth;

  @override
  void initState() {
    super.initState();
    _auth = sl.get<AuthRepository>();
    _error = widget.aviso;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _correoValido(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

  /// Paso 1: con el correo, el backend dice si sigue contraseña o código (primer ingreso).
  Future<void> _continuar({bool olvide = false}) async {
    final email = _emailController.text.trim();
    if (!_correoValido(email)) {
      setState(() => _error = 'Escribe tu correo completo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await _auth.solicitarAcceso(email: email, olvide: olvide);
    if (!mounted) return;
    r.fold(
      (a) {
        setState(() => _loading = false);
        if (a.pidePassword && !olvide) {
          setState(() => _pidePassword = true);
          _passwordFocus.requestFocus();
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CodigoAccesoScreen(email: email, esperaInicial: a.esperaSegundos, olvide: olvide, onToggleTheme: widget.onToggleTheme),
        ));
      },
      (f) => setState(() {
        _loading = false;
        _error = mensajeAcceso(f);
      }),
    );
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
        // Credenciales válidas: cierra el contexto de autofill para que el
        // gestor del sistema (Contraseñas de iOS / Chrome-Google en Android)
        // ofrezca GUARDAR la contraseña. La próxima vez la autocompleta.
        TextInput.finishAutofillContext();
        // Siembra nombre + perfil cacheado (foto/número) del arranque anterior
        // para que el home los pinte de inmediato, sin esperar a /perfil.
        AppStateProvider.of(context).seedFromSesion(sesion);
        // Registra el token FCM del dispositivo (best-effort) ahora que hay
        // sesión: el backend lo liga al instalador para el push de asignación.
        PushService.instance.registrarToken();
        // Onboarding: si entró con contraseña temporal, primero crea la suya
        // (pantalla forzada, sin poder saltarla) y de ahí al home.
        if (sesion.debeCambiarPassword) {
          // Primero la contraseña definitiva; la invitación a Face ID va después.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ContrasenasScreen(
                onboarding: true,
                currentPassword: _passwordController.text,
                onCompleted: (ctx) => irAlHomeTrasEntrar(ctx, onToggleTheme: widget.onToggleTheme, promptFoto: true),
              ),
            ),
          );
          return;
        }
        irAlHomeTrasEntrar(context, onToggleTheme: widget.onToggleTheme);
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
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset(
                      isDark
                          ? 'assets/assets/logo_white.png'
                          : 'assets/assets/logo_light.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "OHM",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            "SAFE",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "App de Instaladores",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    Text("Correo", style: _labelStyle(theme, isDark)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      readOnly: _pidePassword,
                      keyboardType: TextInputType.emailAddress,
                      // Sugerencias de correo del historial del teléfono (QuickType
                      // en iOS / autofill en Android).
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: _pidePassword ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: (_) => _pidePassword ? _passwordFocus.requestFocus() : (_loading ? null : _continuar()),
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: _fieldDecoration(
                        theme,
                        isDark,
                        "tucorreo@ohmsafe.com",
                        Icons.mail_outline_rounded,
                      ).copyWith(
                        suffixIcon: _pidePassword
                            ? TextButton(
                                onPressed: () => setState(() {
                                  _pidePassword = false;
                                  _passwordController.clear();
                                  _error = null;
                                }),
                                child: const Text('Cambiar'),
                              )
                            : null,
                      ),
                    ),
                    if (_pidePassword) ...[
                    const SizedBox(height: 16),

                    Text("Contraseña", style: _labelStyle(theme, isDark)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscure,
                      // El gestor de contraseñas del sistema ofrece guardar/rellenar.
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      onSubmitted: (_) => _loading ? null : _login(),
                      decoration:
                          _fieldDecoration(
                            theme,
                            isDark,
                            "••••••••",
                            Icons.lock_outline_rounded,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : () => _continuar(olvide: true),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    OhmGradientButton(
                      label: _pidePassword ? "Iniciar sesión" : "Continuar",
                      icon: _pidePassword ? Icons.login_rounded : Icons.arrow_forward_rounded,
                      loading: _loading,
                      onPressed: _pidePassword ? _login : _continuar,
                    ),
                    if (!_pidePassword) ...[
                      const SizedBox(height: 14),
                      Text(
                        '¿Primera vez? Escribe el correo que registró OhmSafe y te enviaremos un código para activar tu cuenta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
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

  InputDecoration _fieldDecoration(
    ThemeData theme,
    bool isDark,
    String hint,
    IconData icon,
  ) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: theme.extension<OhmColors>()!.surfaceContainer,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );
}
