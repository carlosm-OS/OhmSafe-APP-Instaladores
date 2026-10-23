import 'package:flutter/material.dart';

import '../core/theme/app_theme_extension.dart';
import '../core/utils/destino_equipo.dart';
import 'botones_dialogo.dart';
import 'ayuda.dart';

/// Confirma a dónde va el energizador antes de vincular (2026-10-14). No hay nada que elegir:
/// la casa la decide la venta. Devuelve true si el instalador confirma; false si cancela o si
/// la venta no permite decidir (en ese caso sólo se explica qué hacer).
Future<bool> confirmarDestinoEquipo(BuildContext context, DestinoDecidido destino) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Confirmacion(destino: destino),
  );
  return r == true;
}

class _Confirmacion extends StatelessWidget {
  const _Confirmacion({required this.destino});
  final DestinoDecidido destino;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    final venta = destino.venta;
    final bloquea = destino.bloquea;
    // Textos del lienzo de Carlos (2026-10-15, versión A): lo único que decide el instalador es si
    // está en esa dirección; «casa nueva», «suscripción» y la venta pasan a segundo plano.
    final titulo = bloquea ? 'Todavía no se puede vincular' : '¿Estás instalando en esta dirección?';
    final icono = bloquea ? Icons.help_outline_rounded : Icons.home_rounded;
    final acento = bloquea ? cs.error : cs.primary;
    final explicacion = destino.esNueva
        ? 'El energizador quedará vinculado a esta casa del cliente. Si no es donde estás, no lo vincules y avisa a operaciones.'
        : 'El energizador se suma a esta casa del cliente. Si no es donde estás, no lo vincules y avisa a operaciones.';

    return SafeArea(
      // Desplazable: con letra grande o en teléfonos chicos la hoja no cabe y los botones quedaban fuera.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(titulo, style: theme.textTheme.headlineSmall)),
                const InfoAyuda(
                  titulo: '¿Por qué esta casa?',
                  puntos: [
                    'La casa la define la venta; aquí no se elige.',
                    'Cada casa del cliente tiene su propia suscripción.',
                    'Un energizador extra en la misma casa se agrega después, en «Agregar dispositivos».',
                    'Si la dirección no es la correcta, cancela y avisa a operaciones antes de vincular.',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lo que importa primero: a qué casa va. La venta va después, más discreta.
            if (!bloquea && (destino.casaNombre ?? '').isNotEmpty) ...[
              _Bloque(
                icono: icono,
                color: acento,
                titulo: destino.casaNombre!,
                etiqueta: destino.esNueva ? 'Nueva' : 'Ya tiene equipo',
                texto: (destino.direccion ?? '').isEmpty ? null : destino.direccion,
              ),
              const SizedBox(height: 12),
            ],
            // Al bloquear, el motivo del backend explica qué falta; si no, el texto fijo de arriba.
            Text(bloquea ? destino.motivo : explicacion, style: theme.textTheme.bodyMedium?.copyWith(color: bloquea ? cs.error : cs.onSurfaceVariant)),
            if (venta != null) ...[
              const SizedBox(height: 10),
              // La venta, discreta: una línea gris (le sirve a soporte, no compite con la dirección).
              Text(
                [
                  'Venta ${venta.nombre}',
                  venta.esServicioNuevo ? (venta.plan ?? 'Plan nuevo') : 'Equipo adicional',
                  ...venta.equipos.map((e) => '${e.cantidad} ${e.nombre}'),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (destino.aviso != null) ...[
              const SizedBox(height: 10),
              _Bloque(icono: Icons.info_outline_rounded, color: ohm.warning, titulo: 'Nota para operaciones', texto: destino.aviso),
            ],
            const SizedBox(height: 20),
            if (bloquea)
              BotonesDialogo(primario: 'Entendido, avisaré a operaciones', onPrimario: () => Navigator.pop(context, false))
            else
              BotonesDialogo(
                secundario: 'No es esta dirección',
                onSecundario: () => Navigator.pop(context, false),
                primario: 'Sí, vincular aquí',
                onPrimario: () => Navigator.pop(context, true),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.icono, required this.color, required this.titulo, this.etiqueta, this.texto});
  final IconData icono;
  final Color color;
  final String titulo;

  /// Etiqueta junto al nombre («Nueva» / «Ya tiene equipo»).
  final String? etiqueta;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      // v2 (2026-10-23): grupo gris claro sin borde sobre la hoja blanca; el color va sólo en el ícono.
      decoration: BoxDecoration(color: context.ohm.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (etiqueta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          etiqueta!,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                        ),
                      ),
                  ],
                ),
                if (texto != null) ...[
                  const SizedBox(height: 2),
                  Text(texto!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
