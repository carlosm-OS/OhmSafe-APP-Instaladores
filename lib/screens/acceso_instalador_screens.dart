import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_state_provider.dart';
import '../core/auth/flujo_sesion.dart';
import '../core/di/injection_container.dart';
import '../core/error/failures.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/auth/domain/entities/acceso.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../widgets/avatar_halo.dart';
import '../widgets/ohm_gradient_button.dart';

/// Primer ingreso del instalador y «olvidé mi contraseña» (contrato `/auth/correo|codigo|activar`):
/// correo → [CodigoAccesoScreen] → (primera vez) [BienvenidaInstaladorScreen] → [CrearPasswordScreen].
/// Después de crear la contraseña el instalador ya nunca vuelve a ver este recorrido.

/// Mensaje claro para los fallos del acceso (los códigos vienen del backend).
String mensajeAcceso(Failure f) {
  if (f is NetworkFailure) return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
  if (f is ServerFailure) {
    switch (f.code) {
      case 'CODIGO_INCORRECTO':
        final quedan = f.details['intentosRestantes'];
        return quedan is num ? 'El código no es correcto. Te quedan ${quedan.toInt()} intentos.' : 'El código no es correcto.';
      case 'CODIGO_VENCIDO':
        return 'El código venció. Pide uno nuevo.';
      case 'DEMASIADOS_INTENTOS':
        return 'Demasiados intentos. Pide un código nuevo.';
      case 'ACTIVACION_VENCIDA':
        return 'La verificación venció. Vuelve a pedir tu código.';
    }
  }
  return f.message;
}

/// Encabezado común: logo OhmSafe y título.
class _Encabezado extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const _Encabezado({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(height: 40),
        ),
        const SizedBox(height: 28),
        Text(titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitulo, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
      ],
    );
  }
}

InputDecoration _decoracion(BuildContext context, String hint, IconData icono) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icono, size: 20),
      filled: true,
      fillColor: context.ohm.surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );

Widget _marco(BuildContext context, {required List<Widget> children, bool atras = true}) => Scaffold(
      appBar: atras ? AppBar(backgroundColor: Colors.transparent, elevation: 0) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ),
    );

// -----------------------------------------------------------------------------
// Código de 6 dígitos
// -----------------------------------------------------------------------------

class CodigoAccesoScreen extends StatefulWidget {
  final String email;
  final int esperaInicial;
  final bool olvide;
  final VoidCallback onToggleTheme;
  const CodigoAccesoScreen({super.key, required this.email, required this.onToggleTheme, this.esperaInicial = 60, this.olvide = false});

  @override
  State<CodigoAccesoScreen> createState() => _CodigoAccesoScreenState();
}

class _CodigoAccesoScreenState extends State<CodigoAccesoScreen> {
  final _codigo = TextEditingController();
  bool _cargando = false;
  String? _error;
  late int _espera = widget.esperaInicial;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _arrancarReloj();
  }

  void _arrancarReloj() {
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _espera = _espera > 0 ? _espera - 1 : 0);
      if (_espera == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    final codigo = _codigo.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _error = 'Escribe los 6 dígitos del código.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await sl.get<AuthRepository>().verificarCodigo(email: widget.email, codigo: codigo);
    if (!mounted) return;
    r.fold(
      (v) {
        final siguiente = v.primeraVez
            ? BienvenidaInstaladorScreen(email: widget.email, verificado: v, onToggleTheme: widget.onToggleTheme)
            : CrearPasswordScreen(email: widget.email, activacion: v.activacion, primeraVez: false, onToggleTheme: widget.onToggleTheme);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => siguiente));
      },
      (f) => setState(() {
        _cargando = false;
        _error = mensajeAcceso(f);
      }),
    );
  }

  Future<void> _reenviar() async {
    setState(() => _error = null);
    final r = await sl.get<AuthRepository>().solicitarAcceso(email: widget.email, olvide: true);
    if (!mounted) return;
    r.fold(
      (a) {
        setState(() => _espera = a.esperaSegundos > 0 ? a.esperaSegundos : 60);
        _arrancarReloj();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Si tu correo está registrado, te llegará un código nuevo.')));
      },
      (f) => setState(() => _error = mensajeAcceso(f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _marco(context, children: [
      _Encabezado(
        titulo: widget.olvide ? 'Crea una contraseña nueva' : 'Revisa tu correo',
        subtitulo: 'Si ${widget.email} está registrado como instalador OhmSafe, te enviamos un código de 6 dígitos. Revisa también tu carpeta de spam.',
      ),
      const SizedBox(height: 28),
      TextField(
        controller: _codigo,
        autofocus: true,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
        decoration: _decoracion(context, '000000', Icons.pin_outlined).copyWith(prefixIcon: null, counterText: ''),
        onChanged: (v) {
          if (v.length == 6 && !_cargando) _verificar();
        },
        onSubmitted: (_) => _cargando ? null : _verificar(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
      const SizedBox(height: 24),
      OhmGradientButton(label: 'Verificar código', icon: Icons.verified_user_outlined, loading: _cargando, onPressed: _verificar),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _espera > 0 ? null : _reenviar,
        child: Text(_espera > 0 ? 'Reenviar código en $_espera s' : 'Reenviar código'),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Bienvenida (sólo la primera vez)
// -----------------------------------------------------------------------------

class BienvenidaInstaladorScreen extends StatelessWidget {
  final String email;
  final CodigoVerificado verificado;
  final VoidCallback onToggleTheme;
  const BienvenidaInstaladorScreen({super.key, required this.email, required this.verificado, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nombre = verificado.nombre.isNotEmpty ? verificado.nombre.split(' ').first : '';
    final entrada = AppMotion.duration(context, const Duration(milliseconds: 650));
    return _marco(context, atras: false, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: entrada,
        curve: Curves.easeOutBack,
        builder: (_, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: 0.85 + 0.15 * t, child: child)),
        child: Center(
          child: AvatarHalo(
            size: 128,
            initials: initialsFromName(verificado.nombre),
            imageBase64: verificado.fotoBase64,
            placeholderIcon: Icons.engineering_rounded,
          ),
        ),
      ),
      const SizedBox(height: 28),
      Text(
        nombre.isNotEmpty ? '¡Bienvenido, $nombre!' : '¡Bienvenido!',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 14),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Instalador certificado OhmSafe', textAlign: TextAlign.center, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
      if (verificado.numeroInstalador.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Instalador #${verificado.numeroInstalador}', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 22),
      Text(
        'Te deseamos mucho éxito en cada instalación. Cada cerca que instalas protege a una familia.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
      const SizedBox(height: 32),
      OhmGradientButton(
        label: 'Crear mi contraseña',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => CrearPasswordScreen(email: email, activacion: verificado.activacion, primeraVez: true, onToggleTheme: onToggleTheme),
        )),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Crear contraseña
// -----------------------------------------------------------------------------

class CrearPasswordScreen extends StatefulWidget {
  final String email;
  final String activacion;
  final bool primeraVez;
  final VoidCallback onToggleTheme;
  const CrearPasswordScreen({super.key, required this.email, required this.activacion, required this.primeraVez, required this.onToggleTheme});

  @override
  State<CrearPasswordScreen> createState() => _CrearPasswordScreenState();
}

class _CrearPasswordScreenState extends State<CrearPasswordScreen> {
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _oculta = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final p = _password.text;
    final regla = validarPasswordNueva(p);
    if (regla != null) return setState(() => _error = regla);
    if (p != _confirmar.text) return setState(() => _error = 'Las contraseñas no coinciden.');
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await sl.get<AuthRepository>().activar(email: widget.email, activacion: widget.activacion, password: p);
    if (!mounted) return;
    r.fold(
      (sesion) {
        TextInput.finishAutofillContext(); // el gestor del sistema ofrece guardar la contraseña
        AppStateProvider.of(context).seedFromSesion(sesion);
        PushService.instance.registrarToken();
        irAlHomeTrasEntrar(context, onToggleTheme: widget.onToggleTheme);
      },
      (f) => setState(() {
        _cargando = false;
        _error = mensajeAcceso(f);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ojo = IconButton(icon: Icon(_oculta ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20), onPressed: () => setState(() => _oculta = !_oculta));
    return _marco(context, atras: !widget.primeraVez, children: [
      _Encabezado(
        titulo: widget.primeraVez ? 'Crea tu contraseña' : 'Contraseña nueva',
        subtitulo: 'Con ella entrarás a la app a partir de ahora. Usa al menos 8 caracteres, con letras y números.',
      ),
      const SizedBox(height: 28),
      // Sin la pista «contraseña nueva» de iOS: con ella iOS toma el campo al primer carácter para
      // sugerir una contraseña segura y, sin llavero de iCloud (simulador, muchos teléfonos), el
      // campo se traba y sólo muestra la primera letra. La pista «contraseña» basta para que el
      // gestor del sistema ofrezca guardarla al terminar (finishAutofillContext).
      AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: const ValueKey('password-nueva'),
            controller: _password,
            obscureText: _oculta,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.next,
            decoration: _decoracion(context, 'Contraseña nueva', Icons.lock_outline_rounded).copyWith(suffixIcon: ojo),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('password-confirmar'),
            controller: _confirmar,
            obscureText: _oculta,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _cargando ? null : _crear(),
            decoration: _decoracion(context, 'Repite la contraseña', Icons.lock_outline_rounded),
          ),
        ]),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
      const SizedBox(height: 24),
      OhmGradientButton(label: widget.primeraVez ? 'Crear contraseña y entrar' : 'Guardar y entrar', icon: Icons.login_rounded, loading: _cargando, onPressed: _crear),
    ]);
  }
}
