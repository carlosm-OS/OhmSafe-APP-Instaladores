import 'package:flutter/material.dart';

import 'notification_bell.dart';

// =============================================================================
// Piezas del flujo de instalación (pasos 4 a 7), copiadas del lenguaje que ya
// usan los pasos 1 a 3 (inspección del perímetro, instalación de cerca). No es
// un estilo nuevo: mismo encabezado (logo + campana, flecha + título centrado),
// tarjetas blancas con borde tenue sin sombra, etiquetas de sección en
// mayúsculas grises, filas de lista con su control a la derecha y naranja sólo
// en acciones. Carlos, 2026-10-15: «no está en la línea que venía trabajando».
// =============================================================================

/// Logo + campana y, debajo, flecha de regreso + título centrado (como «Inspección del perímetro»).
class EncabezadoFlujo extends StatelessWidget {
  const EncabezadoFlujo({super.key, required this.titulo, this.alVolver});

  final String titulo;

  /// Por defecto, `Navigator.pop`.
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                isDark ? 'assets/assets/logo_white.png' : 'assets/assets/logo_light.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('OHM', style: TextStyle(fontWeight: FontWeight.w900, color: theme.textTheme.bodyLarge?.color)),
                    Text('SAFE', style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
                  ],
                ),
              ),
              const Align(alignment: Alignment.centerRight, child: NotificationBell()),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Text(
                    titulo,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textTheme.titleLarge?.color),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Regresar',
                    onPressed: alVolver ?? () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(6), shape: const CircleBorder()),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.iconTheme.color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta blanca con borde tenue y sin sombra (la del cliente y metraje del paso 2).
class TarjetaFlujo extends StatelessWidget {
  const TarjetaFlujo({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}

/// «OBSTÁCULOS EN EL TERRENO»: etiqueta de sección. Con [ayuda], un ⓘ discreto del mismo gris.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key, this.ayuda, this.tituloAyuda});

  final String texto;
  final List<String>? ayuda;
  final String? tituloAyuda;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4);
    final etiqueta = Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5));
    if (ayuda == null) return Padding(padding: const EdgeInsets.only(bottom: 12), child: etiqueta);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Flexible(child: etiqueta),
          InfoAyuda(titulo: tituloAyuda ?? texto, puntos: ayuda!, color: color),
        ],
      ),
    );
  }
}

/// ⓘ que se toca y abre la ayuda. Ícono chico y gris: no compite con el contenido.
class InfoAyuda extends StatelessWidget {
  const InfoAyuda({super.key, required this.titulo, required this.puntos, this.color});

  final String titulo;
  final List<String> puntos;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda: $titulo',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(Icons.info_outline_rounded, size: 18, color: color ?? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
      onPressed: () => mostrarAyuda(context, titulo: titulo, puntos: puntos),
    );
  }
}

/// Hoja de ayuda con la forma de «¿Qué necesitas?» (reportar o cancelar): título y renglones cortos.
Future<void> mostrarAyuda(BuildContext context, {required String titulo, required List<String> puntos}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          // Desplazable: con letra grande (accesibilidad) la hoja puede pasar del alto de la pantalla.
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final p in puntos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(p, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85))),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Fila de lista como «Postes esquina» (paso 3): nombre a la izquierda, control a la derecha.
/// [marcada] usa el estado elegido de los obstáculos del paso 2 (borde y texto naranja).
class FilaFlujo extends StatelessWidget {
  const FilaFlujo({super.key, required this.titulo, this.subtitulo, this.trailing, this.marcada = false, this.colorSubtitulo});

  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  final bool marcada;
  final Color? colorSubtitulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: marcada ? (isDark ? cs.primary.withValues(alpha: 0.2) : cs.primaryContainer) : (isDark ? cs.surface.withValues(alpha: 0.5) : cs.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: marcada ? cs.primary : theme.dividerColor.withValues(alpha: 0.3), width: marcada ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: marcada ? FontWeight.w700 : FontWeight.w500,
                    color: marcada ? cs.primary : theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitulo!, style: TextStyle(fontSize: 13, height: 1.35, color: colorSubtitulo ?? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6))),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Círculo de selección de los obstáculos (paso 2): vacío o naranja con palomita.
class CirculoCheck extends StatelessWidget {
  const CirculoCheck({super.key, required this.marcado});

  final bool marcado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: marcado ? cs.primary : (isDark ? Colors.white30 : Colors.black12), width: 2),
        color: marcado ? cs.primary : Colors.transparent,
      ),
      child: marcado ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
    );
  }
}

/// Botón dentro de una fila, con la forma del contador «− 5 +» del paso 3 (38 de alto, radio 8).
/// [lleno] pinta el fondo naranja como el «+».
class BotonFila extends StatelessWidget {
  const BotonFila({super.key, required this.etiqueta, required this.onPressed, this.icono, this.lleno = false});

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool lleno;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activo = onPressed != null;
    final fg = lleno ? Colors.white : (activo ? cs.primary : theme.disabledColor);
    return Semantics(
      button: true,
      enabled: activo,
      label: etiqueta,
      child: Opacity(
        opacity: activo ? 1 : 0.45,
        child: Material(
          color: lleno ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: lleno ? null : Border.all(color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono != null) ...[Icon(icono, size: 18, color: fg), const SizedBox(width: 6)],
                  Text(etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario de ancho completo como «Cancelar instalación» (borde gris, texto oscuro).
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.etiqueta, required this.onPressed, this.icono});

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = OutlinedButton.styleFrom(
      foregroundColor: theme.textTheme.bodyLarge?.color,
      side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    const texto = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    return SizedBox(
      width: double.infinity,
      child: icono == null
          ? OutlinedButton(onPressed: onPressed, style: style, child: Text(etiqueta, style: texto))
          : OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icono, size: 20), label: Text(etiqueta, style: texto)),
    );
  }
}

/// Aviso dentro de la pantalla: tarjeta blanca con un ícono de color, sin fondos teñidos.
class MensajeFlujo extends StatelessWidget {
  const MensajeFlujo({super.key, required this.icono, required this.color, required this.titulo, this.texto, this.accion});

  final IconData icono;
  final Color color;
  final String titulo;
  final String? texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaFlujo(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                  if (texto != null) ...[
                    const SizedBox(height: 2),
                    Text(texto!, style: TextStyle(fontSize: 13, height: 1.35, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                  ],
                  if (accion != null) ...[const SizedBox(height: 10), accion!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglón «Etiqueta:  valor» centrado, como «Cliente:» y «Metraje agendado:» del paso 2.
class DatoFlujo extends StatelessWidget {
  const DatoFlujo({super.key, required this.etiqueta, required this.valor, this.color});

  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$etiqueta:  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
          Flexible(
            child: Text(
              valor,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color ?? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
