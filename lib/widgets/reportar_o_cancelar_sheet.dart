import 'package:flutter/material.dart';

import '../core/di/injection_container.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../screens/incidencias_screen.dart';
import 'ayuda.dart';
import 'cancellation_flow.dart';

/// «Reportar incidencias» del Inicio (Carlos, 2026-10-07): antes de abrir el formulario se
/// pregunta qué quiere hacer el técnico, porque reportar una incidencia NO reagenda nada.
///   - Reportar una incidencia → ticket en Helpdesk «Incidencias de campo» (operaciones lo recibe).
///   - Cancelar una instalación en sitio → la hoja real de cancelación: la intervención vuelve a
///     «por planificar» y operaciones recibe el ticket «Reagendar» con el motivo.
Future<void> mostrarReportarOCancelar(BuildContext context) async {
  // v2 (2026-10-23): fondo, forma y asa vienen del tema; las dos opciones van en un grupo de filas.
  final eleccion = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Semantics(header: true, child: Text('¿Qué necesitas?', style: theme.textTheme.headlineSmall)),
              ),
              GrupoFilas(
                children: [
                  FilaFlujo(
                    leading: Icon(Icons.report_problem_rounded, color: cs.primary),
                    titulo: 'Reportar una incidencia',
                    subtitulo: 'Equipo dañado, riesgo en sitio, falta de material… Operaciones lo recibe. No cambia tu agenda.',
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.pop(ctx, 'reportar'),
                  ),
                  FilaFlujo(
                    leading: Icon(Icons.event_busy_rounded, color: cs.error),
                    titulo: 'Cancelar una instalación en sitio',
                    subtitulo: 'Mal clima, el cliente no puede, una emergencia. La instalación sale de tu agenda y operaciones la vuelve a agendar.',
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    onTap: () => Navigator.pop(ctx, 'cancelar'),
                  ),
                ],
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
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Semantics(header: true, child: Text('¿Cuál instalación se cancela?', style: theme.textTheme.headlineSmall)),
              ),
              GrupoFilas(
                children: [
                  for (final o in abiertas)
                    FilaFlujo(
                      leading: Icon(o.estado == 'en_curso' ? Icons.play_circle_outline_rounded : Icons.schedule_rounded, color: cs.onSurfaceVariant),
                      titulo: o.cliente,
                      subtitulo: '${o.direccion}${o.estado == 'en_curso' ? ' · En curso' : ''}',
                      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                      onTap: () => Navigator.pop(ctx, o),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || elegida == null) return;
  showCancellationFlow(context, elegida.toTicketMap());
}
