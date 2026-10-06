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

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _listo => _seleccion != _kNueva || _nombre.text.trim().isNotEmpty;

  void _confirmar() {
    if (!_listo) return;
    Navigator.pop(
      context,
      _seleccion == _kNueva
          // La dirección de la casa nueva es la del ticket de instalación: no se edita aquí.
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
              'Elige si es una casa nueva (con la dirección de esta instalación) o se suma a una casa que el cliente ya tiene.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
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
                          const SizedBox(height: 6),
                          Text('Dirección: la de este ticket de instalación (no se edita aquí).', style: muted),
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
                    c.energizadores == 1 ? '1 energizador' : '${c.energizadores} energizadores',
                  ].join(' · '),
                  etiqueta: c.id == o.sugerida ? 'Coincide con la dirección' : null,
                ),
                const SizedBox(height: 8),
              ],
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
