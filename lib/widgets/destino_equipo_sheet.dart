import 'package:geolocator/geolocator.dart';
import '../core/utils/ubicacion.dart';
import 'package:flutter/material.dart';

import '../core/utils/destino_equipo.dart';

/// «¿Dónde va este equipo?»: hoja que el instalador ve justo antes de vincular
/// cuando el cliente ya tiene casas en el dashboard. Devuelve el `destino` para
/// el backend, o null si canceló.
Future<Map<String, dynamic>?> elegirDestinoEquipo(BuildContext context, OpcionesDestino opciones) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DestinoSheet(opciones: opciones),
  );
}

const _kNueva = OpcionesDestino.nueva;

class _DestinoSheet extends StatefulWidget {
  const _DestinoSheet({required this.opciones});
  final OpcionesDestino opciones;

  @override
  State<_DestinoSheet> createState() => _DestinoSheetState();
}

class _DestinoSheetState extends State<_DestinoSheet> {
  late String _seleccion = widget.opciones.seleccionInicial;
  late final TextEditingController _nombre = TextEditingController(text: widget.opciones.nombreNueva);

  /// Dónde está el técnico ahora (dirección escrita) y a qué distancia de la dirección de la compra.
  bool _buscandoUbicacion = true;
  String? _dondeEstas;
  double? _distanciaMetros;

  @override
  void initState() {
    super.initState();
    _ubicarTecnico();
  }

  Future<void> _ubicarTecnico() async {
    final pos = await ubicacionActual(limite: const Duration(seconds: 6));
    if (pos == null) {
      if (mounted) setState(() => _buscandoUbicacion = false);
      return;
    }
    final o = widget.opciones;
    final results = await Future.wait([
      direccionDeCoordenadas(pos.latitude, pos.longitude),
      o.latNueva != null && o.lngNueva != null
          ? Future.value((lat: o.latNueva!, lng: o.lngNueva!))
          : coordenadasDeDireccion(o.direccionNueva),
    ]);
    if (!mounted) return;
    final compra = results[1] as ({double lat, double lng})?;
    setState(() {
      _buscandoUbicacion = false;
      _dondeEstas = (results[0] as String?) ?? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      _distanciaMetros = compra == null ? null : Geolocator.distanceBetween(pos.latitude, pos.longitude, compra.lat, compra.lng);
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _listo => _seleccion != _kNueva || _nombre.text.trim().isNotEmpty;

  /// Aviso (título, texto) cuando la elección no cuadra con lo vendido. No bloquea: el usuario decide.
  (String, String)? get _avisoDestino {
    final v = widget.opciones.venta;
    if (v == null) return null;
    if (v.esServicioNuevo && _seleccion != _kNueva) {
      final casa = widget.opciones.casas.where((c) => c.id == _seleccion).map((c) => c.nombre).firstOrNull ?? 'esa casa';
      return (
        'Esta venta es un servicio nuevo',
        'Normalmente un plan nuevo va en una casa nueva. Si lo sumas a «$casa», la suscripción de ${v.nombre} se ligará a esa casa (si ya tiene una, quedará pendiente para operaciones). Confírmalo con el cliente.',
      );
    }
    if (!v.esServicioNuevo && _seleccion == _kNueva) {
      return (
        'Esta venta es equipo adicional',
        'Normalmente se suma a una casa que el cliente ya tiene. Elige casa nueva sólo si el equipo va en otra propiedad.',
      );
    }
    return null;
  }

  void _confirmar() {
    if (!_listo) return;
    Navigator.pop(
      context,
      _seleccion == _kNueva
          // La dirección de la casa nueva es la de la compra (ticket de instalación): no se edita aquí.
          ? destinoCasaNueva(nombre: _nombre.text, direccion: widget.opciones.direccionNueva)
          : destinoCasaExistente(_seleccion),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final o = widget.opciones;
    final muted = theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Dónde va este equipo?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Elige si es una casa nueva (con la dirección de la compra) o se suma a una casa que el cliente ya tiene.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (o.venta != null) ...[
              const SizedBox(height: 10),
              // Qué se vendió: con esto a la vista el instalador decide (servicio nuevo → casa nueva; equipo adicional → se suma).
              _Aviso(
                icono: o.venta!.esServicioNuevo ? Icons.add_home_outlined : Icons.add_box_outlined,
                titulo: 'Venta ${o.venta!.nombre}',
                texto: o.venta!.resumen,
                tono: _Tono.info,
              ),
            ],
            const SizedBox(height: 14),

            // 1) Casa nueva: primera opción. Nombre editable; dirección = la del ticket, sólo lectura.
            _Opcion(
              seleccionada: _seleccion == _kNueva,
              onTap: () => setState(() => _seleccion = _kNueva),
              titulo: 'Casa nueva',
              subtitulo: o.direccionNueva.isNotEmpty ? o.direccionNueva : 'Dirección de la instalación',
              child: _seleccion == _kNueva
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nombre,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(labelText: 'Nombre de la casa', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _Dato(
                            icono: Icons.receipt_long_outlined,
                            titulo: o.ventaNueva != null ? 'Dirección de la compra (${o.ventaNueva})' : 'Dirección de la compra',
                            texto: o.direccionNueva.isNotEmpty ? o.direccionNueva : 'Sin dirección en la venta',
                          ),
                          const SizedBox(height: 8),
                          _Dato(
                            icono: Icons.my_location,
                            titulo: 'Dónde estás ahora',
                            texto: _buscandoUbicacion
                                ? 'Buscando tu ubicación…'
                                : (_dondeEstas ?? 'Sin ubicación (activa el GPS para verla)'),
                          ),
                          if (_distanciaMetros != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _distanciaMetros! <= 300
                                  ? 'Estás en la dirección de la compra.'
                                  : 'Estás a ${distanciaLegible(_distanciaMetros!)} de la dirección de la compra. Confírmala con el cliente antes de continuar.',
                              style: muted?.copyWith(
                                color: _distanciaMetros! <= 300 ? cs.primary : cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text('La dirección de la casa nueva es la de la compra; no se edita aquí.', style: muted),
                        ],
                      ),
                    )
                  : null,
            ),

            // 2) Casas que el cliente ya tiene.
            if (o.casas.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'CASAS DEL CLIENTE',
                style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final c in o.casas) ...[
                _Opcion(
                  seleccionada: _seleccion == c.id,
                  onTap: () => setState(() => _seleccion = c.id),
                  titulo: c.nombre,
                  subtitulo: [
                    if ((c.direccion ?? '').isNotEmpty) c.direccion!,
                    c.equipos == 1 ? '1 equipo' : '${c.equipos} equipos',
                  ].join(' · '),
                  etiqueta: c.id == o.sugerida ? 'Coincide con la dirección' : null,
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (_avisoDestino != null) ...[
              const SizedBox(height: 4),
              _Aviso(icono: Icons.warning_amber_rounded, titulo: _avisoDestino!.$1, texto: _avisoDestino!.$2, tono: _Tono.alerta),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _listo ? _confirmar : null,
                    style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta seleccionable (radio + título + subtítulo), misma forma para «Casa nueva» y para cada casa.
class _Opcion extends StatelessWidget {
  const _Opcion({required this.seleccionada, required this.onTap, required this.titulo, required this.subtitulo, this.etiqueta, this.child});
  final bool seleccionada;
  final VoidCallback onTap;
  final String titulo;
  final String subtitulo;
  final String? etiqueta;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: seleccionada ? cs.primary.withValues(alpha: 0.06) : theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: seleccionada ? cs.primary : theme.dividerColor.withValues(alpha: 0.6), width: seleccionada ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(seleccionada ? Icons.radio_button_checked : Icons.radio_button_off, color: seleccionada ? cs.primary : cs.outline, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                            if (etiqueta != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                                child: Text(etiqueta!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitulo, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              if (child != null) child!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila «icono · título · texto» de sólo lectura dentro de la tarjeta de casa nueva.
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.titulo, required this.texto});
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(texto, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Tono { info, alerta }

/// Tarjeta de contexto («Venta S00255 · Servicio nuevo…») o de aviso (elección que no cuadra con lo vendido).
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.texto, required this.tono});
  final IconData icono;
  final String titulo;
  final String texto;
  final _Tono tono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = tono == _Tono.alerta ? cs.error : cs.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
