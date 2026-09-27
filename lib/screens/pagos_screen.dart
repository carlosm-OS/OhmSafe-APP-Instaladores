import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../core/utils/fechas_odoo.dart';
import '../features/dinero/data/dinero_repository.dart';
import '../features/dinero/domain/dinero.dart';
import '../widgets/notification_bell.dart';

/// Mis pagos: lo que OhmSafe le paga al instalador por cada intervención
/// completada. Cada renglón es una factura de proveedor en Odoo; nace en
/// borrador al cerrar («En revisión»), operaciones la valida («Por pagar») y
/// contabilidad la paga («Pagado»).
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  ResumenPagos? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await sl.get<DineroRepository>().pagos();
    if (!mounted) return;
    r.fold(
      (res) => setState(() {
        _resumen = res;
        _cargando = false;
        _error = null;
      }),
      (f) => setState(() {
        _cargando = false;
        _error = f.message;
      }),
    );
  }

  (Color, IconData) _estilo(String estado, ColorScheme cs) => switch (estado) {
        'pagado' => (cs.primary, Icons.check_circle_rounded),
        'por_pagar' => (cs.tertiary, Icons.schedule_rounded),
        'cancelado' => (cs.error, Icons.cancel_outlined),
        _ => (cs.onSurfaceVariant, Icons.hourglass_top_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _resumen;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos'), actions: const [NotificationBell(), SizedBox(width: 8)]),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar tus pagos: $_error', textAlign: TextAlign.center))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Row(children: [
                        Expanded(child: _Total(etiqueta: 'Pagado', valor: dinero(r!.pagado), color: cs.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: _Total(etiqueta: 'Por pagar', valor: dinero(r.porPagar), color: cs.tertiary)),
                        const SizedBox(width: 10),
                        Expanded(child: _Total(etiqueta: 'En revisión', valor: dinero(r.pendienteValidacion), color: cs.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 18),
                      if (r.pagos.isEmpty) ...[
                        const SizedBox(height: 80),
                        Icon(Icons.payments_outlined, size: 56, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Aún no hay pagos', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Cada intervención que cierres aparece aquí con su pago.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      ] else
                        for (final p in r.pagos) ...[
                          Builder(builder: (context) {
                            final (color, icono) = _estilo(p.estado, cs);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                children: [
                                  Icon(icono, color: color),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.concepto, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                          [if (p.referencia != 'Borrador') p.referencia, FechasOdoo.fecha(p.fecha)].join(' · '),
                                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(dinero(p.monto, p.moneda), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text(estadosPago[p.estado] ?? p.estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      const SizedBox(height: 12),
                      Text(
                        'Los pagos «En revisión» se confirman cuando operaciones valida la intervención. Si un importe no coincide, repórtalo como incidencia.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color color;
  const _Total({required this.etiqueta, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color))),
        ],
      ),
    );
  }
}
