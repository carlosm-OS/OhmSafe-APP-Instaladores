import '../widgets/cancellation_flow.dart';
import 'package:flutter/material.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/theme/app_motion.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';

class PerimeterInspectionScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const PerimeterInspectionScreen({super.key, required this.ticket});

  @override
  State<PerimeterInspectionScreen> createState() => _PerimeterInspectionScreenState();
}

class _PerimeterInspectionScreenState extends State<PerimeterInspectionScreen> {
  // Obstacles to display in the 2-column grid
  final List<String> _obstacles = ['Malla ciclónica', 'Vegetación', 'Concertina', 'Árboles', 'Herrería', 'Desniveles', 'Arcos', 'Cableado', 'Altura superior'];

  bool _noObstaclesSelected = false;
  final Set<String> _selectedObstacles = {};

  /// Metraje REAL medido en sitio. Arranca con el agendado (de la llamada) pero
  /// el instalador lo corrige con lo que mide: el agendado se conserva aparte
  /// para poder contrastar lo cotizado contra lo real.
  final TextEditingController _metrosController = TextEditingController();
  bool _metrosInicializado = false;

  /// Solo dígitos del metraje que viene del ticket ("85 m" -> "85").
  String _metrajeAgendado() {
    final raw = (widget.ticket['details']?['metraje'] ?? '').toString();
    final m = RegExp(r'[\d.]+').firstMatch(raw);
    return m?.group(0) ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_metrosInicializado) {
      _metrosController.text = _metrajeAgendado();
      _metrosInicializado = true;
    }
  }

  @override
  void dispose() {
    _metrosController.dispose();
    super.dispose();
  }

  void _toggleObstacle(String obstacle) {
    setState(() {
      if (obstacle == 'Perímetro sin obstáculos') {
        _noObstaclesSelected = !_noObstaclesSelected;
        if (_noObstaclesSelected) {
          _selectedObstacles.clear();
        }
      } else {
        _noObstaclesSelected = false;
        if (_selectedObstacles.contains(obstacle)) {
          _selectedObstacles.remove(obstacle);
        } else {
          _selectedObstacles.add(obstacle);
        }
      }
    });
  }

  bool get _hasSelection => _noObstaclesSelected || _selectedObstacles.isNotEmpty;

  bool _isSending = false;

  /// Mensaje humano del repositorio si no se pudo guardar; va junto al botón (v2).
  String? _error;

  /// Guarda la inspección de perímetro en el backend (obstáculos + bandera
  /// "sin obstáculos") y, solo si tiene éxito, regresa 'perimeter_completed'.
  Future<void> _guardarInspeccion() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    final id = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    final result = await sl.get<OrdenesRepository>().guardarInspeccion(
      id,
      sinObstaculos: _noObstaclesSelected,
      obstaculos: _selectedObstacles.toList(),
      metrosReales: double.tryParse(_metrosController.text.trim()),
    );
    if (!mounted) return;
    result.fold(
      (_) {
        // Los metros reales medidos mandan desde aquí: el paso de instalación y la ficha
        // los muestran sin esperar a recargar la orden del backend.
        final metros = double.tryParse(_metrosController.text.trim());
        if (metros != null && metros > 0) {
          final details = widget.ticket['details'];
          if (details is Map) details['metraje'] = '${metros % 1 == 0 ? metros.toInt() : metros} m';
        }
        Navigator.pop(context, 'perimeter_completed');
      },
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
            EncabezadoFlujo(titulo: "Inspección del perímetro", subtitulo: widget.ticket["user"] ?? "Cliente", alVolver: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  const EtiquetaSeccion("Metraje"),
                  GrupoFilas(
                    pie: "Corrige el real con lo que mides en sitio; el agendado se guarda aparte para comparar.",
                    children: [
                      FilaFlujo(
                        titulo: "Metraje agendado",
                        trailing: Text(details["metraje"] ?? "0 m", style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      // El metraje REAL lo mide el instalador en sitio; el agendado (arriba) queda intacto.
                      FilaFlujo(
                        titulo: "Metraje real",
                        trailing: SizedBox(
                          width: 104,
                          child: TextField(
                            controller: _metrosController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: "m",
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const EtiquetaSeccion("Obstáculos en el terreno"),
                  GrupoFilas(children: [_buildObstacleTile("Perímetro sin obstáculos", _noObstaclesSelected)]),
                  GrupoFilas(
                    pie: "Marca todos los que haya.",
                    children: [for (final name in _obstacles) _buildObstacleTile(name, _selectedObstacles.contains(name))],
                  ),

                  // Lo que pasa, pasa junto al botón (v2).
                  if (_error != null)
                    MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: "No pudimos guardar la inspección", texto: _error),
                  OhmGradientButton(
                    label: "Guardar inspección",
                    loading: _isSending,
                    loadingLabel: "Guardando la inspección…",
                    onPressed: _hasSelection ? _guardarInspeccion : null,
                  ),
                  if (!_hasSelection) ...[
                    const SizedBox(height: 12),
                    const FaltaParaSeguir(["marcar los obstáculos o «Perímetro sin obstáculos»"]),
                  ],
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

  Widget _buildObstacleTile(String name, bool isSelected) {
    // Deshabilitado mientras «Perímetro sin obstáculos» está marcado.
    final bool isDisabled = _noObstaclesSelected && name != 'Perímetro sin obstáculos';

    return Semantics(
      checked: isSelected,
      enabled: !isDisabled,
      child: AnimatedOpacity(
        duration: AppMotion.of(context, AppDurations.base),
        opacity: isDisabled ? 0.4 : 1.0,
        child: FilaFlujo(
          titulo: name,
          trailing: CirculoCheck(marcado: isSelected),
          onTap: isDisabled ? null : () => _toggleObstacle(name),
        ),
      ),
    );
  }
}
