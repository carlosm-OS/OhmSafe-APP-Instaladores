import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/di/injection_container.dart';
import '../core/utils/fechas_odoo.dart';
import '../core/utils/ubicacion.dart';
import '../features/incidencias/data/incidencias_repository.dart';
import '../features/incidencias/domain/incidencia.dart';
import '../features/ordenes/domain/entities/orden.dart';
import '../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../core/theme/app_theme_extension.dart';
import '../widgets/ayuda.dart';
import '../widgets/menu_item_tile.dart';
import '../widgets/ohm_gradient_button.dart';

/// Mis incidencias (tickets de Helpdesk que abrí desde la app) + botón para
/// reportar una nueva. Operaciones las atiende en Odoo y, si hace falta
/// visita, crea la intervención desde el ticket.
/// v2 (2026-10-23): encabezado de todos, lista agrupada con el estado como punto + palabra, y un
/// solo botón naranja abajo («Reportar una incidencia») en lugar del botón flotante.
class IncidenciasScreen extends StatefulWidget {
  const IncidenciasScreen({super.key});

  @override
  State<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends State<IncidenciasScreen> {
  List<Incidencia> _items = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await sl.get<IncidenciasRepository>().listar();
    if (!mounted) return;
    r.fold(
      (items) => setState(() {
        _items = items;
        _cargando = false;
        _error = null;
      }),
      (f) => setState(() {
        _cargando = false;
        _error = f.message;
      }),
    );
  }

  void _volverAIntentar() {
    setState(() => _cargando = true);
    _cargar();
  }

  /// Etapa del ticket en Odoo → color del punto: resuelta en verde, cancelada en gris, el resto en
  /// ámbar (operaciones todavía la está viendo).
  Color _colorEstado(String estado) {
    final e = estado.toLowerCase();
    if (e.contains('resuel') || e.contains('cerrad') || e.contains('hecho') || e.contains('listo')) return context.ohm.success;
    if (e.contains('cancel')) return Theme.of(context).colorScheme.outline;
    return context.ohm.warning;
  }

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<Incidencia>(MaterialPageRoute(builder: (_) => const NuevaIncidenciaScreen()));
    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidencia ${creada.referencia} enviada a operaciones')));
      _cargar();
    }
  }

  IconData _icono(String tipo) => switch (tipo) {
    'equipo_danado' => Icons.broken_image_rounded,
    'cliente_ausente' => Icons.person_off_rounded,
    'riesgo_en_sitio' => Icons.warning_amber_rounded,
    'falta_material' => Icons.inventory_2_rounded,
    'acceso_al_sitio' => Icons.lock_rounded,
    _ => Icons.report_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final List<Widget> contenido;
    if (_cargando) {
      contenido = [_cargandoFila(context, 'Cargando tus incidencias…')];
    } else if (_error != null) {
      contenido = [
        MensajeFlujo(
          icono: Icons.error_outline_rounded,
          color: cs.error,
          titulo: 'No se pudieron cargar tus incidencias',
          texto: _error,
          accion: TextButton(onPressed: _volverAIntentar, child: const Text('Volver a intentar')),
        ),
      ];
    } else if (_items.isEmpty) {
      contenido = [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.check_circle_outline_rounded, size: 32, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text('Sin incidencias reportadas', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Aquí ves lo que reportas desde el sitio y en qué va. No tienes ninguna abierta. Si algo se complica en una instalación, presiona «Reportar una incidencia» y operaciones lo toma.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    } else {
      contenido = [
        GrupoFilas(
          children: [
            for (final it in _items)
              FilaFlujo(
                leading: MosaicoIcono(icono: _icono(it.tipo), color: it.tipo == 'riesgo_en_sitio' ? cs.error : cs.onSurfaceVariant),
                titulo: '${it.titulo} ${it.referencia}',
                subtitulo: [
                  if (it.descripcion.isNotEmpty) it.descripcion,
                  [if (it.ordenId != null) 'Instalación ${it.ordenId}', FechasOdoo.fechaHora(it.fecha)].join(' · '),
                ].join('\n'),
                // Ancho acotado: EstadoPunto lleva un Flexible y en el trailing no hay límite.
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: EstadoPunto(it.estado, color: _colorEstado(it.estado)),
                ),
              ),
          ],
        ),
      ];
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoFlujo(titulo: 'Incidencias'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargar,
                color: cs.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: contenido,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OhmGradientButton(label: 'Reportar una incidencia', icon: Icons.add_rounded, onPressed: _nueva),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Cargando…» con frase, nunca un círculo mudo (v2).
Widget _cargandoFila(BuildContext context, String frase) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 32),
    child: Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(frase, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    ),
  );
}

/// Formulario: tipo, qué pasó, orden relacionada (opcional), foto (opcional).
/// La ubicación se toma sola al enviar.
class NuevaIncidenciaScreen extends StatefulWidget {
  const NuevaIncidenciaScreen({super.key});

  @override
  State<NuevaIncidenciaScreen> createState() => _NuevaIncidenciaScreenState();
}

class _NuevaIncidenciaScreenState extends State<NuevaIncidenciaScreen> {
  String _tipo = 'equipo_danado';
  final _descripcion = TextEditingController();
  String? _ordenId;
  List<Orden> _ordenes = const [];
  XFile? _foto;
  bool _enviando = false;

  /// Falta contar qué pasó: va debajo del campo.
  String? _errorTexto;

  /// No se envió (red, servidor): aviso rojo junto al botón.
  String? _error;

  @override
  void initState() {
    super.initState();
    sl.get<OrdenesRepository>().getOrdenes(tipo: 'instalacion').then((r) {
      if (!mounted) return;
      r.fold((list) {
        setState(() => _ordenes = list.where((o) => o.estado != 'completo' && o.estado != 'cancelado').toList());
        // La instalación EN CURSO va preseleccionada: casi siempre la incidencia es de esa visita.
        // (La pregunta «¿reportar o cancelar?» ya se hizo en el Inicio.)
        final enCurso = _ordenes.where((o) => o.estado == 'en_curso').toList();
        if (enCurso.length == 1 && _ordenId == null) _ordenId = enCurso.first.id;
      }, (_) {});
    });
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto() async {
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

  Future<void> _enviar() async {
    if (_enviando) return;
    final texto = _descripcion.text.trim();
    if (texto.length < 5) {
      setState(() => _errorTexto = 'Cuenta qué pasó (al menos una frase).');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
      _errorTexto = null;
    });
    final foto = _foto == null ? null : base64Encode(await File(_foto!.path).readAsBytes());
    final ubicacion = ubicacionJson(await ubicacionActual(limite: const Duration(seconds: 4)));
    if (!mounted) return;
    final r = await sl.get<IncidenciasRepository>().reportar(tipo: _tipo, descripcion: texto, ordenId: _ordenId, fotoBase64: foto, ubicacion: ubicacion);
    if (!mounted) return;
    r.fold(
      (inc) => Navigator.of(context).pop(inc),
      (f) => setState(() {
        _enviando = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoFlujo(titulo: 'Reportar incidencia'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  const EtiquetaSeccion('¿Qué pasó?'),
                  GrupoFilas(
                    children: [
                      for (final e in tiposIncidencia.entries)
                        FilaFlujo(
                          titulo: e.value,
                          trailing: CirculoCheck(marcado: _tipo == e.key),
                          onTap: _enviando ? null : () => setState(() => _tipo = e.key),
                        ),
                    ],
                  ),
                  const EtiquetaSeccion('Cuéntanos'),
                  TextField(
                    controller: _descripcion,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyLarge,
                    onChanged: (_) {
                      if (_errorTexto != null) setState(() => _errorTexto = null);
                    },
                    decoration: InputDecoration(hintText: 'Describe la situación', alignLabelWithHint: true, errorText: _errorTexto),
                  ),
                  const SizedBox(height: 12),
                  const EtiquetaSeccion('Instalación relacionada (opcional)'),
                  DropdownButtonFormField<String?>(
                    initialValue: _ordenId,
                    isExpanded: true,
                    style: theme.textTheme.bodyLarge,
                    dropdownColor: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Ninguna')),
                      for (final o in _ordenes)
                        DropdownMenuItem<String?>(
                          value: o.id,
                          child: Text('${o.cliente} · ${o.direccion}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _ordenId = v),
                  ),
                  const SizedBox(height: 20),
                  BotonSecundario(
                    etiqueta: _foto == null ? 'Agregar foto (opcional)' : 'Foto lista · cambiar',
                    icono: _foto == null ? Icons.add_a_photo_rounded : Icons.check_circle_rounded,
                    onPressed: _enviando ? null : _tomarFoto,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) MensajeFlujo(icono: Icons.error_outline_rounded, color: cs.error, titulo: 'No se envió tu reporte', texto: _error),
                  OhmGradientButton(
                    label: _error != null ? 'Volver a intentar' : 'Enviar a operaciones',
                    icon: Icons.send_rounded,
                    loading: _enviando,
                    loadingLabel: 'Enviando tu reporte…',
                    onPressed: _enviar,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Se envía con tu ubicación actual. Operaciones te responde por la campana y, si hace falta visita, la verás en tus instalaciones.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
