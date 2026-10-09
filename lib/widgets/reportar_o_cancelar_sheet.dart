import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../screens/incidencias_screen.dart';
import 'cancellation_flow.dart';

/// «Reportar incidencias» del Inicio (Carlos, 2026-10-07): antes de abrir el formulario se
/// pregunta qué quiere hacer el técnico, porque reportar una incidencia NO reagenda nada.
///   - Reportar una incidencia → ticket en Helpdesk «Incidencias de campo» (operaciones lo recibe).
///   - Cancelar una instalación en sitio → la hoja real de cancelación: la intervención vuelve a
///     «por planificar» y operaciones recibe el ticket «Reagendar» con el motivo.
Future<void> mostrarReportarOCancelar(BuildContext context) async {
  final eleccion = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('¿Qué necesitas?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.report_problem_outlined, color: cs.primary),
                title: const Text('Reportar una incidencia'),
                subtitle: const Text('Equipo dañado, riesgo en sitio, falta de material… Operaciones lo recibe como ticket. No cambia tu agenda.'),
                onTap: () => Navigator.pop(ctx, 'reportar'),
              ),
              ListTile(
                leading: Icon(Icons.event_busy_outlined, color: cs.error),
                title: const Text('Cancelar una instalación en sitio'),
                subtitle: const Text('Mal clima, el cliente no puede, una emergencia. La instalación sale de tu agenda y operaciones la vuelve a agendar.'),
                onTap: () => Navigator.pop(ctx, 'cancelar'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || eleccion == null) return;
  if (eleccion == 'reportar') {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidenciasScreen()));
    return;
  }
  await _elegirInstalacionACancelar(context);
}

Future<void> _elegirInstalacionACancelar(BuildContext context) async {
  final r = await sl.get<OrdenesRepository>().getOrdenes(tipo: 'instalacion');
  if (!context.mounted) return;
  var abiertas = <Orden>[];
  r.fold((list) => abiertas = list.where((o) => o.estado == 'en_curso' || o.estado == 'por_hacer').toList(), (_) {});
  // La que está en curso va primero: es casi siempre la que se cancela.
  abiertas.sort((a, b) => (a.estado == 'en_curso' ? 0 : 1).compareTo(b.estado == 'en_curso' ? 0 : 1));
  if (abiertas.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes instalaciones pendientes que cancelar.')));
    return;
  }
  if (abiertas.length == 1) {
    showCancellationFlow(context, abiertas.first.toTicketMap());
    return;
  }
  final elegida = await showModalBottomSheet<Orden>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          const Text('¿Cuál instalación se cancela?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final o in abiertas)
            ListTile(
              leading: Icon(o.estado == 'en_curso' ? Icons.play_circle_outline : Icons.schedule, color: Theme.of(ctx).colorScheme.primary),
              title: Text(o.cliente),
              subtitle: Text('${o.direccion}${o.estado == 'en_curso' ? ' · En curso' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, o),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || elegida == null) return;
  showCancellationFlow(context, elegida.toTicketMap());
}
