import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_state_provider.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../core/push/push_service.dart';
import '../widgets/ohm_gradient_button.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../core/auth/flujo_sesion.dart';
import '../core/auth/session_manager.dart';
import 'contrasenas_screen.dart';
import 'acceso_instalador_screens.dart';

/// Inicio de sesión del instalador en dos pasos (2026-09-26):
/// 1) correo → el backend dice si ya tiene contraseña;
/// 2a) sí: pide la contraseña (y ofrece «¿Olvidaste tu contraseña?»);
/// 2b) no: primer ingreso → código al correo → bienvenida → crea su contraseña.
/// Si en este teléfono ya entró alguien, abre directo en la contraseña con su
/// correo (y «Cambiar» para otra persona): quien ya tiene cuenta no ve el paso
/// de primera vez. En modo mock acepta cualquier correo/contraseña no vacíos.
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

  /// Mientras se lee el último correo del teléfono no se pinta el paso 1.
  bool _leyendoCorreo = true;

  late final AuthRepository _auth;

  @override
  void initState() {
    super.initState();
    _auth = sl.get<AuthRepository>();
    _error = widget.aviso;
    _recordarCorreo();
  }

  Future<void> _recordarCorreo() async {
    String? correo;
    try {
      correo = await sl.get<SessionManager>().ultimoCorreo();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _leyendoCorreo = false;
      if (correo != null && correo.isNotEmpty) {
        _emailController.text = correo;
        _pidePassword = true;
      }
    });
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CodigoAccesoScreen(email: email, esperaInicial: a.esperaSegundos, olvide: olvide, onToggleTheme: widget.onToggleTheme),
          ),
        );
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
    final result = await _auth.login(email: _emailController.text, password: _passwordController.text);
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
    // El aviso con que se llega (sesión vencida, sin red) no es un error de lo que escribiste: va en
    // tarjeta blanca; los errores de esta pantalla, en rojo junto al botón (v2, 2026-10-23).
    final esAviso = _error != null && _error == widget.aviso;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Puerta de entrada: aquí el logo es la identidad (todavía no hay Home).
                    Image.asset(
                      isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("OHM", style: theme.textTheme.displaySmall),
                          Text("SAFE", style: theme.textTheme.displaySmall?.copyWith(color: cs.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "App de Instaladores",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),

                    const EtiquetaSeccion("Correo"),
                    TextField(
                      controller: _emailController,
                      readOnly: _pidePassword,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      // Sugerencias de correo del historial del teléfono (QuickType
                      // en iOS / autofill en Android).
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: _pidePassword ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: (_) => _pidePassword ? _passwordFocus.requestFocus() : (_loading ? null : _continuar()),
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: "tucorreo@ohmsafe.com",
                        prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                        suffixIcon: _pidePassword
                            ? TextButton(
                                onPressed: () => setState(() {
                                  _pidePassword = false;
                                  _passwordController.clear();
                                  _error = null;
                                }),
                                style: TextButton.styleFrom(foregroundColor: cs.onSurface, minimumSize: const Size(48, 44)),
                                child: const Text('Cambiar'),
                              )
                            : null,
                      ),
                    ),
                    if (_pidePassword) ...[
                      const SizedBox(height: 20),
                      const EtiquetaSeccion("Contraseña"),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscure,
                        // El gestor de contraseñas del sistema ofrece guardar/rellenar.
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        style: theme.textTheme.bodyLarge,
                        onSubmitted: (_) => _loading ? null : _login(),
                        decoration: InputDecoration(
                          hintText: "••••••••",
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : () => _continuar(olvide: true),
                          style: TextButton.styleFrom(foregroundColor: cs.onSurface, minimumSize: const Size(48, 44)),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    if (_error != null)
                      Semantics(
                        liveRegion: true,
                        child: esAviso
                            ? MensajeFlujo(icono: Icons.info_outline_rounded, color: context.ohm.info, titulo: _error!)
                            : MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: _error!),
                      ),
                    OhmGradientButton(
                      label: _pidePassword ? "Iniciar sesión" : "Continuar",
                      icon: _pidePassword ? Icons.login_rounded : Icons.arrow_forward_rounded,
                      loading: _loading,
                      loadingLabel: _pidePassword ? 'Entrando…' : 'Revisando tu correo…',
                      onPressed: _pidePassword ? _login : _continuar,
                    ),
                    if (!_pidePassword && !_leyendoCorreo) ...[
                      const SizedBox(height: 14),
                      Text(
                        '¿Primera vez? Escribe el correo que registró OhmSafe y te enviaremos un código para activar tu cuenta.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
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
}
