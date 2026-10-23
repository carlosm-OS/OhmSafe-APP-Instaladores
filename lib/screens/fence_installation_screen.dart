import 'package:flutter/material.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import '../widgets/cancellation_flow.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

class FenceInstallationScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const FenceInstallationScreen({super.key, required this.ticket});

  @override
  State<FenceInstallationScreen> createState() => _FenceInstallationScreenState();
}

class _FenceInstallationScreenState extends State<FenceInstallationScreen> {
  // Counters for materials with default initial values matching the mock image (5, 5, 5, 5, 1, 3)
  final Map<String, int> _materials = {'Postes esquina': 5, 'Postes de paso': 5, 'Líneas': 5, 'Abanicos': 5, 'Letrero Ohmsafe': 1, 'Letrero Precaución': 3};

  /// Metros que manda el servidor (el real de la inspección si ya se midió; si no, el agendado).
  /// La copia de la orden que trae la pantalla puede venir de la lista cargada ANTES de la
  /// inspección (bug visto con i45: se midieron 100 m y aquí salían los 90 agendados).
  String? _metrosServidor;

  @override
  void initState() {
    super.initState();
    _cargarMetros();
  }

  Future<void> _cargarMetros() async {
    final id = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    if (id.isEmpty) return;
    final r = await sl.get<OrdenesRepository>().getOrden(id);
    if (!mounted) return;
    r.fold((orden) {
      final m = orden.metraje.trim();
      if (m.isEmpty || m == '0') return;
      final texto = RegExp(r'^[0-9.,]+$').hasMatch(m) ? '$m m' : m;
      setState(() => _metrosServidor = texto);
      // Que los pasos siguientes (vincular, cierre) usen el mismo dato.
      final details = widget.ticket['details'];
      if (details is Map) details['metraje'] = texto;
    }, (_) {});
  }

  void _increment(String material) {
    setState(() {
      _materials[material] = (_materials[material] ?? 0) + 1;
    });
  }

  void _decrement(String material) {
    setState(() {
      final current = _materials[material] ?? 0;
      if (current > 0) {
        _materials[material] = current - 1;
      }
    });
  }

  bool _isSending = false;

  /// Mensaje humano del repositorio si no se pudo guardar; va junto al botón (v2).
  String? _error;

  /// Nombre visible de cada material. La llave del mapa es la que ya guarda el servidor y no cambia.
  static const Map<String, String> _nombreVisible = {'Letrero Ohmsafe': 'Letrero OhmSafe'};

  /// Envía el registro de instalación al backend: los conteos con columna propia
  /// en Odoo (postes/abanicos) más el desglose completo de materiales. Solo si
  /// tiene éxito regresa 'installation_completed' para avanzar el flujo.
  Future<void> _guardarInstalacion() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    final registro = <String, dynamic>{
      'postesEsquina': _materials['Postes esquina'],
      'postesPaso': _materials['Postes de paso'],
      'abanicos': _materials['Abanicos'],
      'materiales': _materials,
    };
    final id = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    final result = await sl.get<OrdenesRepository>().guardarInstalacion(id, registro);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'installation_completed'),
      (failure) => setState(() {
        _isSending = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final details = widget.ticket["details"] as Map<String, String>;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // v2 (2026-10-23): encabezado único.
            EncabezadoFlujo(titulo: "Cerca eléctrica", subtitulo: widget.ticket["user"] ?? "Cliente", alVolver: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  const EtiquetaSeccion("Medidas"),
                  GrupoFilas(
                    children: [
                      FilaFlujo(
                        titulo: "Metros a instalar",
                        subtitulo: "El real que mediste en la inspección",
                        trailing: Text(
                          _metrosServidor ?? details["metraje"] ?? "0 m",
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const EtiquetaSeccion("Conteo de materiales"),
                  GrupoFilas(
                    pie: "Los contadores traen números de inicio: corrígelos con lo que realmente instalaste.",
                    children: [for (final material in _materials.keys) _buildMaterialRow(material, _materials[material] ?? 0)],
                  ),

                  // Lo que pasa, pasa junto al botón (v2).
                  if (_error != null)
                    MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: "No pudimos guardar las medidas de la cerca", texto: _error),
                  OhmGradientButton(
                    label: "Guardar medidas de la cerca",
                    loading: _isSending,
                    loadingLabel: "Guardando la cerca…",
                    onPressed: _guardarInstalacion,
                  ),
                  const SizedBox(height: 12),
                  BotonSecundario(etiqueta: "Cancelar instalación", peligro: true, onPressed: () => showCancellationFlow(context, widget.ticket)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(String name, int value) {
    return FilaFlujo(
      titulo: _nombreVisible[name] ?? name,
      trailing: Contador(valor: '$value', alQuitar: value > 0 ? () => _decrement(name) : null, alAgregar: () => _increment(name)),
    );
  }
}

/// Contador − n + (v2): dos píldoras [BotonFila] de 44 de alto como mínimo, con nombre para el lector
/// de pantalla («Quitar uno», «Agregar uno»). Lo usan la cerca y la reparación.
class Contador extends StatelessWidget {
  const Contador({super.key, required this.valor, required this.alQuitar, required this.alAgregar, this.sufijo = ''});

  final String valor;
  final VoidCallback? alQuitar;
  final VoidCallback? alAgregar;

  /// «m» para los metros de un hilo.
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: alQuitar != null,
          label: 'Quitar uno',
          onTap: alQuitar,
          excludeSemantics: true,
          child: BotonFila(etiqueta: '−', onPressed: alQuitar),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Text(
            '$valor$sufijo',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Semantics(
          button: true,
          enabled: alAgregar != null,
          label: 'Agregar uno',
          onTap: alAgregar,
          excludeSemantics: true,
          child: BotonFila(etiqueta: '+', onPressed: alAgregar),
        ),
      ],
    );
  }
}
