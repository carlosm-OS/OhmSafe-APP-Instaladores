import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
import '../core/error/failures.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';

/// Mi cuenta › Contraseña (v2, 2026-10-23; lienzo «12 · Contraseña»). Una sola regla, la misma del
/// alta (`validarPasswordNueva` en acceso): al menos 8 caracteres, con letras y números. Antes pedía
/// mayúscula, minúscula, número y símbolo, y el alta no: dos reglas para lo mismo.
class ContrasenasScreen extends StatefulWidget {
  /// Modo onboarding (primer ingreso con contraseña temporal): oculta el campo
  /// "contraseña actual" (se usa [currentPassword]), la barra inferior y el
  /// botón atrás, y al terminar llama [onCompleted] (ir al home) en vez de
  /// regresar al perfil. No se puede saltar.
  final bool onboarding;
  final String? currentPassword;

  /// Recibe el context de ESTA pantalla (válido) para navegar al home.
  final void Function(BuildContext context)? onCompleted;

  const ContrasenasScreen({super.key, this.onboarding = false, this.currentPassword, this.onCompleted});

  @override
  State<ContrasenasScreen> createState() => _ContrasenasScreenState();
}

class _ContrasenasScreenState extends State<ContrasenasScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _currentFocusNode = FocusNode();
  final _newFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isLoading = false;

  // Errores en línea, debajo de cada campo.
  String? _currentError;
  String? _newError;
  String? _confirmError;

  /// Falla que no es de un campo (sin red, servidor): aviso rojo junto al botón.
  String? _errorGeneral;

  /// Guardada: el formulario cede el lugar al aviso de éxito.
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
    _currentPasswordController.addListener(_onCurrentPasswordChanged);
  }

  void _onNewPasswordChanged() {
    setState(() {
      _newError = null;
      if (_confirmPasswordController.text.isNotEmpty) {
        _validateConfirmPassword();
      }
    });
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      _validateConfirmPassword();
    });
  }

  void _onCurrentPasswordChanged() {
    setState(() {
      _currentError = null;
    });
  }

  void _validateConfirmPassword() {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) {
      _confirmError = null;
    } else if (confirm != newPass) {
      _confirmError = "Las contraseñas no coinciden.";
    } else {
      _confirmError = null;
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _currentPasswordController.removeListener(_onCurrentPasswordChanged);

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _currentFocusNode.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // La misma regla que el alta (validarPasswordNueva): 8 caracteres y letras con números.
  bool get _isLengthValid => _newPasswordController.text.length >= 8;
  bool get _hasLettersAndNumbers => RegExp(r'[A-Za-z]').hasMatch(_newPasswordController.text) && RegExp(r'\d').hasMatch(_newPasswordController.text);
  bool get _isPasswordValid => _isLengthValid && _hasLettersAndNumbers;

  Future<void> _submitChange() async {
    if (_isLoading) return;
    // Unfocus all fields
    _currentFocusNode.unfocus();
    _newFocusNode.unfocus();
    _confirmFocusNode.unfocus();

    // En onboarding la "actual" es la temporal con la que acaba de entrar.
    final current = widget.onboarding ? (widget.currentPassword ?? '') : _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    bool hasErrors = false;
    setState(() => _errorGeneral = null);

    if (!widget.onboarding && current.isEmpty) {
      setState(() {
        _currentError = "Escribe tu contraseña actual.";
      });
      hasErrors = true;
    }

    if (newPass.isEmpty) {
      setState(() {
        _newError = "Escribe tu contraseña nueva.";
      });
      hasErrors = true;
    } else if (!_isLengthValid) {
      setState(() {
        _newError = "Usa al menos 8 caracteres.";
      });
      hasErrors = true;
    } else if (!_hasLettersAndNumbers) {
      setState(() {
        _newError = "Combina letras y números.";
      });
      hasErrors = true;
    } else if (newPass == current) {
      setState(() {
        _newError = "Escribe una distinta a la actual.";
      });
      hasErrors = true;
    }

    if (confirm.isEmpty) {
      setState(() {
        _confirmError = "Escribe otra vez tu contraseña nueva.";
      });
      hasErrors = true;
    } else if (newPass != confirm) {
      setState(() {
        _confirmError = "Las contraseñas no coinciden.";
      });
      hasErrors = true;
    }

    if (hasErrors || !_isPasswordValid) return;

    setState(() {
      _isLoading = true;
    });

    // Cambio real contra el backend (Odoo). Opción A: primer ingreso con
    // contraseña temporal o cambio posterior.
    final result = await sl.get<PerfilRepository>().cambiarPassword(passwordActual: current, passwordNueva: newPass);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    result.fold(
      (_) {
        if (widget.onboarding) {
          widget.onCompleted?.call(context); // context válido de esta pantalla
        } else {
          setState(() => _listo = true);
        }
      },
      (failure) {
        setState(() {
          // AuthFailure = la contraseña actual no coincide con la de Odoo.
          _currentError = failure is AuthFailure ? "No es tu contraseña actual. Revísala y vuelve a intentar." : null;
          // El repo ya entrega un mensaje humano (sin red, servidor).
          if (failure is! AuthFailure) _errorGeneral = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoFlujo(
              titulo: widget.onboarding ? 'Crea tu contraseña' : (_listo ? 'Contraseña actualizada' : 'Contraseña'),
              subtitulo: widget.onboarding ? 'Con ella entrarás a la app a partir de ahora.' : null,
              volver: !widget.onboarding,
              campana: !widget.onboarding,
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: _listo ? _exito(context) : _formulario(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Éxito en la misma pantalla (antes: diálogo «¡Contraseña Actualizada!» con texto de relleno).
  List<Widget> _exito(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Semantics(
        liveRegion: true,
        child: TarjetaFlujo(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: context.ohm.success, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text('Listo. Usa tu contraseña nueva la próxima vez que entres.', style: theme.textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      OhmGradientButton(label: 'Volver al perfil', onPressed: () => Navigator.pop(context)),
    ];
  }

  List<Widget> _formulario(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return [
      // Current password field — oculto en onboarding (se usa la temporal)
      if (!widget.onboarding)
        _buildPasswordField(
          label: "Contraseña actual",
          controller: _currentPasswordController,
          focusNode: _currentFocusNode,
          nextFocusNode: _newFocusNode,
          obscureText: _obscureCurrent,
          errorText: _currentError,
          autofill: const [AutofillHints.password],
          onToggleVisibility: () {
            setState(() {
              _obscureCurrent = !_obscureCurrent;
            });
          },
        ),

      // Sin la pista «contraseña nueva» de iOS en los campos nuevos: con ella iOS toma el campo al
      // primer carácter para sugerir una contraseña y, sin llavero de iCloud, el campo se traba
      // (mismo arreglo que en acceso, 911d413).
      _buildPasswordField(
        label: "Contraseña nueva",
        controller: _newPasswordController,
        focusNode: _newFocusNode,
        nextFocusNode: _confirmFocusNode,
        obscureText: _obscureNew,
        errorText: _newError,
        onToggleVisibility: () {
          setState(() {
            _obscureNew = !_obscureNew;
          });
        },
      ),

      // Una sola regla, la del alta; se va marcando mientras escribes.
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TarjetaFlujo(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRequirementRow("Al menos 8 caracteres", _isLengthValid),
              const SizedBox(height: 8),
              _buildRequirementRow("Letras y números", _hasLettersAndNumbers),
            ],
          ),
        ),
      ),

      // Confirmar — justo debajo de la regla para que ambas se vean juntas
      _buildPasswordField(
        label: "Repite la contraseña nueva",
        controller: _confirmPasswordController,
        focusNode: _confirmFocusNode,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submitChange(),
        obscureText: _obscureNew,
        errorText: _confirmError,
        showVisibilityToggle: false,
        onToggleVisibility: () {},
        customSuffix:
            _confirmPasswordController.text.isNotEmpty &&
                _newPasswordController.text.isNotEmpty &&
                _confirmPasswordController.text == _newPasswordController.text
            ? Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(Icons.check_circle_rounded, color: context.ohm.success, size: 22, semanticLabel: 'Coinciden'),
              )
            : null,
      ),

      if (_errorGeneral != null)
        MensajeFlujo(
          icono: Icons.error_outline_rounded,
          color: cs.error,
          titulo: 'No se cambió tu contraseña',
          texto: '${_errorGeneral!} Tu contraseña actual sigue funcionando.',
        ),

      const SizedBox(height: 4),
      OhmGradientButton(
        label: _errorGeneral != null ? 'Volver a intentar' : 'Guardar contraseña nueva',
        loading: _isLoading,
        loadingLabel: 'Guardando tu contraseña nueva…',
        onPressed: _submitChange,
      ),
    ];
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    FocusNode? nextFocusNode,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
    String? errorText,
    bool showVisibilityToggle = true,
    Widget? customSuffix,
    List<String>? autofill,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EtiquetaSeccion(label),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: false,
            style: Theme.of(context).textTheme.bodyLarge,
            textInputAction: textInputAction,
            autofillHints: autofill,
            onSubmitted:
                onFieldSubmitted ??
                (value) {
                  if (nextFocusNode != null) {
                    FocusScope.of(context).requestFocus(nextFocusNode);
                  }
                },
            decoration: InputDecoration(
              errorText: errorText,
              errorMaxLines: 2,
              suffixIcon:
                  customSuffix ??
                  (showVisibilityToggle
                      ? IconButton(
                          tooltip: obscureText ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                          onPressed: onToggleVisibility,
                        )
                      : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isValid) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ok = context.ohm.success;
    return Semantics(
      label: '$text: ${isValid ? 'cumple' : 'falta'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isValid ? ok : cs.outline, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: isValid ? ok : cs.onSurfaceVariant, fontWeight: isValid ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
