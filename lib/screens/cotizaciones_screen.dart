import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/di/injection_container.dart';
import '../core/utils/fechas_odoo.dart';
import '../features/dinero/data/dinero_repository.dart';
import '../features/dinero/domain/dinero.dart';
import '../widgets/notification_bell.dart';

/// Cotizar venta: las cotizaciones que el instalador levantó en campo y un
/// botón para armar una nueva. La cotización vive en Odoo (Ventas) atribuida
/// al instalador; Odoo se la manda al cliente por correo y el cliente paga
/// en el portal desde el enlace.
class CotizacionesScreen extends StatefulWidget {
  const CotizacionesScreen({super.key});

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  List<Cotizacion> _items = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await sl.get<DineroRepository>().cotizaciones();
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
    final creada = await Navigator.of(context).push<Cotizacion>(MaterialPageRoute(builder: (_) => const NuevaCotizacionScreen()));
    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cotización ${creada.referencia} enviada a ${creada.cliente}')));
      _cargar();
    }
  }

  Color _color(String estado, ColorScheme cs) => switch (estado) {
        'confirmada' => cs.primary,
        'cancelada' => cs.error,
        'enviada' => cs.tertiary,
        _ => cs.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizar venta'), actions: const [NotificationBell(), SizedBox(width: 8)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _nueva, icon: const Icon(Icons.add), label: const Text('Cotizar')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar tus cotizaciones: $_error', textAlign: TextAlign.center))])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Icon(Icons.request_quote_outlined, size: 56, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Sin cotizaciones todavía', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text('¿Un vecino quiere cerca? Cotízala aquí: le llega por correo y paga en línea. La venta queda a tu nombre.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CotizacionCard(c: _items[i], color: _color(_items[i].estado, cs)),
                      ),
      ),
    );
  }
}

class _CotizacionCard extends StatelessWidget {
  final Cotizacion c;
  final Color color;
  const _CotizacionCard({required this.c, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${c.cliente} · ${c.referencia}', style: const TextStyle(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
              child: Text(estadosCotizacion[c.estado] ?? c.estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${dinero(c.total, c.moneda)} · ${FechasOdoo.fecha(c.fecha)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          if (c.urlPortal != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(c.urlPortal!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ver en portal'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: c.urlPortal!));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado: compártelo con el cliente')));
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copiar enlace'),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Formulario: datos del cliente, productos del catálogo con cantidad y nota.
class NuevaCotizacionScreen extends StatefulWidget {
  const NuevaCotizacionScreen({super.key});

  @override
  State<NuevaCotizacionScreen> createState() => _NuevaCotizacionScreenState();
}

class _NuevaCotizacionScreenState extends State<NuevaCotizacionScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _ciudad = TextEditingController();
  final _nota = TextEditingController();
  List<ProductoCatalogo> _catalogo = const [];
  final Map<int, double> _cantidades = {};
  bool _cargandoCatalogo = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    sl.get<DineroRepository>().catalogo().then((r) {
      if (!mounted) return;
      r.fold(
        (list) => setState(() {
          _catalogo = list;
          _cargandoCatalogo = false;
        }),
        (f) => setState(() {
          _cargandoCatalogo = false;
          _error = 'No se pudo cargar el catálogo: ${f.message}';
        }),
      );
    });
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _telefono, _direccion, _ciudad, _nota]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _catalogo.fold(0, (acc, p) => acc + p.precio * (_cantidades[p.id] ?? 0));

  Future<void> _enviar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_cantidades.values.every((q) => q <= 0)) {
      setState(() => _error = 'Agrega al menos un producto.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final r = await sl.get<DineroRepository>().cotizar(
          nombre: _nombre.text.trim(),
          email: _email.text.trim(),
          telefono: _telefono.text.trim(),
          direccion: _direccion.text.trim(),
          ciudad: _ciudad.text.trim(),
          lineas: _cantidades,
          nota: _nota.text,
        );
    if (!mounted) return;
    r.fold(
      (c) => Navigator.of(context).pop(c),
      (f) => setState(() {
        _enviando = false;
        _error = 'No se pudo cotizar: ${f.message}';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cotización')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Cliente', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe el nombre del cliente' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo (ahí le llega la cotización)', border: OutlineInputBorder()),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Correo inválido',
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _telefono, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _direccion, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Dirección (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextFormField(controller: _ciudad, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ciudad (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text('Productos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_cargandoCatalogo)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (_catalogo.isEmpty)
              Text('El catálogo está vacío. Operaciones etiqueta en Odoo lo que se puede cotizar desde la app.', style: TextStyle(color: cs.onSurfaceVariant))
            else
              for (final p in _catalogo) _LineaProducto(p: p, cantidad: _cantidades[p.id] ?? 0, onChanged: (q) => setState(() => _cantidades[p.id] = q)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Subtotal (sin IVA)', style: TextStyle(color: cs.onSurfaceVariant)),
              Text(dinero(_subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _nota,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Nota para el cliente (opcional)', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: cs.error))],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enviando || _cargandoCatalogo ? null : _enviar,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _enviando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Cotizar y enviar al cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text('Odoo calcula impuestos y le manda la cotización al cliente por correo con tu código de venta. El cliente paga en línea desde el enlace.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LineaProducto extends StatelessWidget {
  final ProductoCatalogo p;
  final double cantidad;
  final ValueChanged<double> onChanged;
  const _LineaProducto({required this.p, required this.cantidad, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activo = cantidad > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: activo ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activo ? cs.primary.withValues(alpha: 0.6) : Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(dinero(p.precio), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
        IconButton(onPressed: cantidad > 0 ? () => onChanged(cantidad - 1) : null, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Quitar'),
        SizedBox(width: 24, child: Text(cantidad.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(onPressed: cantidad < 99 ? () => onChanged(cantidad + 1) : null, icon: const Icon(Icons.add_circle_outline), tooltip: 'Agregar'),
      ]),
    );
  }
}
