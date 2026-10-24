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
import 'ayuda.dart';
import 'ohm_gradient_button.dart';

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
    // No se arrastra para cerrar: mientras envía, cerrarla dejaba al técnico en el flujo con la
    // instalación ya cancelada (auditoría 2026-10-23). Se cierra con su ✕ o tocando fuera.
    enableDrag: false,
    // v2 (2026-10-23): fondo y forma vienen del tema (radio 28 de las hojas).
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

  /// El error vino del envío (no de un dato que falta): se titula «No se canceló…».
  bool _falloEnvio = false;

  /// «reparación» o «instalación», según el tipo que trae el ticket (el mismo que usa el cierre).
  bool get _esReparacion {
    final tipo = (widget.ticket['type'] as String?)?.toLowerCase() ?? '';
    return tipo.contains('reparacion') || tipo.contains('reparación');
  }

  String get _que => _esReparacion ? 'reparación' : 'instalación';

  /// Texto del motivo; con reparación, «Mal clima impide reparar».
  String _textoMotivo(String clave, String texto) => clave == 'mal_clima' && _esReparacion ? 'Mal clima impide reparar' : texto;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    final f = await ImagePicker().pickImage(source: origen, imageQuality: 70, maxWidth: 1600, maxHeight: 1600);
    if (f != null && mounted) setState(() => _foto = f);
  }

  Future<void> _confirmar() async {
    final notas = _notas.text.trim();
    if (_motivo == null) {
      setState(() {
        _falloEnvio = false;
        _error = 'Elige el motivo de la cancelación.';
      });
      return;
    }
    if (_motivo == 'otro' && notas.length < 5) {
      setState(() {
        _falloEnvio = false;
        _error = 'Con «Otro» cuéntanos qué pasó.';
      });
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
      _falloEnvio = false;
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
        _falloEnvio = true;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PopScope(
      canPop: !_enviando,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(header: true, child: Text('Cancelar $_que', style: theme.textTheme.headlineSmall)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Text('Operaciones llamará al cliente y la reagendará.', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('¿Qué pasó?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              // Motivos como chips v2: píldora gris; el elegido en naranja claro con palomita.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in motivosCancelacion.entries)
                    ChoiceChip(
                      label: Text(_textoMotivo(e.key, e.value)),
                      selected: _motivo == e.key,
                      onSelected: _enviando ? null : (_) => setState(() => _motivo = e.key),
                      showCheckmark: true,
                      checkmarkColor: cs.onPrimaryContainer,
                      backgroundColor: cs.surfaceContainerHighest,
                      selectedColor: cs.primaryContainer,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _motivo == e.key ? cs.onPrimaryContainer : cs.onSurface,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notas,
                maxLines: 3,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _motivo == 'otro' ? 'Cuéntanos qué pasó (obligatorio)' : 'Notas para operaciones (opcional)',
                  fillColor: context.ohm.surfaceContainer,
                ),
              ),
              const SizedBox(height: 12),
              if (_foto == null)
                BotonSecundario(etiqueta: 'Agregar foto (opcional)', icono: Icons.add_a_photo_rounded, onPressed: _enviando ? null : _elegirFoto)
              else
                Row(
                  children: [
                    Expanded(child: EstadoPunto('Foto lista', color: context.ohm.success)),
                    BotonFila(etiqueta: 'Quitar foto', onPressed: _enviando ? null : () => setState(() => _foto = null)),
                  ],
                ),
              const SizedBox(height: 20),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: MensajeFlujo(
                    icono: Icons.error_outline_rounded,
                    color: cs.error,
                    titulo: _falloEnvio ? 'No se canceló la $_que' : _error!,
                    texto: _falloEnvio ? _error : null,
                  ),
                ),
              OhmGradientButton(label: 'Confirmar cancelación', loading: _enviando, loadingLabel: 'Cancelando la $_que…', onPressed: _confirmar),
            ],
          ),
        ),
      ),
    );
  }
}
