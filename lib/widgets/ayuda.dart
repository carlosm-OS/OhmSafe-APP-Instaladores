import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_motion.dart';
import 'movimiento.dart';
import 'ohm_gradient_button.dart';

import 'notification_bell.dart';

// =============================================================================
// Piezas del flujo de instalación (pasos 4 a 7), copiadas del lenguaje que ya
// usan los pasos 1 a 3 (inspección del perímetro, instalación de cerca). No es
// un estilo nuevo: mismo encabezado (logo + campana, flecha + título centrado),
// tarjetas blancas con borde tenue sin sombra, etiquetas de sección en
// mayúsculas grises, filas de lista con su control a la derecha y naranja sólo
// en acciones. Carlos, 2026-10-15: «no está en la línea que venía trabajando».
// =============================================================================

/// Encabezado v2 (lienzo «Sistema v2», 2026-10-23): arriba la flecha naranja para regresar y la
/// campana; abajo el título grande a la izquierda, como en iPhone. [subtitulo] dice de qué casa u
/// orden se trata. Sin [alVolver] regresa con `Navigator.maybePop` (respeta `PopScope`).
class EncabezadoFlujo extends StatelessWidget {
  const EncabezadoFlujo({super.key, required this.titulo, this.alVolver, this.subtitulo, this.volver = true, this.campana = true});

  final String titulo;
  final String? subtitulo;

  /// Por defecto, `Navigator.maybePop`.
  final VoidCallback? alVolver;

  /// Raíz de pestaña (Mi cuenta, Historial): sin flecha.
  final bool volver;
  final bool campana;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 4),
              if (volver)
                IconButton(
                  tooltip: 'Regresar',
                  onPressed: alVolver ?? () => Navigator.maybePop(context),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.chevron_left_rounded, size: 34, color: cs.primary),
                ),
              const Spacer(),
              if (campana) const NotificationBell(),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.displayMedium),
              ),
              if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitulo!, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Grupo blanco sobre el gris de fondo, sin borde ni sombra (v2).
class TarjetaFlujo extends StatelessWidget {
  const TarjetaFlujo({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}

/// Filas de lista juntas en un solo grupo blanco, separadas por una línea fina (lista agrupada v2).
/// Las [FilaFlujo] de adentro pierden su fondo y margen propios.
class GrupoFilas extends StatelessWidget {
  const GrupoFilas({super.key, required this.children, this.pie});

  final List<Widget> children;

  /// Nota corta debajo del grupo (13, gris), como en Ajustes de iPhone.
  final String? pie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filas = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) filas.add(Divider(height: 0.5, thickness: 0.5, indent: 16, color: cs.outlineVariant));
      filas.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: cs.surface,
              child: _DentroDeGrupo(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas)),
            ),
          ),
          if (pie != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(pie!, style: theme.textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class _DentroDeGrupo extends InheritedWidget {
  const _DentroDeGrupo({required super.child});

  static bool en(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_DentroDeGrupo>() != null;

  @override
  bool updateShouldNotify(_DentroDeGrupo oldWidget) => false;
}

/// Estado como un punto de color y una palabra (v2): «En línea», «Sin probar», «No respondió».
class EstadoPunto extends StatelessWidget {
  const EstadoPunto(this.texto, {super.key, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(texto, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      ],
    );
  }
}

/// Nombre de un grupo («Sensores cableados»): 13, gris de apoyo, en tipo oración (v2: adiós a las
/// MAYÚSCULAS grises, que además daban 2.4:1). Con [ayuda], un ⓘ al lado.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key, this.ayuda, this.tituloAyuda});

  final String texto;
  final List<String>? ayuda;
  final String? tituloAyuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final etiqueta = Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color));
    if (ayuda == null) return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: etiqueta);
    return Padding(
      padding: const EdgeInsets.only(left: 16),
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
      constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
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
              Text(titulo, style: theme.textTheme.headlineSmall),
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

/// Fila de lista v2: título (17) y apoyo (15, gris) a la izquierda, control a la derecha. Sola es un
/// grupo blanco; dentro de [GrupoFilas] comparte el grupo y se separa con una línea fina.
/// [marcada] = elegida o lista: fondo naranja claro y texto naranja oscuro (7:1).
class FilaFlujo extends StatelessWidget {
  const FilaFlujo({super.key, required this.titulo, this.subtitulo, this.trailing, this.marcada = false, this.colorSubtitulo, this.leading, this.onTap, this.detalle});

  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  final Widget? leading;
  final bool marcada;
  final Color? colorSubtitulo;
  final VoidCallback? onTap;

  /// Debajo del título en lugar de [subtitulo]: p. ej. un [EstadoPunto].
  final Widget? detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enGrupo = _DentroDeGrupo.en(context);
    final contenido = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: marcada ? FontWeight.w600 : FontWeight.w500,
                  color: marcada ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
              if (detalle != null) ...[
                const SizedBox(height: 2),
                detalle!,
              ] else if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitulo!, style: theme.textTheme.bodyMedium?.copyWith(color: colorSubtitulo ?? cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          CambioSuave(
            child: KeyedSubtree(key: ValueKey(trailing.runtimeType), child: trailing!),
          ),
        ],
      ],
    );
    // Cambios de estado en 200 ms (marcada, color) y el trailing cambia fundiendo + deslizando (GO).
    final caja = AnimatedContainer(
      duration: AppMotion.of(context, AppDurations.base),
      curve: AppCurves.standard,
      margin: enGrupo ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: marcada ? cs.primaryContainer : (enGrupo ? Colors.transparent : cs.surface),
        borderRadius: enGrupo ? null : BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: contenido,
    );
    if (onTap == null) return caja;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: enGrupo ? null : BorderRadius.circular(14), child: caja));
  }
}

/// Círculo de selección de los obstáculos (paso 2): vacío o naranja con palomita.
class CirculoCheck extends StatelessWidget {
  const CirculoCheck({super.key, required this.marcado});

  final bool marcado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: marcado ? cs.primary : cs.outline, width: 2),
        color: marcado ? cs.primary : Colors.transparent,
      ),
      child: marcado ? Icon(Icons.check_rounded, size: 13, color: cs.onPrimary) : null,
    );
  }
}

/// Acción dentro de una fila (v2, opción C): píldora gris con texto en tinta, 32 de alto dentro de
/// un área de toque de 44. [lleno] = la acción principal de la fila, en naranja.
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
    final activo = onPressed != null;
    final fg = lleno ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      enabled: activo,
      label: etiqueta,
      excludeSemantics: true,
      child: Presionable(
        activo: activo,
        child: AnimatedOpacity(
          duration: AppMotion.of(context, AppDurations.base),
          opacity: activo ? 1 : 0.4,
          child: GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
              alignment: Alignment.center,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: lleno ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icono != null) ...[Icon(icono, size: 16, color: fg), const SizedBox(width: 6)],
                    Text(etiqueta, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario v2: gris relleno con tinta, mismo alto y radio que el principal.
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.etiqueta, required this.onPressed, this.icono, this.peligro = false});

  final String etiqueta;
  final VoidCallback? onPressed;
  final IconData? icono;

  /// Salir pierde trabajo («Cancelar instalación»): texto en rojo.
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: cs.surfaceContainerHighest,
      foregroundColor: peligro ? cs.error : cs.onSurface,
      disabledBackgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: theme.textTheme.labelLarge,
    );
    return SizedBox(
      width: double.infinity,
      child: icono == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(etiqueta))
          : FilledButton.icon(onPressed: onPressed, style: style, icon: Icon(icono, size: 20), label: Text(etiqueta)),
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
    // Errores: tarjeta roja rellena con texto blanco (lienzo de Carlos, 2026-10-15); los demás avisos
    // siguen en tarjeta blanca con el ícono de color.
    if (color == theme.colorScheme.error) return _relleno(context);
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
                  Text(
                    titulo,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (texto != null) ...[
                    const SizedBox(height: 2),
                    Text(texto!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _relleno(BuildContext context) {
    const blanco = Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: AvisoRojo.fondo, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: blanco),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: blanco),
                  ),
                  if (texto != null) ...[const SizedBox(height: 2), Text(texto!, style: const TextStyle(fontSize: 15, height: 1.4, color: blanco))],
                  if (accion != null) ...[
                    const SizedBox(height: 10),
                    // La acción (p. ej. «Intentar de nuevo») va en blanco sobre el rojo.
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(primary: blanco),
                        disabledColor: blanco.withValues(alpha: 0.6),
                      ),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: blanco),
                        child: accion!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rojo de los avisos de error rellenos (lienzo de Carlos, 2026-10-15). El texto va en blanco y bold.
/// 2026-10-17: del #FF3A4B del lienzo (3.5:1 con blanco, se leía mal al sol) al mismo tono más oscuro,
/// #DC2638 (4.8:1, pasa el mínimo de accesibilidad 4.5:1 para texto normal).
abstract final class AvisoRojo {
  static const Color fondo = Color(0xFFDC2638);
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
          Text(
            '$etiqueta:  ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
          ),
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

/// «Esperando señal del equipo…» con barra de progreso (Carlos, 2026-10-15). Un instalador en prueba
/// vio «Sin señal» recién encendido el equipo y se puso a revisar cables, cuando sólo faltaba esperar
/// a que reportara. Se muestra mientras la pantalla vuelve a consultar sola.
class EsperandoSenal extends StatelessWidget {
  const EsperandoSenal({
    super.key,
    this.titulo = 'Esperando señal del equipo…',
    this.texto = 'Si lo acabas de encender, puede tardar 1 o 2 minutos en aparecer en línea. La pantalla se actualiza sola.',
  });

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaFlujo(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(minHeight: 6, color: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de un requisito en una [ZonaEstado].
enum EstadoZona { enOrden, falta, opcional }

/// Zona de estado de un requisito (propuesta A del lienzo, Carlos 2026-10-23): verde «EN ORDEN»,
/// rojo «FALTA» o gris «OPCIONAL». Nunca sólo color: ícono ✓/✕ + etiqueta + una frase que dice qué
/// hacer, y la acción dentro de la zona. Rojo sólo para lo que impide seguir; lo opcional va en gris.
class ZonaEstado extends StatelessWidget {
  const ZonaEstado({
    super.key,
    required this.estado,
    required this.titulo,
    required this.detalle,
    this.accionEtiqueta,
    this.alAccion,
    this.accionPrincipal = false,
    this.accionIcono,
    this.ocupado = false,
  });

  final EstadoZona estado;
  final String titulo;
  final String detalle;

  /// Sin etiqueta no hay acción. [accionPrincipal] la pinta como botón naranja de ancho completo
  /// (para resolver un «FALTA»); si no, es un enlace del color de la zona («Cambiar red»).
  final String? accionEtiqueta;
  final VoidCallback? alAccion;
  final bool accionPrincipal;
  final IconData? accionIcono;

  /// La acción está en curso: el botón lo dice y no se puede volver a tocar.
  final bool ocupado;

  static const _verde = Color(0xFF166534);
  static const _gris = Color(0xFF64748B);

  ({Color fondo, Color borde, Color texto, Color marca, String etiqueta}) _colores(BuildContext context) {
    final theme = Theme.of(context);
    final oscuro = theme.brightness == Brightness.dark;
    return switch (estado) {
      EstadoZona.enOrden => (
        fondo: oscuro ? _verde.withValues(alpha: 0.28) : const Color(0xFFDCFCE7),
        borde: oscuro ? const Color(0xFF22C55E) : _verde,
        texto: oscuro ? const Color(0xFFBBF7D0) : const Color(0xFF14532D),
        marca: _verde,
        etiqueta: 'EN ORDEN',
      ),
      EstadoZona.falta => (
        fondo: oscuro ? AvisoRojo.fondo.withValues(alpha: 0.24) : const Color(0xFFFEE2E2),
        borde: oscuro ? const Color(0xFFF87171) : AvisoRojo.fondo,
        texto: oscuro ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
        marca: AvisoRojo.fondo,
        etiqueta: 'FALTA',
      ),
      EstadoZona.opcional => (
        fondo: oscuro ? theme.colorScheme.surface.withValues(alpha: 0.5) : theme.colorScheme.surface,
        borde: theme.dividerColor.withValues(alpha: 0.45),
        texto: theme.textTheme.bodyLarge?.color ?? (oscuro ? Colors.white : Colors.black87),
        marca: _gris,
        etiqueta: 'OPCIONAL',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _colores(context);
    final ok = estado == EstadoZona.enOrden;
    final marca = estado == EstadoZona.opcional
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.marca, width: 2),
            ),
            child: Icon(Icons.remove_rounded, size: 18, color: c.marca),
          )
        : Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.marca),
            child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 20, color: Colors.white),
          );
    final etiqueta = accionEtiqueta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppDurations.base),
        curve: AppCurves.standard,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: c.fondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borde, width: estado == EstadoZona.opcional ? 1 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: '${c.etiqueta}: $titulo. $detalle',
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CambioSuave(
                      alineacion: Alignment.center,
                      child: KeyedSubtree(key: ValueKey(estado), child: marca),
                    ),
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
                              Text(
                                titulo,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.texto),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.marca, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  c.etiqueta,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(detalle, style: TextStyle(fontSize: 15, height: 1.4, color: c.texto)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (etiqueta != null) ...[
              const SizedBox(height: 10),
              if (accionPrincipal)
                OhmGradientButton(label: etiqueta, icon: accionIcono, height: AppTouch.min, loading: ocupado, onPressed: alAccion)
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: ocupado ? null : alAccion,
                    style: TextButton.styleFrom(
                      foregroundColor: estado == EstadoZona.opcional ? Theme.of(context).colorScheme.primary : c.borde,
                      minimumSize: const Size(44, AppTouch.min),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: ocupado
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(accionIcono ?? Icons.wifi_rounded, size: 18),
                    label: Text(etiqueta),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renglón rojo bajo un botón apagado: qué falta para seguir (no sólo el botón gris).
class FaltaParaSeguir extends StatelessWidget {
  const FaltaParaSeguir(this.faltantes, {super.key});

  final List<String> faltantes;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final color = oscuro ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    final lista = faltantes.length < 2 ? faltantes.join() : '${faltantes.sublist(0, faltantes.length - 1).join(', ')} y ${faltantes.last}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: oscuro ? const Color(0xFFF87171) : AvisoRojo.fondo),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Para seguir falta: $lista.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }
}
