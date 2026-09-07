import 'package:flutter/material.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../core/error/failures.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';

class ContrasenasScreen extends StatefulWidget {
  /// Modo onboarding (primer ingreso con contraseña temporal): oculta el campo
  /// "contraseña actual" (se usa [currentPassword]), la barra inferior y el
  /// botón atrás, y al terminar llama [onCompleted] (ir al home) en vez de
  /// regresar al perfil. No se puede saltar.
  final bool onboarding;
  final String? currentPassword;
  /// Recibe el context de ESTA pantalla (válido) para navegar al home.
  final void Function(BuildContext context)? onCompleted;

  const ContrasenasScreen({
    super.key,
    this.onboarding = false,
    this.currentPassword,
    this.onCompleted,
  });

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
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Validation errors displayed inline
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
    _currentPasswordController.addListener(_onCurrentPasswordChanged);

    // Listen to focus changes to trigger UI updates (like active border shadows)
    _currentFocusNode.addListener(_onFocusChanged);
    _newFocusNode.addListener(_onFocusChanged);
    _confirmFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
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
      _confirmError = "Las contraseñas no coinciden";
    } else {
      _confirmError = null;
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _currentPasswordController.removeListener(_onCurrentPasswordChanged);
    
    _currentFocusNode.removeListener(_onFocusChanged);
    _newFocusNode.removeListener(_onFocusChanged);
    _confirmFocusNode.removeListener(_onFocusChanged);

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _currentFocusNode.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // Password validation checks based on mock requirements
  bool get _hasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _newPasswordController.text.contains(RegExp(r'[.*\-+$!@#%^&*(),.?":{}|<>]'));
  bool get _isLengthValid => _newPasswordController.text.length >= 8;
  bool get _isPasswordValid => _hasUppercase && _hasLowercase && _hasNumber && _hasSpecial && _isLengthValid;

  // Password strength logic
  int get _strengthScore {
    int score = 0;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecial) score++;
    if (_isLengthValid) score++;
    return score;
  }

  String get _strengthText {
    final text = _newPasswordController.text;
    if (text.isEmpty) return "";
    final score = _strengthScore;
    if (score <= 2) return "Débil";
    if (score <= 4) return "Aceptable";
    return "Fuerte";
  }

  Color get _strengthColor {
    final score = _strengthScore;
    if (score <= 2) return Colors.redAccent;
    if (score <= 4) return Colors.orangeAccent;
    return Colors.green;
  }

  Future<void> _submitChange() async {
    // Unfocus all fields
    _currentFocusNode.unfocus();
    _newFocusNode.unfocus();
    _confirmFocusNode.unfocus();

    // En onboarding la "actual" es la temporal con la que acaba de entrar.
    final current = widget.onboarding
        ? (widget.currentPassword ?? '')
        : _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    bool hasErrors = false;

    if (!widget.onboarding && current.isEmpty) {
      setState(() {
        _currentError = "Por favor, escribe tu contraseña actual";
      });
      hasErrors = true;
    }

    if (newPass.isEmpty) {
      setState(() {
        _newError = "Por favor, ingresa una nueva contraseña";
      });
      hasErrors = true;
    } else if (!_isPasswordValid) {
      setState(() {
        _newError = "La contraseña debe cumplir con todos los requisitos";
      });
      hasErrors = true;
    } else if (newPass == current) {
      setState(() {
        _newError = "La nueva contraseña debe ser diferente a la actual";
      });
      hasErrors = true;
    }

    if (confirm.isEmpty) {
      setState(() {
        _confirmError = "Por favor, confirma tu nueva contraseña";
      });
      hasErrors = true;
    } else if (newPass != confirm) {
      setState(() {
        _confirmError = "Las contraseñas no coinciden";
      });
      hasErrors = true;
    }

    if (hasErrors) return;

    setState(() {
      _isLoading = true;
    });

    // Cambio real contra el backend (Odoo). Opción A: primer ingreso con
    // contraseña temporal o cambio posterior.
    final result = await sl.get<PerfilRepository>().cambiarPassword(
          passwordActual: current,
          passwordNueva: newPass,
        );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    result.fold(
      (_) {
        if (widget.onboarding) {
          widget.onCompleted?.call(context); // context válido de esta pantalla
        } else {
          _showSuccessDialog();
        }
      },
      (failure) {
        setState(() {
          // AuthFailure = la contraseña actual no coincide con la de Odoo.
          _currentError =
              failure is AuthFailure ? "La contraseña actual es incorrecta" : null;
        });
        if (failure is! AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No se pudo cambiar la contraseña: ${failure.message}")),
          );
        }
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cs = Theme.of(context).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: cs.surface,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "¡Contraseña Actualizada!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Tu contraseña ha sido cambiada de forma segura. Se ha registrado tu actualización en el servidor seguro de OhmSafe.",
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to profile screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Volver al Perfil",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;

    // Styling constants matching the screenshot
    final labelColor = cs.onSurfaceVariant;
    final fillColor = ohm.surfaceContainer;

    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
      color: labelColor,
    );

    final inputStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: theme.textTheme.bodyLarge?.color,
    );

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
                            widget.onboarding ? "Crea tu contraseña" : "Perfil",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ),
                        if (!widget.onboarding)
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
                        // Subtitle: Cambio de contraseña
                        Center(
                          child: Text(
                            "Cambio de contraseña",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Current password field — oculto en onboarding (se usa la temporal)
                        if (!widget.onboarding)
                          _buildPasswordField(
                          label: "ESCRIBE LA CONTRASEÑA ACTUAL",
                          controller: _currentPasswordController,
                          focusNode: _currentFocusNode,
                          nextFocusNode: _newFocusNode,
                          obscureText: _obscureCurrent,
                          errorText: _currentError,
                          onToggleVisibility: () {
                            setState(() {
                              _obscureCurrent = !_obscureCurrent;
                            });
                          },
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                        ),

                        // New password field
                        _buildPasswordField(
                          label: "CONTRASEÑA NUEVA",
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
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                        ),

                        // Confirmar — justo debajo de "nueva" para que ambas se vean juntas
                        _buildPasswordField(
                          label: "CONFIRMAR NUEVA CONTRASEÑA",
                          controller: _confirmPasswordController,
                          focusNode: _confirmFocusNode,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitChange(),
                          obscureText: _obscureConfirm,
                          errorText: _confirmError,
                          showVisibilityToggle: false,
                          onToggleVisibility: () {},
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          customSuffix: _confirmPasswordController.text.isNotEmpty && _newPasswordController.text.isNotEmpty && _confirmPasswordController.text == _newPasswordController.text
                              ? const Padding(
                                  padding: EdgeInsets.only(right: 12.0),
                                  child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                                )
                              : null,
                        ),

                        // Password strength visual indicator
                        if (_newPasswordController.text.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Seguridad de la contraseña:",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      _strengthText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _strengthColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(3, (index) {
                                    final score = _strengthScore;
                                    bool active = false;
                                    if (score >= 1 && score <= 2 && index == 0) active = true;
                                    if (score >= 3 && score <= 4 && index <= 1) active = true;
                                    if (score >= 5 && index <= 2) active = true;

                                    return Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        height: 4,
                                        margin: EdgeInsets.only(
                                          right: index < 2 ? 6.0 : 0.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: active ? _strengthColor : (isDark ? Colors.white10 : Colors.black12),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Real-time Requirements checklist
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "La contraseña debe contener al menos:",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildRequirementRow("1 Mayúscula", _hasUppercase, labelColor),
                              const SizedBox(height: 8),
                              _buildRequirementRow("1 Minúscula", _hasLowercase, labelColor),
                              const SizedBox(height: 8),
                              _buildRequirementRow("1 Número", _hasNumber, labelColor),
                              const SizedBox(height: 8),
                              _buildRequirementRow("1 caracter especial (.*-\$+)", _hasSpecial, labelColor),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitChange,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Confirmar cambio de contraseña",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
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
          if (!widget.onboarding) const AppBottomNav(currentTab: "Perfil"),

          // Fullscreen loader overlay during save
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: cs.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Guardando contraseña...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Cifrando datos de seguridad",
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required TextStyle labelStyle,
    required TextStyle inputStyle,
    required Color fillColor,
    FocusNode? nextFocusNode,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
    String? errorText,
    bool showVisibilityToggle = true,
    Widget? customSuffix,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (focusNode.hasFocus && !hasError)
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              if (hasError)
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            style: inputStyle,
            textInputAction: textInputAction,
            autofillHints: const [AutofillHints.password],
            onSubmitted: onFieldSubmitted ?? (value) {
              if (nextFocusNode != null) {
                FocusScope.of(context).requestFocus(nextFocusNode);
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              suffixIcon: customSuffix ?? (showVisibilityToggle
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: hasError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: onToggleVisibility,
                      ),
                    )
                  : null),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasError ? Colors.redAccent : Colors.transparent,
                  width: hasError ? 1.5 : 0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasError ? Colors.redAccent : cs.primary,
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isValid, Color labelColor) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isValid ? Colors.green : labelColor.withValues(alpha: 0.4),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isValid ? Colors.green : labelColor.withValues(alpha: 0.8),
            fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
