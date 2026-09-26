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
import '../widgets/notification_bell.dart';

/// Mis incidencias (tickets de Helpdesk que abrí desde la app) + botón para
/// reportar una nueva. Operaciones las atiende en Odoo y, si hace falta
/// visita, crea la intervención desde el ticket.
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

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<Incidencia>(MaterialPageRoute(builder: (_) => const NuevaIncidenciaScreen()));
    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Incidencia ${creada.referencia} enviada a operaciones')));
      _cargar();
    }
  }

  IconData _icono(String tipo) => switch (tipo) {
        'equipo_danado' => Icons.broken_image_outlined,
        'cliente_ausente' => Icons.person_off_outlined,
        'riesgo_en_sitio' => Icons.warning_amber_rounded,
        'falta_material' => Icons.inventory_2_outlined,
        'acceso_al_sitio' => Icons.lock_outline,
        _ => Icons.report_gmailerrorred_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias'), actions: const [NotificationBell(), SizedBox(width: 8)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _nueva, icon: const Icon(Icons.add), label: const Text('Reportar')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar tus incidencias: $_error', textAlign: TextAlign.center))])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Icon(Icons.check_circle_outline, size: 56, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Sin incidencias reportadas', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Si algo se complica en sitio, repórtalo aquí y operaciones lo toma.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(_icono(it.tipo), color: it.tipo == 'riesgo_en_sitio' ? cs.error : cs.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(child: Text('${it.titulo} ${it.referencia}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                                          child: Text(it.estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSecondaryContainer)),
                                        ),
                                      ]),
                                      if (it.descripcion.isNotEmpty) ...[const SizedBox(height: 4), Text(it.descripcion, maxLines: 3, overflow: TextOverflow.ellipsis)],
                                      const SizedBox(height: 4),
                                      Text(
                                        [if (it.ordenId != null) 'Orden ${it.ordenId}', FechasOdoo.fechaHora(it.fecha)].join(' · '),
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
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
  String? _error;

  @override
  void initState() {
    super.initState();
    sl.get<OrdenesRepository>().getOrdenes(tipo: 'instalacion').then((r) {
      if (!mounted) return;
      r.fold((list) => setState(() => _ordenes = list.where((o) => o.estado != 'completo' && o.estado != 'cancelado').toList()), (_) {});
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

  Future<void> _enviar() async {
    final texto = _descripcion.text.trim();
    if (texto.length < 5) {
      setState(() => _error = 'Cuenta qué pasó (al menos una frase).');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
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
        _error = 'No se pudo enviar: ${f.message}';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar incidencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('¿Qué pasó?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in tiposIncidencia.entries)
                ChoiceChip(label: Text(e.value), selected: _tipo == e.key, onSelected: (_) => setState(() => _tipo = e.key)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descripcion,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Describe la situación', border: OutlineInputBorder(), alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _ordenId,
            decoration: const InputDecoration(labelText: 'Orden relacionada (opcional)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Ninguna')),
              for (final o in _ordenes) DropdownMenuItem<String?>(value: o.id, child: Text('${o.cliente} · ${o.direccion}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _ordenId = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _enviando ? null : _tomarFoto,
            icon: Icon(_foto == null ? Icons.add_a_photo_outlined : Icons.check_circle, color: _foto == null ? null : cs.primary),
            label: Text(_foto == null ? 'Agregar foto (opcional)' : 'Foto lista · cambiar'),
          ),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: cs.error))],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Enviar a operaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text('Se envía con tu ubicación actual. Operaciones te responde por la campana y, si hace falta visita, la verás en tus instalaciones.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}
