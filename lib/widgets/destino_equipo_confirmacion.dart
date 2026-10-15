import 'package:flutter/material.dart';

import '../core/theme/app_theme_extension.dart';
import '../core/utils/destino_equipo.dart';
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
    final titulo = bloquea
        ? 'Todavía no se puede vincular'
        : destino.esNueva
            ? 'El equipo va a una casa nueva'
            : 'El equipo se suma a esta casa';
    final icono = bloquea ? Icons.help_outline : (destino.esNueva ? Icons.add_home_outlined : Icons.home_outlined);
    final acento = bloquea ? cs.error : cs.primary;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(titulo, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
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
                texto: (destino.direccion ?? '').isEmpty ? null : destino.direccion,
                resaltado: true,
              ),
              const SizedBox(height: 10),
            ],
            Text(destino.motivo, style: theme.textTheme.bodyMedium?.copyWith(color: bloquea ? cs.error : cs.onSurfaceVariant, height: 1.4)),
            if (venta != null) ...[
              const SizedBox(height: 12),
              _Bloque(
                icono: Icons.receipt_long_outlined,
                color: cs.onSurfaceVariant,
                titulo: 'Venta ${venta.nombre}',
                texto: venta.resumen,
              ),
            ],
            if (destino.aviso != null) ...[
              const SizedBox(height: 10),
              _Bloque(icono: Icons.info_outline, color: ohm.warning, titulo: 'Nota para operaciones', texto: destino.aviso),
            ],
            const SizedBox(height: 20),
            if (bloquea)
              FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Entendido'))
            else
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, vincular'))),
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
      // Tarjeta blanca con borde tenue, como el resto del flujo; la casa elegida lleva borde naranja.
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resaltado ? color : theme.dividerColor.withValues(alpha: 0.3), width: resaltado ? 1.5 : 1),
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
                Text(titulo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
