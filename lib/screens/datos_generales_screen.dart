import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../core/di/injection_container.dart';
import '../core/theme/app_theme_extension.dart';
import '../features/perfil/domain/repositories/perfil_repository.dart';
import '../widgets/ohm_gradient_button.dart';

class DatosGeneralesScreen extends StatefulWidget {
  const DatosGeneralesScreen({super.key});

  @override
  State<DatosGeneralesScreen> createState() => _DatosGeneralesScreenState();
}

class _DatosGeneralesScreenState extends State<DatosGeneralesScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _apellidosController;
  late TextEditingController _telefonoController;
  late TextEditingController _correoController;
  late TextEditingController _curpController;

  // Identificadores del instalador (solo lectura, vienen de Odoo).
  String _numeroInstalador = '';
  String _codigoVenta = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final state = AppStateProvider.of(context);
      // Split installerName into Name and Apellidos
      final nameParts = state.installerName.split(' ');
      final nombre = nameParts.isNotEmpty ? nameParts.first : "";
      final apellidos = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "Mora Gutierrez";

      _nombreController = TextEditingController(text: nombre);
      _apellidosController = TextEditingController(text: apellidos);
      _telefonoController = TextEditingController(text: state.installerPhone);
      _correoController = TextEditingController(text: state.installerEmail);
      _curpController = TextEditingController(text: state.installerCurp);
      _initialized = true;
      _cargarDeOdoo(); // espejo Odoo→app: refresca con lo que hay en Odoo
    }
  }

  /// Lee el perfil de Odoo y refresca los campos (espejo Odoo→app).
  Future<void> _cargarDeOdoo() async {
    final result = await sl.get<PerfilRepository>().getPerfil();
    if (!mounted) return;
    result.fold((perfil) {
      final parts = perfil.nombre.trim().split(' ');
      setState(() {
        if (perfil.nombre.isNotEmpty) {
          _nombreController.text = parts.first;
          if (parts.length > 1) _apellidosController.text = parts.sublist(1).join(' ');
        }
        if (perfil.telefono.isNotEmpty) _telefonoController.text = perfil.telefono;
        if (perfil.email.isNotEmpty) _correoController.text = perfil.email;
        _curpController.text = perfil.curp; // refleja el valor de Odoo (aunque esté vacío)
        _numeroInstalador = perfil.numeroInstalador;
        _codigoVenta = perfil.codigoVenta;
      });
    }, (_) {/* si falla, se quedan los valores locales */});
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    _curpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final isDark = theme.brightness == Brightness.dark;
    final state = AppStateProvider.of(context);

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
                        // Subtitle: Datos Generales
                        Center(
                          child: Text(
                            "Datos Generales",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Identidad del instalador (solo lectura, viene de Odoo)
                        _buildIdentidadCard(context),
                        const SizedBox(height: 24),

                        // Form fields
                        _buildField(
                          label: "NOMBRE(S)",
                          controller: _nombreController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                        ),
                        _buildField(
                          label: "APELLIDOS",
                          controller: _apellidosController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                        ),
                        _buildField(
                          label: "TELÉFONO",
                          controller: _telefonoController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildField(
                          label: "CORREO ELECTRÓNICO",
                          controller: _correoController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildField(
                          label: "CURP",
                          controller: _curpController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),

                        // Save Button
                        OhmGradientButton(
                          label: "Guardar",
                          onPressed: () async {
                            final name = "${_nombreController.text.trim()} ${_apellidosController.text.trim()}".trim();
                            final phone = _telefonoController.text.trim();
                            final email = _correoController.text.trim();
                            final curp = _curpController.text.trim();

                            if (name.isEmpty || phone.isEmpty || email.isEmpty || curp.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Por favor, llena todos los campos"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            // Estado local (UI) + persistencia en el backend (Odoo).
                            state.updateInstallerInfo(
                              name: name,
                              phone: phone,
                              email: email,
                              curp: curp,
                            );
                            final result = await sl.get<PerfilRepository>().updatePerfil(
                                  nombre: name,
                                  telefono: phone,
                                  curp: curp,
                                );
                            if (!mounted) return;
                            result.fold(
                              (_) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Datos guardados correctamente",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: cs.primary,
                                ),
                              ),
                              (failure) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("No se pudieron guardar: ${failure.message}"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              ),
                            );
                          },
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

  /// Tarjeta de identidad del instalador: número (ID visible) y código de venta
  /// para el bono por referidos. Solo lectura; el código se puede copiar.
  Widget _buildIdentidadCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ohm = context.ohm;
    final tieneNumero = _numeroInstalador.isNotEmpty;
    final tieneCodigo = _codigoVenta.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ohm.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número de instalador
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Text("N.º de instalador",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              const Spacer(),
              Text(tieneNumero ? "#$_numeroInstalador" : "Se asigna al validar",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tieneNumero ? cs.onSurface : cs.onSurfaceVariant)),
            ],
          ),
          Divider(height: 24, color: cs.outlineVariant),
          // Código de venta (bono por referidos)
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 20, color: ohm.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Código de venta",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text("Compártelo: si venden con él, ganas bono",
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (tieneCodigo)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _codigoVenta));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text("Código copiado"), backgroundColor: ohm.accent),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ohm.accentContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_codigoVenta,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ohm.onAccentContainer)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 15, color: ohm.onAccentContainer),
                      ],
                    ),
                  ),
                )
              else
                Text("Se asigna al validar",
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required TextStyle labelStyle,
    required TextStyle inputStyle,
    required Color fillColor,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: inputStyle,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
