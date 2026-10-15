import 'package:flutter/material.dart';

/// Ayuda contextual del flujo de instalación (2026-10-15, Carlos: «comunicar mejor los pasos que
/// pueden ser confusos»). En el teléfono un tooltip de pulsación larga casi nadie lo descubre: el
/// ícono ⓘ se TOCA y abre una hoja corta con el «cómo funciona» en viñetas.
class InfoAyuda extends StatelessWidget {
  const InfoAyuda({super.key, required this.titulo, required this.puntos, this.color, this.tamano = 20});

  final String titulo;

  /// Frases cortas, una idea cada una.
  final List<String> puntos;
  final Color? color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Más información: $titulo',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(Icons.info_outline_rounded, size: tamano, color: color ?? cs.onSurfaceVariant),
      onPressed: () => mostrarAyuda(context, titulo: titulo, puntos: puntos),
    );
  }
}

/// Hoja de ayuda: título y viñetas. Se cierra con «Entendido» o deslizando.
Future<void> mostrarAyuda(BuildContext context, {required String titulo, required List<String> puntos}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      // Desplazable: con letra grande (accesibilidad) la hoja puede pasar del alto de la pantalla.
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 14),
              for (final p in puntos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        ),
      );
    },
  );
}

/// «Paso 4 de 7»: dice en qué parte de la instalación va el instalador (va bajo el título).
class PasoDeInstalacion extends StatelessWidget {
  const PasoDeInstalacion({super.key, required this.paso, this.total = 7, this.opcional = false});

  final int paso;
  final int total;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Text(
          'Paso $paso de $total${opcional ? ' · opcional' : ''}',
          style: theme.textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Encabezado de sección en mayúsculas pequeñas, con ⓘ opcional a la derecha.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.ayuda});

  final String texto;
  final InfoAyuda? ayuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: ayuda == null ? 6 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700),
            ),
          ),
          ?ayuda,
        ],
      ),
    );
  }
}

/// Aviso en línea (éxito, error o información) que se queda en su lugar dentro de la pantalla, en
/// vez de un cartel flotante que tapa el encabezado.
class AvisoEnLinea extends StatelessWidget {
  const AvisoEnLinea({super.key, required this.icono, required this.color, required this.titulo, this.texto, this.accion});

  final IconData icono;
  final Color color;
  final String titulo;
  final String? texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
                Text(titulo, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                if (texto != null) ...[
                  const SizedBox(height: 3),
                  Text(texto!, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                ],
                if (accion != null) ...[const SizedBox(height: 8), accion!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
