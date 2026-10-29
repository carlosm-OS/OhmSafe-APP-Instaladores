import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_state_provider.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';

/// Mi cuenta › Datos bancarios (v2, 2026-10-23): encabezado de todos, campos con su error debajo
/// (nada de SnackBar rojo) y CLABE de 18 dígitos. Ojo: hoy los datos sólo se guardan en la memoria de
/// la app (`AppState.updateBankInfo`); no viajan a OhmSafe. El mensaje de éxito lo dice tal cual.
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

  // Errores por campo (v2: debajo del campo, con qué arreglar).
  String? _errorTitular;
  String? _errorClabe;
  String? _errorCuenta;

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

  void _guardar() {
    final holder = _holderController.text.trim();
    final clabe = _clabeController.text.trim();
    final name = _selectedBank ?? "";
    final account = _accountController.text.trim();

    setState(() {
      _errorTitular = holder.isEmpty ? 'Escribe el nombre como aparece en tu cuenta.' : null;
      _errorClabe = clabe.length != 18 ? 'La CLABE tiene 18 dígitos; llevas ${clabe.length}.' : null;
      _errorCuenta = account.isEmpty ? 'Escribe tu número de cuenta.' : null;
    });
    if (_errorTitular != null || _errorClabe != null || _errorCuenta != null || name.isEmpty) return;

    AppStateProvider.of(context).updateBankInfo(holder: holder, clabe: clabe, name: name, account: account);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo. Se guardaron en este teléfono.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Get unique list of bank names for dropdown items
    final bankOptions = _bankCatalog.values.toSet().toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoFlujo(titulo: 'Datos bancarios', subtitulo: 'Donde recibes tus pagos'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _campo(
                    etiqueta: 'Nombre del titular de la cuenta',
                    controller: _holderController,
                    error: _errorTitular,
                    alCambiar: () => _errorTitular = null,
                    autofill: const [AutofillHints.name],
                    capitalizacion: TextCapitalization.words,
                  ),
                  _campo(
                    etiqueta: 'CLABE',
                    controller: _clabeController,
                    error: _errorClabe,
                    alCambiar: () => _errorClabe = null,
                    teclado: TextInputType.number,
                    formatos: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
                    ayuda: '18 dígitos. El banco se elige solo con los 3 primeros.',
                  ),
                  const EtiquetaSeccion('Banco'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBank,
                      // La CLABE elige el banco: la llave hace que el campo muestre el nuevo valor.
                      key: ValueKey(_selectedBank),
                      style: theme.textTheme.bodyLarge,
                      dropdownColor: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
                      items: bankOptions.map((bank) => DropdownMenuItem<String>(value: bank, child: Text(bank))).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBank = value;
                        });
                      },
                    ),
                  ),
                  _campo(
                    etiqueta: 'Número de cuenta',
                    controller: _accountController,
                    error: _errorCuenta,
                    alCambiar: () => _errorCuenta = null,
                    teclado: TextInputType.number,
                    formatos: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 4),
                  OhmGradientButton(label: 'Guardar datos bancarios', onPressed: _guardar),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Por ahora se quedan en este teléfono y no se envían a OhmSafe. Si cambia la cuenta donde recibes tus pagos, avísanos desde Ayuda.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required String etiqueta,
    required TextEditingController controller,
    required String? error,
    required VoidCallback alCambiar,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter>? formatos,
    List<String>? autofill,
    TextCapitalization capitalizacion = TextCapitalization.none,
    String? ayuda,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EtiquetaSeccion(etiqueta),
          TextField(
            controller: controller,
            keyboardType: teclado,
            inputFormatters: formatos,
            autofillHints: autofill,
            textCapitalization: capitalizacion,
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: (_) {
              if (error != null) setState(alCambiar);
            },
            decoration: InputDecoration(errorText: error, helperText: error == null ? ayuda : null, errorMaxLines: 2, helperMaxLines: 2),
          ),
        ],
      ),
    );
  }
}
