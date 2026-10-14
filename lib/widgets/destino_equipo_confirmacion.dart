import 'package:flutter/material.dart';

import '../core/theme/app_theme_extension.dart';
import '../core/utils/destino_equipo.dart';

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
    final titulo = bloquea
        ? 'No se puede vincular todavía'
        : destino.esNueva
            ? 'Este equipo va a una casa nueva'
            : 'Este equipo se suma a una casa';
    final icono = bloquea ? Icons.help_outline : (destino.esNueva ? Icons.add_home_outlined : Icons.home_outlined);
    final acento = bloquea ? cs.error : cs.primary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (venta != null) ...[
              _Bloque(
                icono: Icons.receipt_long_outlined,
                color: cs.onSurfaceVariant,
                titulo: 'Venta ${venta.nombre}',
                texto: venta.resumen,
              ),
              const SizedBox(height: 10),
            ],
            if (!bloquea && (destino.casaNombre ?? '').isNotEmpty)
              _Bloque(
                icono: icono,
                color: acento,
                titulo: destino.casaNombre!,
                texto: (destino.direccion ?? '').isEmpty ? null : destino.direccion,
                resaltado: true,
              ),
            const SizedBox(height: 10),
            Text(destino.motivo, style: theme.textTheme.bodyMedium?.copyWith(color: bloquea ? cs.error : cs.onSurfaceVariant)),
            if (!bloquea && destino.esExistente) ...[
              const SizedBox(height: 6),
              Text('Un segundo energizador en la misma casa es un complemento de su suscripción, no un paquete nuevo.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            if (destino.aviso != null) ...[
              const SizedBox(height: 10),
              _Bloque(icono: Icons.info_outline, color: ohm.warning, titulo: 'Aviso para operaciones', texto: destino.aviso),
            ],
            const SizedBox(height: 20),
            if (bloquea)
              FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Entendido'))
            else
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vincular'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.icono, required this.color, required this.titulo, this.texto, this.resaltado = false});
  final IconData icono;
  final Color color;
  final String titulo;
  final String? texto;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: resaltado ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: resaltado ? 0.6 : 0.25), width: resaltado ? 1.4 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: resaltado ? color : null)),
                if (texto != null) ...[
                  const SizedBox(height: 2),
                  Text(texto!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
