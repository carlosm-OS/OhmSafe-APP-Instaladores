import '../widgets/cancellation_flow.dart';
import '../core/utils/como_llegar.dart';
import 'package:flutter/material.dart';
import '../widgets/ayuda.dart';
import '../widgets/ohm_gradient_button.dart';
import '../core/di/injection_container.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/utils/ubicacion.dart';
import 'instalaciones_screen.dart' show InsigniaUrgente;

class RouteDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const RouteDetailsScreen({super.key, required this.ticket});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  bool _isSending = false;

  /// Mensaje humano del repositorio cuando no se pudo marcar la llegada; va junto al botón (v2).
  String? _error;

  /// Marca la llegada al sitio en el backend (paso "En sitio" en Odoo) y,
  /// solo si tiene éxito, regresa 'arrived' para avanzar el flujo. Ante un
  /// fallo muestra el error y NO avanza (la orden sigue en su estado previo).
  Future<void> _marcarLlegada() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    final id = (widget.ticket["id"] ?? widget.ticket["ticket_id"] ?? "").toString();
    // La posición de la llegada es la referencia del cierre (radio de 300 m).
    final ubicacion = ubicacionJson(await ubicacionActual());
    if (!mounted) return;
    final result = await sl.get<OrdenesRepository>().marcarLlegada(id, ubicacion: ubicacion);
    if (!mounted) return;
    result.fold(
      (_) => Navigator.pop(context, 'arrived'),
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
    final isUrgent = widget.ticket["isUrgent"] as bool? ?? false;
    final cliente = (widget.ticket["user"] ?? '').toString();
    final direccion = details["direccion"] ?? '';
    final ciudadCp = [details["ciudad"] ?? '', details["cp"] ?? ''].where((x) => x.trim().isNotEmpty).join(' · ');
    final destino = DestinoServicio.deDetalles(details);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // v2 (2026-10-23): encabezado único.
            EncabezadoFlujo(titulo: "Ruta", subtitulo: (widget.ticket["title"] ?? '').toString(), alVolver: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (isUrgent)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Align(alignment: Alignment.centerLeft, child: InsigniaUrgente()),
                    ),
                  const EtiquetaSeccion("Cliente"),
                  GrupoFilas(
                    pie: "Al llegar, marca tu llegada: tu ubicación de ese momento es la referencia del cierre.",
                    children: [
                      FilaFlujo(
                        leading: Icon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                        titulo: cliente.isEmpty ? 'Cliente' : cliente,
                        subtitulo: details["telefono"],
                      ),
                      FilaFlujo(
                        leading: Icon(Icons.place_outlined, color: cs.onSurfaceVariant),
                        titulo: direccion.isEmpty ? 'Sin dirección' : direccion,
                        subtitulo: ciudadCp,
                        trailing: destino.vacio ? null : BotonFila(etiqueta: 'Cómo llegar', onPressed: () => mostrarComoLlegar(context, destino)),
                      ),
                    ],
                  ),
                  // Lo que pasa, pasa junto al botón (v2): el error con qué hacer y el botón que dice qué hace.
                  if (_error != null) MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: "No pudimos marcar tu llegada", texto: _error),
                  OhmGradientButton(
                    label: "Marcar llegada",
                    icon: Icons.place_rounded,
                    loading: _isSending,
                    loadingLabel: "Tomando tu ubicación…",
                    onPressed: _marcarLlegada,
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
}
