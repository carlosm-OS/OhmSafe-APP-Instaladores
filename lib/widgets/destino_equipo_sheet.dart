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

const _kNueva = '__nueva__';

class _DestinoSheet extends StatefulWidget {
  const _DestinoSheet({required this.opciones});
  final OpcionesDestino opciones;

  @override
  State<_DestinoSheet> createState() => _DestinoSheetState();
}

class _DestinoSheetState extends State<_DestinoSheet> {
  late String? _seleccion = widget.opciones.seleccionInicial;
  late final TextEditingController _nombre = TextEditingController(text: widget.opciones.nombreNueva);
  late final TextEditingController _direccion = TextEditingController(text: widget.opciones.direccionNueva);

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    super.dispose();
  }

  bool get _listo => _seleccion != null && (_seleccion != _kNueva || _nombre.text.trim().isNotEmpty);

  void _confirmar() {
    if (!_listo) return;
    Navigator.pop(
      context,
      _seleccion == _kNueva
          ? destinoCasaNueva(nombre: _nombre.text, direccion: _direccion.text)
          : destinoCasaExistente(_seleccion!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final o = widget.opciones;
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
              'El cliente ya tiene ${o.casas.length == 1 ? 'una casa' : '${o.casas.length} casas'} en su app. '
              'Elige si este energizador se suma a una de ellas o es de una casa nueva.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final c in o.casas)
              RadioListTile<String>(
                value: c.id,
                groupValue: _seleccion,
                onChanged: (v) => setState(() => _seleccion = v),
                title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if ((c.direccion ?? '').isNotEmpty) c.direccion!,
                  c.energizadores == 1 ? '1 energizador' : '${c.energizadores} energizadores',
                  if (c.id == o.sugerida) 'Coincide con la dirección de la orden',
                ].join(' · ')),
                contentPadding: EdgeInsets.zero,
              ),
            RadioListTile<String>(
              value: _kNueva,
              groupValue: _seleccion,
              onChanged: (v) => setState(() => _seleccion = v),
              title: const Text('Casa nueva', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Otra propiedad del mismo cliente'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_seleccion == _kNueva) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre de la casa', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _direccion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 16),
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
