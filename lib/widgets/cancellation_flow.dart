import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/di/injection_container.dart';
import '../core/navigation/volver_a_listado.dart';
import '../core/theme/app_theme_extension.dart';
import '../core/utils/ubicacion.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../screens/instalaciones_screen.dart';

/// Motivos de cancelación en sitio (mismo catálogo que el backend, `MOTIVOS_CANCELACION`).
const motivosCancelacion = <String, String>{
  'cliente_ausente': 'No hay nadie en el domicilio',
  'sin_acceso': 'No pude ingresar',
  'mal_clima': 'Mal clima impide instalar',
  'cliente_reagenda': 'El cliente pidió reagendar',
  'falta_material': 'Falta material o equipo',
  'riesgo_en_sitio': 'Riesgo en sitio',
  'otro': 'Otro',
};

/// Hoja de cancelación en sitio: motivo (chips), notas, foto opcional. Manda la
/// ubicación y la hora para que quede constancia de que el técnico estuvo ahí.
/// Al confirmar, la intervención regresa a «por planificar» en Odoo y operaciones
/// recibe la actividad de llamar al cliente; el técnico vuelve al listado.
void showCancellationFlow(BuildContext context, Map<String, dynamic> ticket) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _HojaCancelacion(ticket: ticket, contextoPadre: context),
  );
}

class _HojaCancelacion extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final BuildContext contextoPadre;
  const _HojaCancelacion({required this.ticket, required this.contextoPadre});

  @override
  State<_HojaCancelacion> createState() => _HojaCancelacionState();
}

class _HojaCancelacionState extends State<_HojaCancelacion> {
  String? _motivo;
  final _notas = TextEditingController();
  XFile? _foto;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (origen == null) return;
    final f = await ImagePicker().pickImage(source: origen, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
    if (f != null && mounted) setState(() => _foto = f);
  }

  Future<void> _confirmar() async {
    final notas = _notas.text.trim();
    if (_motivo == null) {
      setState(() => _error = 'Elige el motivo de la cancelación.');
      return;
    }
    if (_motivo == 'otro' && notas.length < 5) {
      setState(() => _error = 'Con «Otro» cuéntanos qué pasó.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final foto = _foto == null ? null : base64Encode(await File(_foto!.path).readAsBytes());
    final ubicacion = ubicacionJson(await ubicacionActual(limite: const Duration(seconds: 4)));
    if (!mounted) return;
    final id = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    final r = await sl.get<OrdenesRepository>().cancelar(id, motivo: _motivo!, notas: notas, fotoBase64: foto, ubicacion: ubicacion);
    if (!mounted) return;
    r.fold(
      (_) {
        Navigator.pop(context);
        volverAListado(widget.contextoPadre, InstalacionesScreen(cancelledTicketTitle: widget.ticket['title']));
      },
      (f) => setState(() {
        _enviando = false;
        _error = 'No se pudo cancelar: ${f.message}';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ohm = context.ohm;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cancelar instalación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                IconButton(onPressed: _enviando ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), visualDensity: VisualDensity.compact),
              ],
            ),
            Text('Operaciones llamará al cliente y la reagendará.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text('¿Qué pasó?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in motivosCancelacion.entries)
                  ChoiceChip(label: Text(e.value), selected: _motivo == e.key, onSelected: _enviando ? null : (_) => setState(() => _motivo = e.key)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notas,
              maxLines: 3,
              enabled: !_enviando,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: _motivo == 'otro' ? 'Cuéntanos qué pasó (obligatorio)' : 'Notas para operaciones (opcional)',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                filled: true,
                fillColor: ohm.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enviando ? null : _elegirFoto,
                    icon: Icon(_foto == null ? Icons.add_a_photo_outlined : Icons.check_circle, size: 18),
                    label: Text(_foto == null ? 'Agregar foto (opcional)' : 'Foto lista'),
                  ),
                ),
                if (_foto != null) IconButton(onPressed: _enviando ? null : () => setState(() => _foto = null), icon: const Icon(Icons.close, size: 18)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _enviando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmar cancelación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
