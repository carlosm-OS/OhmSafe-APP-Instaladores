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
import '../widgets/ayuda.dart';
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

/// Marco v2 (2026-10-23) de estas pantallas: el encabezado de todos (título grande a la izquierda,
/// sin logo ni campana: todavía no hay sesión) y el contenido en una lista con margen de 16.
Widget _marco(BuildContext context, {required String titulo, String? subtitulo, required List<Widget> children, bool atras = true}) => Scaffold(
  body: SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoFlujo(titulo: titulo, subtitulo: subtitulo, volver: atras, campana: false),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: children),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// Error del acceso junto a la acción (v2): tarjeta roja con qué pasó; el mensaje ya dice cómo seguir.
Widget _errorAcceso(BuildContext context, String error) => Semantics(
  liveRegion: true,
  child: MensajeFlujo(icono: Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, titulo: error),
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

  /// Pega el código desde el portapapeles: toma el primer número de 6 dígitos de lo copiado
  /// (sirve aunque se haya copiado la frase completa del correo).
  Future<void> _pegar() async {
    final texto = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final m = RegExp(r'(?<!\d)(\d{6})(?!\d)').firstMatch(texto) ?? RegExp(r'^(\d{6})$').firstMatch(texto.replaceAll(RegExp(r'\D'), ''));
    if (!mounted) return;
    if (m == null) {
      setState(() => _error = 'No encontramos un código de 6 dígitos en lo que copiaste.');
      return;
    }
    _codigo.text = m.group(1)!;
    _codigo.selection = TextSelection.collapsed(offset: 6);
    _verificar();
  }

  Future<void> _reenviar() async {
    setState(() => _error = null);
    final r = await sl.get<AuthRepository>().solicitarAcceso(email: widget.email, olvide: true);
    if (!mounted) return;
    r.fold((a) {
      setState(() => _espera = a.esperaSegundos > 0 ? a.esperaSegundos : 60);
      _arrancarReloj();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Si tu correo está registrado, te llegará un código nuevo.')));
    }, (f) => setState(() => _error = mensajeAcceso(f)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _marco(
      context,
      titulo: widget.olvide ? 'Crea una contraseña nueva' : 'Revisa tu correo',
      subtitulo: 'Si ${widget.email} está registrado como instalador OhmSafe, te enviamos un código de 6 dígitos. Revisa también tu carpeta de spam.',
      children: [
        const EtiquetaSeccion('Código de 6 dígitos'),
        TextField(
          controller: _codigo,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 10),
          decoration: const InputDecoration(hintText: '000000', counterText: ''),
          onChanged: (v) {
            if (v.length == 6 && !_cargando) _verificar();
          },
          onSubmitted: (_) => _cargando ? null : _verificar(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: BotonFila(etiqueta: 'Pegar código', icono: Icons.content_paste_rounded, onPressed: _cargando ? null : _pegar),
        ),
        const SizedBox(height: 8),
        if (_error != null) _errorAcceso(context, _error!),
        OhmGradientButton(
          label: 'Verificar código',
          icon: Icons.verified_user_rounded,
          loading: _cargando,
          loadingLabel: 'Verificando el código…',
          onPressed: _verificar,
        ),
        const SizedBox(height: 12),
        BotonSecundario(etiqueta: _espera > 0 ? 'Reenviar código en $_espera s' : 'Reenviar código', onPressed: _espera > 0 ? null : _reenviar),
      ],
    );
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
    final entrada = AppMotion.of(context, AppDurations.deliberate);
    // Momento de celebración: centrado, sin encabezado (no hay a dónde regresar).
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: entrada,
                  curve: AppCurves.confirm,
                  builder: (_, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
                  ),
                  child: Center(
                    child: AvatarHalo(
                      size: 128,
                      initials: initialsFromName(verificado.nombre),
                      imageBase64: verificado.fotoBase64,
                      placeholderIcon: Icons.engineering_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(nombre.isNotEmpty ? '¡Bienvenido, $nombre!' : '¡Bienvenido!', textAlign: TextAlign.center, style: theme.textTheme.displayMedium),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('Instalador certificado OhmSafe', textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                        ),
                      ],
                    ),
                  ),
                ),
                if (verificado.numeroInstalador.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Instalador #${verificado.numeroInstalador}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Te deseamos mucho éxito en cada instalación. Cada cerca que instalas protege a una familia.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                OhmGradientButton(
                  label: 'Crear mi contraseña',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CrearPasswordScreen(email: email, activacion: verificado.activacion, primeraVez: true, onToggleTheme: onToggleTheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // v2: los errores de cada campo van debajo del campo; los del servidor, en rojo junto al botón.
  String? _errorPassword;
  String? _errorConfirmar;
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
    if (regla != null) {
      return setState(() {
        _errorPassword = regla;
        _errorConfirmar = null;
      });
    }
    if (p != _confirmar.text) {
      return setState(() {
        _errorPassword = null;
        _errorConfirmar = 'Las contraseñas no coinciden.';
      });
    }
    setState(() {
      _cargando = true;
      _error = null;
      _errorPassword = null;
      _errorConfirmar = null;
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

  Widget _regla(String texto, bool cumple) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ok = context.ohm.success;
    return Semantics(
      label: '$texto: ${cumple ? 'cumple' : 'falta'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(cumple ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: cumple ? ok : cs.outline),
          const SizedBox(width: 8),
          Flexible(
            child: Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: cumple ? ok : cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ojo = IconButton(
      tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(_oculta ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
      onPressed: () => setState(() => _oculta = !_oculta),
    );
    final p = _password.text;
    return _marco(
      context,
      atras: !widget.primeraVez,
      titulo: widget.primeraVez ? 'Crea tu contraseña' : 'Contraseña nueva',
      subtitulo: 'Con ella entrarás a la app a partir de ahora.',
      children: [
        // Sin la pista «contraseña nueva» de iOS: con ella iOS toma el campo al primer carácter para
        // sugerir una contraseña segura y, sin llavero de iCloud (simulador, muchos teléfonos), el
        // campo se traba y sólo muestra la primera letra. La pista «contraseña» basta para que el
        // gestor del sistema ofrezca guardarla al terminar (finishAutofillContext).
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EtiquetaSeccion('Contraseña nueva'),
              TextField(
                key: const ValueKey('password-nueva'),
                controller: _password,
                obscureText: _oculta,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _errorPassword = null),
                decoration: InputDecoration(hintText: 'Al menos 8, con letras y números', suffixIcon: ojo, errorText: _errorPassword),
              ),
              const SizedBox(height: 12),
              // Una sola regla, la misma de Mi cuenta › Contraseña; se va marcando mientras escribes.
              TarjetaFlujo(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _regla('Al menos 8 caracteres', p.length >= 8),
                    const SizedBox(height: 8),
                    _regla('Letras y números', RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const EtiquetaSeccion('Repite la contraseña'),
              TextField(
                key: const ValueKey('password-confirmar'),
                controller: _confirmar,
                obscureText: _oculta,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_errorConfirmar != null) setState(() => _errorConfirmar = null);
                },
                onSubmitted: (_) => _cargando ? null : _crear(),
                decoration: InputDecoration(errorText: _errorConfirmar),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null) _errorAcceso(context, _error!),
        OhmGradientButton(
          label: widget.primeraVez ? 'Crear contraseña y entrar' : 'Guardar y entrar',
          icon: Icons.login_rounded,
          loading: _cargando,
          loadingLabel: 'Guardando tu contraseña…',
          onPressed: _crear,
        ),
      ],
    );
  }
}
