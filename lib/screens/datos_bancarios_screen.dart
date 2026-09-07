import 'package:flutter/material.dart';
import '../controllers/app_state_provider.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/app_bottom_nav.dart';

class DatosBancariosScreen extends StatefulWidget {
  const DatosBancariosScreen({super.key});

  @override
  State<DatosBancariosScreen> createState() => _DatosBancariosScreenState();
}

class _DatosBancariosScreenState extends State<DatosBancariosScreen> {
  late TextEditingController _holderController;
  late TextEditingController _clabeController;
  late TextEditingController _accountController;
  
  String? _selectedBank;
  bool _initialized = false;

  // Catalog of Mexican banks with their CLABE codes
  static const Map<String, String> _bankCatalog = {
    '002': 'BANAMEX',
    '012': 'BBVA',
    '014': 'SANTANDER',
    '021': 'HSBC',
    '030': 'BANBAJIO',
    '044': 'SCOTIABANK',
    '058': 'BANREGIO',
    '072': 'BANORTE',
    '112': 'BANJERCITO',
    '127': 'BANCO AZTECA',
    '137': 'BANCOPPEL',
    '555': 'BBVA', // Mapping for mock data CLABE: 5552667879000
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final state = AppStateProvider.of(context);
      _holderController = TextEditingController(text: state.bankHolder);
      _clabeController = TextEditingController(text: state.bankClabe);
      _accountController = TextEditingController(text: state.bankAccount);
      
      // Determine initial selected bank
      final initialBank = state.bankName.toUpperCase();
      if (_bankCatalog.values.contains(initialBank)) {
        _selectedBank = initialBank;
      } else {
        _selectedBank = 'BBVA'; // default fallback
      }

      // Add listener to auto-detect bank from the first 3 digits of CLABE
      _clabeController.addListener(_onClabeChanged);
      _initialized = true;
    }
  }

  void _onClabeChanged() {
    final text = _clabeController.text.trim();
    if (text.length >= 3) {
      final bankCode = text.substring(0, 3);
      if (_bankCatalog.containsKey(bankCode)) {
        final matchedBank = _bankCatalog[bankCode]!;
        if (_selectedBank != matchedBank) {
          setState(() {
            _selectedBank = matchedBank;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _clabeController.removeListener(_onClabeChanged);
    _holderController.dispose();
    _clabeController.dispose();
    _accountController.dispose();
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

    // Get unique list of bank names for dropdown items
    final bankOptions = _bankCatalog.values.toSet().toList();

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
                        // Subtitle: Datos Bancarios
                        Center(
                          child: Text(
                            "Datos Bancarios",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form fields
                        _buildField(
                          label: "NOMBRE DEL TITULAR DE LA CUENTA",
                          controller: _holderController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                        ),
                        _buildField(
                          label: "NÚMERO CLABE",
                          controller: _clabeController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          keyboardType: TextInputType.number,
                        ),

                        // Banco Dropdown Menu
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "BANCO",
                              style: labelStyle,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedBank,
                              style: inputStyle,
                              dropdownColor: cs.surface,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                              items: bankOptions.map((bank) {
                                return DropdownMenuItem<String>(
                                  value: bank,
                                  child: Text(bank),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBank = value;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                        _buildField(
                          label: "NÚMERO DE CUENTA",
                          controller: _accountController,
                          labelStyle: labelStyle,
                          inputStyle: inputStyle,
                          fillColor: fillColor,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final holder = _holderController.text.trim();
                              final clabe = _clabeController.text.trim();
                              final name = _selectedBank ?? "";
                              final account = _accountController.text.trim();

                              if (holder.isEmpty || clabe.isEmpty || name.isEmpty || account.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Por favor, llena todos los campos"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              state.updateBankInfo(
                                holder: holder,
                                clabe: clabe,
                                name: name,
                                account: account,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Datos bancarios guardados correctamente",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: cs.primary,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Guardar",
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required TextStyle labelStyle,
    required TextStyle inputStyle,
    required Color fillColor,
    TextInputType keyboardType = TextInputType.text,
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
